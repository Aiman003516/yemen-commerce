-- Merchant Order Workbench and COD reconciliation foundation.
-- The workbench exposes merchant-scoped operational projections only. It never
-- transfers funds, verifies non-cash payments, or grants client table writes.

create table if not exists public.cod_reconciliation_batches (
  id uuid primary key default gen_random_uuid(),
  merchant_id uuid not null references public.merchants(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  business_date date not null,
  status text not null default 'open' check (status in ('open', 'reconciled', 'variance', 'voided')),
  expected_total_minor bigint not null default 0 check (expected_total_minor >= 0),
  collected_total_minor bigint not null default 0 check (collected_total_minor >= 0),
  variance_minor bigint not null default 0,
  note text,
  created_by_user_id uuid not null references public.profiles(id) on delete restrict,
  closed_by_user_id uuid references public.profiles(id) on delete set null,
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (shop_id, business_date),
  check ((status = 'open' and closed_at is null) or (status <> 'open' and closed_at is not null))
);

alter table public.cod_collection_records
  add column if not exists reconciliation_batch_id uuid references public.cod_reconciliation_batches(id) on delete set null;

create index if not exists cod_batches_merchant_status_date_idx
  on public.cod_reconciliation_batches(merchant_id, status, business_date desc);
create index if not exists cod_batches_shop_date_idx
  on public.cod_reconciliation_batches(shop_id, business_date desc);
create index if not exists cod_records_batch_created_idx
  on public.cod_collection_records(reconciliation_batch_id, created_at desc);
create index if not exists merchant_orders_shop_workbench_idx
  on public.merchant_orders(shop_id, fulfilment_status, payment_status, created_at desc, id desc);
create index if not exists merchant_orders_shop_cod_idx
  on public.merchant_orders(shop_id, cod_status, created_at desc, id desc);

alter table public.cod_reconciliation_batches enable row level security;
grant select on public.cod_reconciliation_batches to authenticated;

 drop policy if exists cod_reconciliation_batches_owner_read on public.cod_reconciliation_batches;
create policy cod_reconciliation_batches_owner_read
on public.cod_reconciliation_batches
for select to authenticated
using (
  merchant_id in (select private.current_merchant_ids())
  or private.is_admin()
);

create or replace function private.open_cod_reconciliation_batch(
  p_shop_id uuid,
  p_business_date date,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_merchant uuid;
  v_batch cod_reconciliation_batches%rowtype;
  v_expected bigint;
begin
  if v_user is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;
  select s.merchant_id into v_merchant
  from shops s
  where s.id = p_shop_id
    and (s.merchant_id in (select private.current_merchant_ids()) or private.is_admin());
  if v_merchant is null then
    raise exception using errcode = '42501', message = 'SHOP_NOT_OWNED';
  end if;
  if p_business_date is null or p_business_date > current_date then
    raise exception using errcode = 'P0001', message = 'INVALID_COD_BUSINESS_DATE';
  end if;

  select * into v_batch
  from cod_reconciliation_batches
  where shop_id = p_shop_id and business_date = p_business_date
  for update;
  if found then
    return jsonb_build_object(
      'batch_id', v_batch.id,
      'shop_id', v_batch.shop_id,
      'business_date', v_batch.business_date,
      'status', v_batch.status,
      'expected_total_minor', v_batch.expected_total_minor,
      'collected_total_minor', v_batch.collected_total_minor,
      'variance_minor', v_batch.variance_minor,
      'idempotent', true
    );
  end if;

  select coalesce(sum(o.cod_expected_minor), 0)
  into v_expected
  from merchant_orders o
  where o.shop_id = p_shop_id
    and o.payment_provider_code = 'cash'
    and o.cod_expected_minor > 0
    and o.created_at::date = p_business_date;

  insert into cod_reconciliation_batches(
    merchant_id, shop_id, business_date, note, created_by_user_id,
    expected_total_minor
  ) values(
    v_merchant, p_shop_id, p_business_date, nullif(trim(p_note), ''), v_user,
    v_expected
  ) returning * into v_batch;

  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(
    v_user,
    'cod.reconciliation_batch_opened',
    'cod_reconciliation_batch',
    v_batch.id::text,
    jsonb_build_object('shop_id', p_shop_id, 'business_date', p_business_date)
  );

  return jsonb_build_object(
    'batch_id', v_batch.id,
    'shop_id', v_batch.shop_id,
    'business_date', v_batch.business_date,
    'status', v_batch.status,
    'expected_total_minor', v_expected,
    'collected_total_minor', 0,
    'variance_minor', 0,
    'idempotent', false
  );
end;
$$;
revoke all on function private.open_cod_reconciliation_batch(uuid, date, text) from public, anon, authenticated;
grant execute on function private.open_cod_reconciliation_batch(uuid, date, text) to authenticated, service_role;

create or replace function public.open_cod_reconciliation_batch(
  p_shop_id uuid,
  p_business_date date,
  p_note text default null
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.open_cod_reconciliation_batch(p_shop_id, p_business_date, p_note);
$$;
revoke all on function public.open_cod_reconciliation_batch(uuid, date, text) from public, anon;
grant execute on function public.open_cod_reconciliation_batch(uuid, date, text) to authenticated;

create or replace function private.record_cod_collection(
  p_merchant_order_id uuid,
  p_collected_minor bigint,
  p_note text default null,
  p_reconciliation_batch_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_order merchant_orders%rowtype;
  v_record cod_collection_records%rowtype;
  v_batch cod_reconciliation_batches%rowtype;
  v_status text;
  v_next_payment_status text;
begin
  if v_user is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;
  select * into v_order
  from merchant_orders
  where id = p_merchant_order_id
    and (
      merchant_id in (select private.current_merchant_ids())
      or private.is_admin()
      or exists (
        select 1 from order_courier_assignments a
        where a.merchant_order_id = merchant_orders.id
          and a.courier_user_id = v_user
          and a.status in ('assigned','picked_up','out_for_delivery')
      )
    )
  for update;
  if not found then
    raise exception using errcode = '42501', message = 'ORDER_NOT_FOUND';
  end if;
  if v_order.payment_provider_code <> 'cash' or v_order.cod_expected_minor <= 0 then
    raise exception using errcode = 'P0001', message = 'COD_NOT_APPLICABLE';
  end if;
  if v_order.payment_status in ('paid', 'cancelled') then
    raise exception using errcode = 'P0001', message = 'COD_ALREADY_FINAL';
  end if;
  if p_collected_minor is null or p_collected_minor < 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_COD_AMOUNT';
  end if;
  if p_reconciliation_batch_id is not null then
    select * into v_batch
    from cod_reconciliation_batches
    where id = p_reconciliation_batch_id
      and shop_id = v_order.shop_id
      and merchant_id = v_order.merchant_id
      and status = 'open'
    for update;
    if not found then
      raise exception using errcode = 'P0001', message = 'COD_BATCH_NOT_OPEN';
    end if;
  end if;

  v_status := case when p_collected_minor = v_order.cod_expected_minor then 'collected' else 'mismatch' end;
  v_next_payment_status := case when v_status = 'collected' then 'paid' else v_order.payment_status end;
  insert into cod_collection_records(
    merchant_order_id, reconciliation_batch_id, recorded_by_user_id,
    expected_minor, collected_minor, status, note
  ) values(
    v_order.id, p_reconciliation_batch_id, v_user,
    v_order.cod_expected_minor, p_collected_minor, v_status,
    nullif(trim(coalesce(p_note, '')), '')
  ) returning * into v_record;

  update merchant_orders
  set cod_collected_minor = p_collected_minor,
      cod_status = v_status,
      cod_collected_at = case when v_status = 'collected' then now() else cod_collected_at end,
      cod_reconciliation_note = nullif(trim(coalesce(p_note, '')), ''),
      payment_status = v_next_payment_status,
      updated_at = now()
  where id = v_order.id;

  insert into order_status_history(
    merchant_order_id, actor_user_id, event_type, previous_value, next_value, reason
  ) values(
    v_order.id, v_user, 'cod_collection_recorded', v_order.payment_status,
    v_next_payment_status, coalesce(p_note, v_status)
  );
  if v_status = 'collected' then
    insert into order_status_history(
      merchant_order_id, actor_user_id, event_type, previous_value, next_value, reason
    ) values(v_order.id, v_user, 'payment_reviewed', v_order.payment_status, 'paid', 'COD_EXACT_COLLECTION');
  end if;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(
    v_user,
    'payment.cod_collection_recorded',
    'merchant_order',
    v_order.id::text,
    jsonb_build_object(
      'expected_minor', v_order.cod_expected_minor,
      'collected_minor', p_collected_minor,
      'status', v_status,
      'record_id', v_record.id,
      'reconciliation_batch_id', p_reconciliation_batch_id
    )
  );
  return jsonb_build_object(
    'record_id', v_record.id,
    'cod_status', v_status,
    'payment_status', v_next_payment_status,
    'reconciliation_batch_id', p_reconciliation_batch_id
  );
end;
$$;
revoke all on function private.record_cod_collection(uuid, bigint, text) from public, anon, authenticated;
revoke all on function private.record_cod_collection(uuid, bigint, text, uuid) from public, anon, authenticated;
grant execute on function private.record_cod_collection(uuid, bigint, text) to authenticated, service_role;
grant execute on function private.record_cod_collection(uuid, bigint, text, uuid) to authenticated, service_role;

create or replace function public.record_cod_collection(
  p_merchant_order_id uuid,
  p_collected_minor bigint,
  p_note text default null
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.record_cod_collection(p_merchant_order_id, p_collected_minor, p_note, null);
$$;
revoke all on function public.record_cod_collection(uuid, bigint, text) from public, anon;
grant execute on function public.record_cod_collection(uuid, bigint, text) to authenticated;

create or replace function public.record_cod_collection(
  p_merchant_order_id uuid,
  p_collected_minor bigint,
  p_note text,
  p_reconciliation_batch_id uuid
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.record_cod_collection(p_merchant_order_id, p_collected_minor, p_note, p_reconciliation_batch_id);
$$;
revoke all on function public.record_cod_collection(uuid, bigint, text, uuid) from public, anon;
grant execute on function public.record_cod_collection(uuid, bigint, text, uuid) to authenticated;

create or replace function private.close_cod_reconciliation_batch(
  p_batch_id uuid,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_batch cod_reconciliation_batches%rowtype;
  v_expected bigint;
  v_collected bigint;
  v_variance bigint;
  v_status text;
begin
  if v_user is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;
  select * into v_batch
  from cod_reconciliation_batches
  where id = p_batch_id
    and (merchant_id in (select private.current_merchant_ids()) or private.is_admin())
  for update;
  if not found then
    raise exception using errcode = '42501', message = 'COD_BATCH_NOT_FOUND';
  end if;
  if v_batch.status <> 'open' then
    raise exception using errcode = 'P0001', message = 'COD_BATCH_ALREADY_CLOSED';
  end if;

  select coalesce(sum(o.cod_expected_minor), 0)
  into v_expected
  from merchant_orders o
  where o.shop_id = v_batch.shop_id
    and o.payment_provider_code = 'cash'
    and o.cod_expected_minor > 0
    and o.created_at::date = v_batch.business_date;

  select coalesce(sum(latest.collected_minor), 0)
  into v_collected
  from merchant_orders o
  left join lateral (
    select r.collected_minor
    from cod_collection_records r
    where r.merchant_order_id = o.id
    order by r.created_at desc, r.id desc
    limit 1
  ) latest on true
  where o.shop_id = v_batch.shop_id
    and o.payment_provider_code = 'cash'
    and o.cod_expected_minor > 0
    and o.created_at::date = v_batch.business_date;
  v_variance := v_collected - v_expected;
  v_status := case when v_variance = 0 then 'reconciled' else 'variance' end;

  update cod_reconciliation_batches
  set status = v_status,
      expected_total_minor = v_expected,
      collected_total_minor = v_collected,
      variance_minor = v_variance,
      note = coalesce(nullif(trim(p_note), ''), note),
      closed_by_user_id = v_user,
      closed_at = now(),
      updated_at = now()
  where id = p_batch_id;

  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(
    v_user,
    'cod.reconciliation_batch_closed',
    'cod_reconciliation_batch',
    p_batch_id::text,
    jsonb_build_object(
      'expected_total_minor', v_expected,
      'collected_total_minor', v_collected,
      'variance_minor', v_variance,
      'status', v_status
    )
  );

  return jsonb_build_object(
    'batch_id', p_batch_id,
    'status', v_status,
    'expected_total_minor', v_expected,
    'collected_total_minor', v_collected,
    'variance_minor', v_variance
  );
end;
$$;
revoke all on function private.close_cod_reconciliation_batch(uuid, text) from public, anon, authenticated;
grant execute on function private.close_cod_reconciliation_batch(uuid, text) to authenticated, service_role;

create or replace function public.close_cod_reconciliation_batch(
  p_batch_id uuid,
  p_note text default null
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.close_cod_reconciliation_batch(p_batch_id, p_note);
$$;
revoke all on function public.close_cod_reconciliation_batch(uuid, text) from public, anon;
grant execute on function public.close_cod_reconciliation_batch(uuid, text) to authenticated;

create or replace function private.merchant_cod_reconciliation(
  p_shop_id uuid,
  p_business_date date,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_batch cod_reconciliation_batches%rowtype;
  v_rows jsonb;
begin
  if v_user is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;
  if p_limit is null or p_limit < 1 or p_limit > 100 or p_offset is null or p_offset < 0 or p_offset > 10000 then
    raise exception using errcode = 'P0001', message = 'INVALID_COD_PAGINATION';
  end if;
  if not exists (
    select 1 from shops s
    where s.id = p_shop_id
      and (s.merchant_id in (select private.current_merchant_ids()) or private.is_admin())
  ) then
    raise exception using errcode = '42501', message = 'SHOP_NOT_OWNED';
  end if;

  select * into v_batch
  from cod_reconciliation_batches
  where shop_id = p_shop_id and business_date = p_business_date;

  select coalesce(jsonb_agg(row_json order by created_at desc), '[]'::jsonb)
  into v_rows
  from (
    select
      o.created_at,
      jsonb_build_object(
        'record_id', latest.id,
        'merchant_order_id', o.id,
        'order_reference', o.order_reference,
        'expected_minor', o.cod_expected_minor,
        'collected_minor', coalesce(latest.collected_minor, 0),
        'status', coalesce(latest.status, 'expected'),
        'note', latest.note,
        'created_at', coalesce(latest.created_at, o.created_at)
      ) as row_json
    from merchant_orders o
    left join lateral (
      select r.id, r.collected_minor, r.status, r.note, r.created_at
      from cod_collection_records r
      where r.merchant_order_id = o.id
      order by r.created_at desc, r.id desc
      limit 1
    ) latest on true
    where o.shop_id = p_shop_id
      and o.payment_provider_code = 'cash'
      and o.cod_expected_minor > 0
      and o.created_at::date = p_business_date
    order by o.created_at desc, o.id desc
    limit p_limit offset p_offset
  ) rows;

  return jsonb_build_object(
    'batch', case when v_batch.id is null then null else jsonb_build_object(
      'batch_id', v_batch.id,
      'shop_id', v_batch.shop_id,
      'business_date', v_batch.business_date,
      'status', v_batch.status,
      'expected_total_minor', v_batch.expected_total_minor,
      'collected_total_minor', v_batch.collected_total_minor,
      'variance_minor', v_batch.variance_minor,
      'note', v_batch.note,
      'closed_at', v_batch.closed_at
    ) end,
    'rows', v_rows,
    'limit', p_limit,
    'offset', p_offset
  );
end;
$$;
revoke all on function private.merchant_cod_reconciliation(uuid, date, integer, integer) from public, anon, authenticated;
grant execute on function private.merchant_cod_reconciliation(uuid, date, integer, integer) to authenticated, service_role;

create or replace function public.merchant_cod_reconciliation(
  p_shop_id uuid,
  p_business_date date,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.merchant_cod_reconciliation(p_shop_id, p_business_date, p_limit, p_offset);
$$;
revoke all on function public.merchant_cod_reconciliation(uuid, date, integer, integer) from public, anon;
grant execute on function public.merchant_cod_reconciliation(uuid, date, integer, integer) to authenticated;

create or replace function private.merchant_order_workbench(
  p_shop_id uuid,
  p_fulfilment_status text default null,
  p_payment_status text default null,
  p_cod_status text default null,
  p_query text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns setof jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
begin
  if auth.uid() is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;
  if p_limit is null or p_limit < 1 or p_limit > 100 or p_offset is null or p_offset < 0 or p_offset > 10000 then
    raise exception using errcode = 'P0001', message = 'INVALID_ORDER_WORKBENCH_PAGINATION';
  end if;
  if p_fulfilment_status is not null and p_fulfilment_status not in ('pending', 'ready', 'arranged', 'completed', 'cancelled') then
    raise exception using errcode = 'P0001', message = 'INVALID_FULFILMENT_FILTER';
  end if;
  if p_payment_status is not null and p_payment_status not in ('awaiting_payment', 'payment_under_review', 'paid', 'rejected', 'cancelled') then
    raise exception using errcode = 'P0001', message = 'INVALID_PAYMENT_FILTER';
  end if;
  if p_cod_status is not null and p_cod_status not in ('not_applicable', 'expected', 'collected', 'mismatch', 'waived') then
    raise exception using errcode = 'P0001', message = 'INVALID_COD_FILTER';
  end if;
  if not exists (
    select 1 from shops s
    where s.id = p_shop_id
      and (s.merchant_id in (select private.current_merchant_ids()) or private.is_admin())
  ) then
    raise exception using errcode = '42501', message = 'SHOP_NOT_OWNED';
  end if;

  return query
  select jsonb_build_object(
    'id', o.id,
    'order_reference', o.order_reference,
    'shop_id', o.shop_id,
    'payment_status', o.payment_status,
    'fulfilment_status', o.fulfilment_status,
    'cod_status', o.cod_status,
    'currency', o.currency,
    'subtotal_minor', o.subtotal_minor,
    'fee_minor', o.fee_minor,
    'tax_minor', o.tax_minor,
    'total_minor', o.total_minor,
    'cod_expected_minor', o.cod_expected_minor,
    'cod_collected_minor', o.cod_collected_minor,
    'fulfilment_method', o.fulfilment_method,
    'created_at', o.created_at,
    'updated_at', o.updated_at,
    'item_count', (select count(*) from merchant_order_items i where i.merchant_order_id = o.id),
    'has_open_case', exists(select 1 from order_cases c where c.merchant_order_id = o.id and c.status in ('open', 'reviewing')),
    'has_active_courier_assignment', exists(select 1 from order_courier_assignments a where a.merchant_order_id = o.id and a.status in ('assigned', 'picked_up', 'out_for_delivery'))
  )
  from merchant_orders o
  where o.shop_id = p_shop_id
    and (p_fulfilment_status is null or o.fulfilment_status = p_fulfilment_status)
    and (p_payment_status is null or o.payment_status = p_payment_status)
    and (p_cod_status is null or o.cod_status = p_cod_status)
    and (nullif(trim(p_query), '') is null or o.order_reference ilike '%' || trim(p_query) || '%')
  order by o.created_at desc, o.id desc
  limit p_limit offset p_offset;
end;
$$;
revoke all on function private.merchant_order_workbench(uuid, text, text, text, text, integer, integer) from public, anon, authenticated;
grant execute on function private.merchant_order_workbench(uuid, text, text, text, text, integer, integer) to authenticated, service_role;

create or replace function public.merchant_order_workbench(
  p_shop_id uuid,
  p_fulfilment_status text default null,
  p_payment_status text default null,
  p_cod_status text default null,
  p_query text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns setof jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select * from private.merchant_order_workbench(p_shop_id, p_fulfilment_status, p_payment_status, p_cod_status, p_query, p_limit, p_offset);
$$;
revoke all on function public.merchant_order_workbench(uuid, text, text, text, text, integer, integer) from public, anon;
grant execute on function public.merchant_order_workbench(uuid, text, text, text, text, integer, integer) to authenticated;

insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
select null, 'schema.order_workbench_cod_reconciliation_ready', 'schema', '20260826_0033', jsonb_build_object('tables', jsonb_build_array('cod_reconciliation_batches'), 'rpc_count', 5)
where not exists (
  select 1 from audit_events where action = 'schema.order_workbench_cod_reconciliation_ready' and resource_id = '20260826_0033'
);
