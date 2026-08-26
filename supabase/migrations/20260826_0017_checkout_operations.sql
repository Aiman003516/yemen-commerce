-- Yemen-first checkout operations.
--
-- This migration keeps the existing one-merchant-order-per-shop invariant while
-- adding delivery snapshots, optional location reservations, and COD records.
-- No provider API is called here and the platform never becomes a fund custodian.

alter table public.merchant_orders
  add column if not exists delivery_service_area_id uuid references public.market_service_areas(id) on delete set null,
  add column if not exists delivery_eta_min_minutes integer,
  add column if not exists delivery_eta_max_minutes integer,
  add column if not exists delivery_snapshot_version integer not null default 1,
  add column if not exists cod_expected_minor bigint not null default 0,
  add column if not exists cod_collected_minor bigint not null default 0,
  add column if not exists cod_status text not null default 'not_applicable',
  add column if not exists cod_collected_at timestamptz,
  add column if not exists cod_reconciliation_note text;

alter table public.merchant_orders
  drop constraint if exists merchant_orders_delivery_eta_check;
alter table public.merchant_orders
  add constraint merchant_orders_delivery_eta_check
  check (
    (delivery_eta_min_minutes is null or delivery_eta_min_minutes >= 0)
    and (delivery_eta_max_minutes is null
      or delivery_eta_max_minutes >= coalesce(delivery_eta_min_minutes, 0))
  );

alter table public.merchant_orders
  drop constraint if exists merchant_orders_cod_status_check;
alter table public.merchant_orders
  add constraint merchant_orders_cod_status_check
  check (cod_status in ('not_applicable', 'expected', 'collected', 'mismatch', 'waived'));

alter table public.merchant_orders
  drop constraint if exists merchant_orders_cod_amounts_check;
alter table public.merchant_orders
  add constraint merchant_orders_cod_amounts_check
  check (
    cod_expected_minor >= 0
    and cod_collected_minor >= 0
    and cod_collected_minor <= greatest(cod_expected_minor, cod_collected_minor)
  );

create table if not exists public.inventory_reservations (
  id uuid primary key default gen_random_uuid(),
  merchant_order_id uuid not null references public.merchant_orders(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  location_id uuid not null references public.inventory_locations(id) on delete restrict,
  quantity integer not null check (quantity > 0),
  status text not null default 'reserved' check (status in ('reserved', 'released', 'fulfilled')),
  created_at timestamptz not null default now(),
  released_at timestamptz,
  fulfilled_at timestamptz,
  unique (merchant_order_id, product_id, location_id)
);
create index if not exists inventory_reservations_order_status_idx
  on public.inventory_reservations(merchant_order_id, status);
create index if not exists inventory_reservations_location_status_idx
  on public.inventory_reservations(location_id, status);

create table if not exists public.cod_collection_records (
  id uuid primary key default gen_random_uuid(),
  merchant_order_id uuid not null references public.merchant_orders(id) on delete cascade,
  recorded_by_user_id uuid not null references public.profiles(id) on delete restrict,
  expected_minor bigint not null check (expected_minor >= 0),
  collected_minor bigint not null check (collected_minor >= 0),
  status text not null check (status in ('collected', 'mismatch', 'waived')),
  note text,
  created_at timestamptz not null default now()
);
create index if not exists cod_collection_records_order_idx
  on public.cod_collection_records(merchant_order_id, created_at desc);

alter table public.inventory_reservations enable row level security;
alter table public.cod_collection_records enable row level security;
grant select on public.inventory_reservations, public.cod_collection_records to authenticated;

drop policy if exists inventory_reservations_participant_read on public.inventory_reservations;
create policy inventory_reservations_participant_read
on public.inventory_reservations for select to authenticated
using (
  exists (
    select 1 from public.merchant_orders o
    where o.id = merchant_order_id
      and (o.customer_user_id = (select auth.uid())
        or o.merchant_id in (select private.current_merchant_ids())
        or private.is_admin())
  )
);

drop policy if exists cod_collection_records_participant_read on public.cod_collection_records;
create policy cod_collection_records_participant_read
on public.cod_collection_records for select to authenticated
using (
  exists (
    select 1 from public.merchant_orders o
    where o.id = merchant_order_id
      and (o.customer_user_id = (select auth.uid())
        or o.merchant_id in (select private.current_merchant_ids())
        or private.is_admin())
  )
);

create or replace function private.prevent_cod_record_mutation()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_catalog
as $$
begin
  raise exception using errcode = '42501', message = 'COD_RECORD_APPEND_ONLY';
end;
$$;
revoke all on function private.prevent_cod_record_mutation() from public, anon, authenticated;
drop trigger if exists cod_collection_records_immutable on public.cod_collection_records;
create trigger cod_collection_records_immutable
before update or delete on public.cod_collection_records
for each row execute function private.prevent_cod_record_mutation();

create or replace function private.checkout_create_orders(
  p_market_id uuid,
  p_fulfilment_by_shop jsonb,
  p_payment_by_merchant jsonb,
  p_delivery_by_shop jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_cart carts%rowtype;
  v_session checkout_sessions%rowtype;
  v_group record;
  v_item record;
  v_fulfilment text;
  v_payment_id uuid;
  v_method payment_methods%rowtype;
  v_order merchant_orders%rowtype;
  v_subtotal bigint;
  v_delivery_fee bigint;
  v_total bigint;
  v_order_ids jsonb := '[]'::jsonb;
  v_delivery jsonb;
  v_address customer_addresses%rowtype;
  v_zone merchant_delivery_zones%rowtype;
  v_pickup pickup_points%rowtype;
  v_address_id uuid;
  v_zone_id uuid;
  v_pickup_point_id uuid;
  v_service_area_id uuid;
  v_delivery_snapshot jsonb := '{}'::jsonb;
  v_cod_expected bigint;
  v_location_id uuid;
  v_inventory product_location_inventory%rowtype;
  v_has_location_inventory boolean;
begin
  if v_user is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;
  if not exists(select 1 from markets where id = p_market_id and status = 'active') then
    raise exception using errcode = 'P0001', message = 'MARKET_UNAVAILABLE';
  end if;

  select * into v_cart from carts
  where customer_user_id = v_user and market_id = p_market_id
  for update;
  if not found or not exists(select 1 from cart_items where cart_id = v_cart.id) then
    raise exception using errcode = 'P0001', message = 'CART_EMPTY';
  end if;

  insert into checkout_sessions(customer_user_id, market_id, status)
  values (v_user, p_market_id, 'created') returning * into v_session;

  for v_group in
    select s.id as shop_id,
           s.merchant_id,
           s.name as shop_name,
           sum(p.price_minor * ci.quantity)::bigint as subtotal_minor
    from cart_items ci
    join products p on p.id = ci.product_id
    join shops s on s.id = p.shop_id
    where ci.cart_id = v_cart.id
    group by s.id, s.merchant_id, s.name
    order by s.id
  loop
    v_delivery := coalesce(
      (
        select x
        from jsonb_array_elements(coalesce(p_delivery_by_shop, '[]'::jsonb)) x
        where nullif(x->>'shop_id', '')::uuid = v_group.shop_id
        limit 1
      ),
      '{}'::jsonb
    );

    select x->>'method' into v_fulfilment
    from jsonb_array_elements(coalesce(p_fulfilment_by_shop, '[]'::jsonb)) x
    where nullif(x->>'shop_id', '')::uuid = v_group.shop_id
    limit 1;
    if v_fulfilment is null or not exists(
      select 1 from shop_fulfilment_methods sf
      where sf.shop_id = v_group.shop_id
        and sf.method = v_fulfilment
        and sf.is_active
    ) then
      raise exception using errcode = 'P0001', message = 'FULFILMENT_UNAVAILABLE';
    end if;

    select (x->>'payment_method_id')::uuid into v_payment_id
    from jsonb_array_elements(coalesce(p_payment_by_merchant, '[]'::jsonb)) x
    where nullif(x->>'merchant_id', '')::uuid = v_group.merchant_id
    limit 1;
    select * into v_method
    from payment_methods
    where id = v_payment_id
      and merchant_id = v_group.merchant_id
      and is_active
      and mode = 'manual'
    for update;
    if not found then
      raise exception using errcode = 'P0001', message = 'PAYMENT_METHOD_UNAVAILABLE';
    end if;

    v_address_id := nullif(v_delivery->>'address_id', '')::uuid;
    v_zone_id := nullif(v_delivery->>'delivery_zone_id', '')::uuid;
    v_pickup_point_id := nullif(v_delivery->>'pickup_point_id', '')::uuid;
    v_service_area_id := null;
    v_delivery_fee := 0;
    v_delivery_snapshot := '{}'::jsonb;

    if v_fulfilment = 'seller_arranged' then
      if v_address_id is null then
        raise exception using errcode = 'P0001', message = 'DELIVERY_ADDRESS_REQUIRED';
      end if;
      select * into v_address
      from customer_addresses
      where id = v_address_id
        and customer_user_id = v_user
        and market_id = p_market_id
        and is_active
      for update;
      if not found or v_address.service_area_id is null then
        raise exception using errcode = 'P0001', message = 'DELIVERY_ADDRESS_UNAVAILABLE';
      end if;
      v_service_area_id := v_address.service_area_id;

      select * into v_zone
      from merchant_delivery_zones
      where id = coalesce(v_zone_id, id)
        and shop_id = v_group.shop_id
        and service_area_id = v_service_area_id
        and is_active
      order by updated_at desc
      limit 1
      for update;
      if not found then
        raise exception using errcode = 'P0001', message = 'DELIVERY_ZONE_UNAVAILABLE';
      end if;
      if v_zone.currency <> v_method.currency then
        raise exception using errcode = 'P0001', message = 'DELIVERY_CURRENCY_MISMATCH';
      end if;
      v_zone_id := v_zone.id;
      v_delivery_fee := v_zone.fee_minor;
      v_delivery_snapshot := jsonb_build_object(
        'version', 1,
        'type', 'address',
        'address_id', v_address.id,
        'label', v_address.label,
        'recipient_name', v_address.recipient_name,
        'phone', v_address.phone,
        'address_line', v_address.address_line,
        'landmark', v_address.landmark,
        'city', v_address.city,
        'district', v_address.district,
        'service_area_id', v_service_area_id,
        'zone_id', v_zone.id
      );
    elsif v_fulfilment = 'collection' and v_pickup_point_id is not null then
      select * into v_pickup
      from pickup_points
      where id = v_pickup_point_id
        and market_id = p_market_id
        and status = 'active'
      for update;
      if not found then
        raise exception using errcode = 'P0001', message = 'PICKUP_POINT_UNAVAILABLE';
      end if;
      v_service_area_id := v_pickup.service_area_id;
      v_delivery_snapshot := jsonb_build_object(
        'version', 1,
        'type', 'pickup',
        'pickup_point_id', v_pickup.id,
        'name_ar', v_pickup.name_ar,
        'address_details', v_pickup.address_details,
        'contact_phone', v_pickup.contact_phone,
        'operating_hours', v_pickup.operating_hours,
        'service_area_id', v_pickup.service_area_id
      );
    elsif v_fulfilment = 'collection' then
      v_delivery_snapshot := jsonb_build_object('version', 1, 'type', 'collection');
    elsif v_fulfilment = 'digital' then
      v_delivery_snapshot := jsonb_build_object('version', 1, 'type', 'digital');
    end if;

    v_subtotal := v_group.subtotal_minor;
    v_total := v_subtotal + v_delivery_fee;
    v_cod_expected := case when v_method.provider_code = 'cash' then v_total else 0 end;

    insert into merchant_orders(
      checkout_session_id,
      merchant_id,
      shop_id,
      customer_user_id,
      market_id,
      order_reference,
      currency,
      subtotal_minor,
      fee_minor,
      tax_minor,
      total_minor,
      payment_method_name,
      payment_method_id,
      payment_provider_code,
      payment_provider_metadata,
      account_holder_name,
      receiving_identifier,
      payment_instructions,
      proof_requirement,
      fulfilment_method,
      fulfilment_instructions,
      delivery_address_snapshot,
      pickup_point_id,
      delivery_zone_id,
      delivery_service_area_id,
      delivery_fee_minor,
      delivery_eta_min_minutes,
      delivery_eta_max_minutes,
      delivery_snapshot_version,
      cod_expected_minor,
      cod_status
    )
    select v_session.id,
           v_group.merchant_id,
           v_group.shop_id,
           v_user,
           p_market_id,
           'YC-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10)),
           v_method.currency,
           v_subtotal,
           v_delivery_fee,
           0,
           v_total,
           v_method.name,
           v_method.id,
           v_method.provider_code,
           v_method.provider_metadata,
           v_method.account_holder_name,
           v_method.receiving_identifier,
           v_method.customer_instructions,
           case when v_method.provider_code = 'cash' then 'none' else v_method.proof_requirement end,
           v_fulfilment,
           sf.instructions,
           v_delivery_snapshot,
           v_pickup_point_id,
           v_zone_id,
           v_service_area_id,
           v_delivery_fee,
           case when v_zone_id is not null then v_zone.eta_min_minutes else null end,
           case when v_zone_id is not null then v_zone.eta_max_minutes else null end,
           1,
           v_cod_expected,
           case when v_cod_expected > 0 then 'expected' else 'not_applicable' end
    from shop_fulfilment_methods sf
    where sf.shop_id = v_group.shop_id
      and sf.method = v_fulfilment
      and sf.is_active
    returning * into v_order;

    for v_item in
      select p.id,
             p.name,
             p.price_minor,
             p.stock_quantity,
             p.status,
             ci.quantity
      from cart_items ci
      join products p on p.id = ci.product_id
      where ci.cart_id = v_cart.id
        and p.shop_id = v_group.shop_id
      for update of p
    loop
      if v_item.status <> 'active' or v_item.stock_quantity < v_item.quantity then
        raise exception using errcode = 'P0001', message = 'STOCK_CHANGED';
      end if;
      insert into merchant_order_items(
        merchant_order_id, product_id, product_name, unit_price_minor, quantity, line_total_minor
      ) values(
        v_order.id, v_item.id, v_item.name, v_item.price_minor,
        v_item.quantity, v_item.price_minor * v_item.quantity
      );

      select il.id into v_location_id
      from inventory_locations il
      where il.shop_id = v_group.shop_id
        and il.status = 'active'
      order by il.is_default desc, il.created_at
      limit 1
      for update;
      v_has_location_inventory := false;
      if v_location_id is not null then
        select * into v_inventory
        from product_location_inventory
        where product_id = v_item.id and location_id = v_location_id
        for update;
        v_has_location_inventory := found;
      end if;

      if v_has_location_inventory then
        if v_inventory.stock_quantity - v_inventory.reserved_quantity < v_item.quantity then
          raise exception using errcode = 'P0001', message = 'STOCK_CHANGED';
        end if;
        update product_location_inventory
        set reserved_quantity = reserved_quantity + v_item.quantity,
            updated_at = now()
        where product_id = v_item.id and location_id = v_location_id;
        insert into inventory_reservations(merchant_order_id, product_id, location_id, quantity)
        values(v_order.id, v_item.id, v_location_id, v_item.quantity);
      else
        update products
        set stock_quantity = stock_quantity - v_item.quantity,
            status = case when stock_quantity - v_item.quantity = 0 then 'out_of_stock' else status end
        where id = v_item.id;
      end if;
    end loop;

    insert into order_status_history(
      merchant_order_id, actor_user_id, event_type, previous_value, next_value, reason
    ) values (v_order.id, v_user, 'order_created', null, 'awaiting_payment',
              case when v_cod_expected > 0 then 'COD_EXPECTED' else null end);

    insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
    values(
      v_user,
      'checkout.merchant_order_created',
      'merchant_order',
      v_order.id::text,
      jsonb_build_object(
        'order_reference', v_order.order_reference,
        'merchant_id', v_order.merchant_id,
        'payment_provider_code', v_order.payment_provider_code,
        'delivery_fee_minor', v_delivery_fee,
        'cod_expected_minor', v_cod_expected
      )
    );

    v_order_ids := v_order_ids || jsonb_build_object(
      'id', v_order.id,
      'order_reference', v_order.order_reference,
      'merchant_id', v_order.merchant_id,
      'total_minor', v_order.total_minor,
      'delivery_fee_minor', v_delivery_fee,
      'cod_status', v_order.cod_status
    );
  end loop;

  delete from cart_items where cart_id = v_cart.id;
  update checkout_sessions set status = 'completed' where id = v_session.id;
  return jsonb_build_object('checkout_session_id', v_session.id, 'orders', v_order_ids);
end;
$$;
revoke all on function private.checkout_create_orders(uuid, jsonb, jsonb, jsonb) from public, anon;
grant execute on function private.checkout_create_orders(uuid, jsonb, jsonb, jsonb) to authenticated, service_role;

create or replace function private.checkout_create_orders(
  p_market_id uuid,
  p_fulfilment_by_shop jsonb,
  p_payment_by_merchant jsonb
)
returns jsonb
language sql
security definer
set search_path = public, private, pg_catalog
as $$
  select private.checkout_create_orders(p_market_id, p_fulfilment_by_shop, p_payment_by_merchant, '[]'::jsonb);
$$;
revoke all on function private.checkout_create_orders(uuid, jsonb, jsonb) from public, anon;
grant execute on function private.checkout_create_orders(uuid, jsonb, jsonb) to authenticated, service_role;

create or replace function public.checkout_create_orders(
  p_market_id uuid,
  p_fulfilment_by_shop jsonb,
  p_payment_by_merchant jsonb
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.checkout_create_orders(p_market_id, p_fulfilment_by_shop, p_payment_by_merchant, '[]'::jsonb);
$$;
revoke all on function public.checkout_create_orders(uuid, jsonb, jsonb) from public, anon;
grant execute on function public.checkout_create_orders(uuid, jsonb, jsonb) to authenticated, service_role;

create or replace function public.checkout_create_orders(
  p_market_id uuid,
  p_fulfilment_by_shop jsonb,
  p_payment_by_merchant jsonb,
  p_delivery_by_shop jsonb default '[]'::jsonb
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.checkout_create_orders(p_market_id, p_fulfilment_by_shop, p_payment_by_merchant, p_delivery_by_shop);
$$;
revoke all on function public.checkout_create_orders(uuid, jsonb, jsonb, jsonb) from public, anon;
grant execute on function public.checkout_create_orders(uuid, jsonb, jsonb, jsonb) to authenticated, service_role;

create or replace function private.record_cod_collection(
  p_merchant_order_id uuid,
  p_collected_minor bigint,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_order merchant_orders%rowtype;
  v_status text;
  v_next_payment_status text;
  v_record cod_collection_records%rowtype;
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

  v_status := case when p_collected_minor = v_order.cod_expected_minor then 'collected' else 'mismatch' end;
  v_next_payment_status := case when v_status = 'collected' then 'paid' else v_order.payment_status end;
  insert into cod_collection_records(
    merchant_order_id, recorded_by_user_id, expected_minor, collected_minor, status, note
  ) values(
    v_order.id, v_user, v_order.cod_expected_minor, p_collected_minor, v_status,
    nullif(trim(coalesce(p_note, '')), '')
  ) returning * into v_record;

  update merchant_orders
  set cod_collected_minor = p_collected_minor,
      cod_status = v_status,
      cod_collected_at = case when v_status = 'collected' then now() else cod_collected_at end,
      cod_reconciliation_note = nullif(trim(coalesce(p_note, '')), ''),
      payment_status = v_next_payment_status
  where id = v_order.id;

  insert into order_status_history(
    merchant_order_id, actor_user_id, event_type, previous_value, next_value, reason
  ) values(
    v_order.id, v_user, 'cod_collection_recorded', v_order.payment_status, v_next_payment_status,
    coalesce(p_note, v_status)
  );
  if v_status = 'collected' then
    insert into order_status_history(
      merchant_order_id, actor_user_id, event_type, previous_value, next_value, reason
    ) values(v_order.id, v_user, 'payment_reviewed', v_order.payment_status, 'paid', 'COD_EXACT_COLLECTION');
  end if;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'payment.cod_collection_recorded', 'merchant_order', v_order.id::text,
         jsonb_build_object('expected_minor', v_order.cod_expected_minor,
                            'collected_minor', p_collected_minor,
                            'status', v_status,
                            'record_id', v_record.id));
  return jsonb_build_object(
    'record_id', v_record.id,
    'cod_status', v_status,
    'payment_status', v_next_payment_status
  );
end;
$$;
revoke all on function private.record_cod_collection(uuid, bigint, text) from public, anon;
grant execute on function private.record_cod_collection(uuid, bigint, text) to authenticated, service_role;

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
  select private.record_cod_collection(p_merchant_order_id, p_collected_minor, p_note);
$$;
revoke all on function public.record_cod_collection(uuid, bigint, text) from public, anon;
grant execute on function public.record_cod_collection(uuid, bigint, text) to authenticated;

create or replace function private.release_order_stock(p_merchant_order_id uuid, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_order merchant_orders%rowtype;
  v_reservation record;
  v_count integer := 0;
begin
  select * into v_order from merchant_orders
  where id = p_merchant_order_id
    and (merchant_id in (select private.current_merchant_ids()) or private.is_admin())
  for update;
  if not found then raise exception using errcode = '42501', message = 'ORDER_NOT_FOUND'; end if;
  if v_order.fulfilment_status <> 'cancelled' then
    raise exception using errcode = 'P0001', message = 'ORDER_MUST_BE_CANCELLED';
  end if;

  for v_reservation in
    select r.* from inventory_reservations r
    where r.merchant_order_id = v_order.id and r.status = 'reserved'
    for update
  loop
    update product_location_inventory
    set reserved_quantity = reserved_quantity - v_reservation.quantity,
        updated_at = now()
    where product_id = v_reservation.product_id
      and location_id = v_reservation.location_id
      and reserved_quantity >= v_reservation.quantity;
    update inventory_reservations
    set status = 'released', released_at = now()
    where id = v_reservation.id;
    v_count := v_count + 1;
  end loop;

  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'inventory.reservation_released', 'merchant_order', v_order.id::text,
         jsonb_build_object('reservation_count', v_count, 'reason', p_reason));
  return jsonb_build_object('released_count', v_count);
end;
$$;
revoke all on function private.release_order_stock(uuid, text) from public, anon;
grant execute on function private.release_order_stock(uuid, text) to authenticated, service_role;

create or replace function public.release_order_stock(p_merchant_order_id uuid, p_reason text default null)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.release_order_stock(p_merchant_order_id, p_reason);
$$;
revoke all on function public.release_order_stock(uuid, text) from public, anon;
grant execute on function public.release_order_stock(uuid, text) to authenticated;

create or replace function private.finalize_order_stock(p_merchant_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_order merchant_orders%rowtype;
  v_reservation record;
  v_count integer := 0;
begin
  select * into v_order from merchant_orders
  where id = p_merchant_order_id
    and (merchant_id in (select private.current_merchant_ids()) or private.is_admin())
  for update;
  if not found then raise exception using errcode = '42501', message = 'ORDER_NOT_FOUND'; end if;
  if v_order.fulfilment_status <> 'completed' or v_order.payment_status <> 'paid' then
    raise exception using errcode = 'P0001', message = 'ORDER_NOT_READY_TO_FINALIZE_STOCK';
  end if;

  for v_reservation in
    select r.* from inventory_reservations r
    where r.merchant_order_id = v_order.id and r.status = 'reserved'
    for update
  loop
    update product_location_inventory
    set stock_quantity = stock_quantity - v_reservation.quantity,
        reserved_quantity = reserved_quantity - v_reservation.quantity,
        updated_at = now()
    where product_id = v_reservation.product_id
      and location_id = v_reservation.location_id
      and stock_quantity - reserved_quantity >= v_reservation.quantity
      and reserved_quantity >= v_reservation.quantity;
    if not found then
      raise exception using errcode = 'P0001', message = 'STOCK_FINALIZATION_CONFLICT';
    end if;
    update inventory_reservations
    set status = 'fulfilled', fulfilled_at = now()
    where id = v_reservation.id;
    v_count := v_count + 1;
  end loop;

  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'inventory.reservation_fulfilled', 'merchant_order', v_order.id::text,
         jsonb_build_object('reservation_count', v_count));
  return jsonb_build_object('fulfilled_count', v_count);
end;
$$;
revoke all on function private.finalize_order_stock(uuid) from public, anon;
grant execute on function private.finalize_order_stock(uuid) to authenticated, service_role;

create or replace function public.finalize_order_stock(p_merchant_order_id uuid)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.finalize_order_stock(p_merchant_order_id);
$$;
revoke all on function public.finalize_order_stock(uuid) from public, anon;
grant execute on function public.finalize_order_stock(uuid) to authenticated;
