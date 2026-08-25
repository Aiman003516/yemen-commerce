-- Yemen-first payment-provider boundary.
-- Jaib and other providers remain manual until formal API approval, sandbox
-- testing, callback verification, and settlement/reconciliation are complete.

alter table public.payment_methods
  add column if not exists provider_code text not null default 'manual',
  add column if not exists provider_metadata jsonb not null default '{}'::jsonb;

alter table public.merchant_orders
  add column if not exists payment_provider_code text not null default 'manual',
  add column if not exists payment_provider_metadata jsonb not null default '{}'::jsonb;

alter table public.payment_methods
  drop constraint if exists payment_methods_provider_code_check;
alter table public.payment_methods
  add constraint payment_methods_provider_code_check
  check (provider_code in ('manual', 'jaib', 'kuraimi', 'cash', 'other'));

alter table public.payment_methods
  drop constraint if exists payment_methods_provider_metadata_object_check;
alter table public.payment_methods
  add constraint payment_methods_provider_metadata_object_check
  check (jsonb_typeof(provider_metadata) = 'object' and length(provider_metadata::text) <= 4000);

alter table public.merchant_orders
  drop constraint if exists merchant_orders_payment_provider_metadata_object_check;
alter table public.merchant_orders
  add constraint merchant_orders_payment_provider_metadata_object_check
  check (jsonb_typeof(payment_provider_metadata) = 'object' and length(payment_provider_metadata::text) <= 4000);

create index if not exists payment_methods_provider_idx
  on public.payment_methods(provider_code, is_active);

create index if not exists merchant_orders_provider_idx
  on public.merchant_orders(payment_provider_code, created_at desc);

create or replace function private.save_merchant_payment_method(
  p_id uuid,
  p_name text,
  p_account_holder_name text,
  p_receiving_identifier text,
  p_instructions text,
  p_proof_requirement text,
  p_provider_code text default 'manual',
  p_provider_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_merchant_id uuid;
  v_id uuid;
  v_provider_code text := lower(trim(coalesce(p_provider_code, 'manual')));
  v_metadata jsonb := coalesce(p_provider_metadata, '{}'::jsonb);
begin
  select id into v_merchant_id
  from merchants
  where owner_user_id = v_user
  order by created_at desc
  limit 1;

  if v_merchant_id is null then
    raise exception using errcode = '42501', message = 'MERCHANT_CONTEXT_REQUIRED';
  end if;

  if length(trim(p_name)) < 2
     or length(trim(p_account_holder_name)) < 2
     or length(trim(p_receiving_identifier)) < 3
     or length(trim(p_instructions)) < 10
     or p_proof_requirement not in ('none', 'reference', 'screenshot', 'both')
     or v_provider_code not in ('manual', 'jaib', 'kuraimi', 'cash', 'other')
     or jsonb_typeof(v_metadata) <> 'object'
     or length(v_metadata::text) > 4000 then
    raise exception using errcode = 'P0001', message = 'INVALID_PAYMENT_METHOD';
  end if;

  if p_id is null then
    insert into payment_methods(
      merchant_id,
      name,
      account_holder_name,
      receiving_identifier,
      customer_instructions,
      proof_requirement,
      mode,
      provider_verification,
      provider_code,
      provider_metadata
    )
    values(
      v_merchant_id,
      trim(p_name),
      trim(p_account_holder_name),
      trim(p_receiving_identifier),
      trim(p_instructions),
      p_proof_requirement,
      'manual',
      'manual_only',
      v_provider_code,
      v_metadata
    )
    returning id into v_id;
  else
    update payment_methods
    set name = trim(p_name),
        account_holder_name = trim(p_account_holder_name),
        receiving_identifier = trim(p_receiving_identifier),
        customer_instructions = trim(p_instructions),
        proof_requirement = p_proof_requirement,
        mode = 'manual',
        provider_verification = 'manual_only',
        provider_code = v_provider_code,
        provider_metadata = v_metadata,
        updated_at = now()
    where id = p_id and merchant_id = v_merchant_id
    returning id into v_id;

    if v_id is null then
      raise exception using errcode = '42501', message = 'PAYMENT_METHOD_NOT_FOUND';
    end if;
  end if;

  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(
    v_user,
    'merchant.payment_method_saved',
    'payment_method',
    v_id::text,
    jsonb_build_object('provider_code', v_provider_code, 'mode', 'manual')
  );

  return jsonb_build_object(
    'payment_method_id', v_id,
    'provider_code', v_provider_code,
    'integration_mode', 'manual',
    'verification_state', 'manual_only'
  );
end;
$$;

revoke all on function private.save_merchant_payment_method(uuid, text, text, text, text, text) from public, anon;
revoke all on function private.save_merchant_payment_method(uuid, text, text, text, text, text, text, jsonb) from public, anon;
grant execute on function private.save_merchant_payment_method(uuid, text, text, text, text, text, text, jsonb) to authenticated, service_role;

create or replace function public.save_merchant_payment_method(
  p_id uuid,
  p_name text,
  p_account_holder_name text,
  p_receiving_identifier text,
  p_instructions text,
  p_proof_requirement text,
  p_provider_code text default 'manual',
  p_provider_metadata jsonb default '{}'::jsonb
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.save_merchant_payment_method(
    p_id,
    p_name,
    p_account_holder_name,
    p_receiving_identifier,
    p_instructions,
    p_proof_requirement,
    p_provider_code,
    p_provider_metadata
  );
$$;

revoke all on function public.save_merchant_payment_method(uuid, text, text, text, text, text) from public, anon;
revoke all on function public.save_merchant_payment_method(uuid, text, text, text, text, text, text, jsonb) from public, anon;
grant execute on function public.save_merchant_payment_method(uuid, text, text, text, text, text, text, jsonb) to authenticated;

create or replace function private.checkout_create_orders(
  p_market_id uuid,
  p_fulfilment_by_shop jsonb,
  p_payment_by_merchant jsonb
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
  v_order_ids jsonb := '[]'::jsonb;
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
  if not found then raise exception using errcode = 'P0001', message = 'CART_EMPTY'; end if;
  if not exists(select 1 from cart_items where cart_id = v_cart.id) then
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
    select x->>'method' into v_fulfilment
    from jsonb_array_elements(coalesce(p_fulfilment_by_shop, '[]'::jsonb)) x
    where (x->>'shop_id')::uuid = v_group.shop_id
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
    where (x->>'merchant_id')::uuid = v_group.merchant_id
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
      fulfilment_instructions
    )
    select v_session.id,
           v_group.merchant_id,
           v_group.shop_id,
           v_user,
           p_market_id,
           'YC-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10)),
           v_method.currency,
           v_group.subtotal_minor,
           0,
           0,
           v_group.subtotal_minor,
           v_method.name,
           v_method.id,
           v_method.provider_code,
           v_method.provider_metadata,
           v_method.account_holder_name,
           v_method.receiving_identifier,
           v_method.customer_instructions,
           v_method.proof_requirement,
           v_fulfilment,
           sf.instructions
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
        merchant_order_id,
        product_id,
        product_name,
        unit_price_minor,
        quantity,
        line_total_minor
      )
      values(
        v_order.id,
        v_item.id,
        v_item.name,
        v_item.price_minor,
        v_item.quantity,
        v_item.price_minor * v_item.quantity
      );
      update products
      set stock_quantity = stock_quantity - v_item.quantity,
          status = case
            when stock_quantity - v_item.quantity = 0 then 'out_of_stock'
            else status
          end
      where id = v_item.id;
    end loop;

    insert into order_status_history(
      merchant_order_id,
      actor_user_id,
      event_type,
      previous_value,
      next_value
    ) values (v_order.id, v_user, 'order_created', null, 'awaiting_payment');

    insert into audit_events(
      actor_user_id,
      action,
      resource_type,
      resource_id,
      metadata
    ) values (
      v_user,
      'checkout.merchant_order_created',
      'merchant_order',
      v_order.id::text,
      jsonb_build_object(
        'order_reference', v_order.order_reference,
        'merchant_id', v_order.merchant_id,
        'payment_provider_code', v_order.payment_provider_code
      )
    );

    v_order_ids := v_order_ids || jsonb_build_object(
      'id', v_order.id,
      'order_reference', v_order.order_reference,
      'merchant_id', v_order.merchant_id,
      'total_minor', v_order.total_minor,
      'payment_provider_code', v_order.payment_provider_code
    );
  end loop;

  delete from cart_items where cart_id = v_cart.id;
  update checkout_sessions set status = 'completed' where id = v_session.id;
  return jsonb_build_object(
    'checkout_session_id', v_session.id,
    'orders', v_order_ids
  );
end;
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
  select private.checkout_create_orders(
    p_market_id,
    p_fulfilment_by_shop,
    p_payment_by_merchant
  );
$$;

revoke all on function public.checkout_create_orders(uuid, jsonb, jsonb) from public, anon;
grant execute on function public.checkout_create_orders(uuid, jsonb, jsonb) to authenticated;
