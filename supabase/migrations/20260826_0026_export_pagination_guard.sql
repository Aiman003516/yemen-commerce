-- Reject pathological export offsets instead of silently changing the requested page.
-- Export remains bounded to 500 rows per call and 10,000 skipped rows.

create or replace function private.export_merchant_b2b(
  p_shop_id uuid,
  p_limit integer default 100,
  p_offset integer default 0
)
returns setof jsonb
language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_limit integer := least(greatest(coalesce(p_limit, 100), 1), 500);
  v_offset integer := coalesce(p_offset, 0);
begin
  if v_user is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;
  if v_offset < 0 or v_offset > 10000 then
    raise exception using errcode = '22023', message = 'EXPORT_OFFSET_OUT_OF_RANGE';
  end if;
  if not exists (
    select 1 from shops s
    where s.id = p_shop_id
      and (s.merchant_id in (select private.current_merchant_ids()) or private.is_admin())
  ) then
    raise exception using errcode = '42501', message = 'SHOP_NOT_OWNED';
  end if;

  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(
    v_user,
    'b2b.analytics_exported',
    'shop',
    p_shop_id::text,
    jsonb_build_object('limit', v_limit, 'offset', v_offset, 'contains_identity', false)
  );

  return query
  select jsonb_build_object(
    'request_id', r.id,
    'shop_id', r.shop_id,
    'status', r.status,
    'requested_currency', r.requested_currency,
    'estimated_monthly_minor', r.estimated_monthly_minor,
    'has_approved_price_list', (r.approved_price_list_id is not null),
    'created_at', r.created_at,
    'updated_at', r.updated_at
  )
  from wholesale_requests r
  where r.shop_id = p_shop_id
  order by r.created_at desc, r.id desc
  limit v_limit offset v_offset;
end;
$$;
revoke all on function private.export_merchant_b2b(uuid, integer, integer) from public, anon, authenticated;
grant execute on function private.export_merchant_b2b(uuid, integer, integer) to authenticated, service_role;
create or replace function public.export_merchant_b2b(p_shop_id uuid, p_limit integer default 100, p_offset integer default 0)
returns setof jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select * from private.export_merchant_b2b(p_shop_id, p_limit, p_offset); $$;
revoke all on function public.export_merchant_b2b(uuid, integer, integer) from public, anon;
grant execute on function public.export_merchant_b2b(uuid, integer, integer) to authenticated;

create or replace function private.export_merchant_pos(
  p_shop_id uuid,
  p_from timestamptz default now() - interval '30 days',
  p_to timestamptz default now(),
  p_limit integer default 100,
  p_offset integer default 0
)
returns setof jsonb
language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_from timestamptz := coalesce(p_from, now() - interval '30 days');
  v_to timestamptz := coalesce(p_to, now());
  v_limit integer := least(greatest(coalesce(p_limit, 100), 1), 500);
  v_offset integer := coalesce(p_offset, 0);
begin
  if v_user is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;
  if v_from >= v_to or v_to - v_from > interval '366 days' then
    raise exception using errcode = '22023', message = 'INVALID_ANALYTICS_RANGE';
  end if;
  if v_offset < 0 or v_offset > 10000 then
    raise exception using errcode = '22023', message = 'EXPORT_OFFSET_OUT_OF_RANGE';
  end if;
  if not exists (
    select 1 from shops s
    where s.id = p_shop_id
      and (s.merchant_id in (select private.current_merchant_ids()) or private.is_admin())
  ) then
    raise exception using errcode = '42501', message = 'SHOP_NOT_OWNED';
  end if;

  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(
    v_user,
    'pos.analytics_exported',
    'shop',
    p_shop_id::text,
    jsonb_build_object('from', v_from, 'to', v_to, 'limit', v_limit, 'offset', v_offset, 'contains_line_items', false)
  );

  return query
  select jsonb_build_object(
    'pos_session_id', s.id,
    'shop_id', s.shop_id,
    'status', s.status,
    'reconciliation_status', s.reconciliation_status,
    'expected_total_minor', s.expected_total_minor,
    'counted_total_minor', s.counted_total_minor,
    'variance_minor', s.variance_minor,
    'opened_at', s.opened_at,
    'closed_at', s.closed_at,
    'sale_count', (select count(*) from pos_sales p where p.pos_session_id = s.id and p.created_at >= v_from and p.created_at < v_to),
    'gross_total_minor', coalesce((select sum(p.total_minor) from pos_sales p where p.pos_session_id = s.id and p.reconciliation_status <> 'voided' and p.created_at >= v_from and p.created_at < v_to), 0)
  )
  from pos_sessions s
  where s.shop_id = p_shop_id and s.opened_at >= v_from and s.opened_at < v_to
  order by s.opened_at desc, s.id desc
  limit v_limit offset v_offset;
end;
$$;
revoke all on function private.export_merchant_pos(uuid, timestamptz, timestamptz, integer, integer) from public, anon, authenticated;
grant execute on function private.export_merchant_pos(uuid, timestamptz, timestamptz, integer, integer) to authenticated, service_role;
create or replace function public.export_merchant_pos(p_shop_id uuid, p_from timestamptz default now() - interval '30 days', p_to timestamptz default now(), p_limit integer default 100, p_offset integer default 0)
returns setof jsonb language sql security invoker set search_path = public, pg_catalog
as $$ select * from private.export_merchant_pos(p_shop_id, p_from, p_to, p_limit, p_offset); $$;
revoke all on function public.export_merchant_pos(uuid, timestamptz, timestamptz, integer, integer) from public, anon;
grant execute on function public.export_merchant_pos(uuid, timestamptz, timestamptz, integer, integer) to authenticated;
