-- Make allowlisted promotion replay idempotent across foreground and OS isolates.
-- Checkout already has command-key idempotency; this adds the same protection
-- to order-promotion commands without touching payment state or fund movement.

create table if not exists public.order_command_keys (
  id uuid primary key default gen_random_uuid(),
  customer_user_id uuid not null references public.profiles(id) on delete cascade,
  merchant_order_id uuid not null references public.merchant_orders(id) on delete cascade,
  command_kind text not null check (command_kind in ('promotion_apply')),
  command_key text not null check (length(command_key) between 16 and 120),
  result jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (customer_user_id, command_kind, command_key),
  check (result is null or jsonb_typeof(result) = 'object')
);
create index if not exists order_command_keys_order_idx
  on public.order_command_keys(merchant_order_id, created_at desc);
alter table public.order_command_keys enable row level security;
revoke all on public.order_command_keys from anon, authenticated;

create or replace function private.apply_order_promotion(
  p_merchant_order_id uuid,
  p_code text,
  p_command_key text
)
returns jsonb
language plpgsql security definer set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_key order_command_keys%rowtype;
  v_order merchant_orders%rowtype;
  v_promotion merchant_promotions%rowtype;
  v_discount bigint;
  v_total bigint;
begin
  if v_user is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;
  if length(trim(coalesce(p_command_key, ''))) < 16 or length(trim(p_command_key)) > 120 then
    raise exception using errcode = 'P0001', message = 'INVALID_COMMAND_KEY';
  end if;

  insert into order_command_keys(customer_user_id, merchant_order_id, command_kind, command_key)
  values(v_user, p_merchant_order_id, 'promotion_apply', trim(p_command_key))
  on conflict (customer_user_id, command_kind, command_key) do nothing;
  select * into v_key
  from order_command_keys
  where customer_user_id = v_user
    and merchant_order_id = p_merchant_order_id
    and command_kind = 'promotion_apply'
    and command_key = trim(p_command_key)
  for update;
  if not found then
    raise exception using errcode = '42501', message = 'COMMAND_KEY_SCOPE_MISMATCH';
  end if;
  if v_key.result is not null then
    return v_key.result;
  end if;

  select * into v_order
  from merchant_orders
  where id = p_merchant_order_id and customer_user_id = v_user
  for update;
  if not found then
    raise exception using errcode = '42501', message = 'ORDER_NOT_FOUND';
  end if;
  if v_order.payment_status <> 'awaiting_payment' or v_order.discount_minor > 0 then
    raise exception using errcode = 'P0001', message = 'PROMOTION_NOT_ALLOWED';
  end if;

  select * into v_promotion
  from merchant_promotions
  where merchant_id = v_order.merchant_id
    and shop_id = v_order.shop_id
    and upper(code) = upper(trim(p_code))
    and status = 'active'
    and (starts_at is null or starts_at <= now())
    and (ends_at is null or ends_at > now())
    and (max_redemptions is null or redemption_count < max_redemptions)
  for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'PROMOTION_UNAVAILABLE';
  end if;

  v_discount := case when v_promotion.kind = 'percent'
    then floor(v_order.subtotal_minor * v_promotion.value_minor / 100)
    else v_promotion.value_minor end;
  v_discount := greatest(0, least(v_discount, v_order.subtotal_minor));
  v_total := v_order.subtotal_minor + v_order.fee_minor + v_order.tax_minor - v_discount;

  update merchant_orders
  set promotion_id = v_promotion.id,
      promotion_code = v_promotion.code,
      discount_minor = v_discount,
      total_minor = v_total,
      cod_expected_minor = case when payment_provider_code = 'cash' then v_total else cod_expected_minor end
  where id = v_order.id;
  update merchant_promotions
  set redemption_count = redemption_count + 1, updated_at = now()
  where id = v_promotion.id;
  insert into order_status_history(merchant_order_id, actor_user_id, event_type, previous_value, next_value, reason)
  values(v_order.id, v_user, 'promotion_applied', v_order.total_minor::text, v_total::text, v_promotion.code);
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'promotion.order_applied', 'merchant_order', v_order.id::text,
         jsonb_build_object('promotion_id', v_promotion.id, 'code', v_promotion.code, 'discount_minor', v_discount));

  v_key.result := jsonb_build_object('order_id', v_order.id, 'promotion_id', v_promotion.id, 'discount_minor', v_discount, 'total_minor', v_total);
  update order_command_keys
  set result = v_key.result, completed_at = now()
  where id = v_key.id;
  return v_key.result;
end;
$$;
revoke all on function private.apply_order_promotion(uuid, text, text) from public, anon, authenticated;
grant execute on function private.apply_order_promotion(uuid, text, text) to authenticated, service_role;

-- Preserve the existing online two-argument API. It intentionally does not
-- claim idempotency because legacy callers do not provide a command key.
create or replace function private.apply_order_promotion(
  p_merchant_order_id uuid,
  p_code text
)
returns jsonb
language sql security definer set search_path = public, private, pg_catalog
as $$
  select private.apply_order_promotion(p_merchant_order_id, p_code, md5(random()::text || clock_timestamp()::text));
$$;
revoke all on function private.apply_order_promotion(uuid, text) from public, anon;
grant execute on function private.apply_order_promotion(uuid, text) to authenticated, service_role;

create or replace function public.apply_order_promotion(
  p_merchant_order_id uuid,
  p_code text,
  p_command_key text
)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$
  select private.apply_order_promotion(p_merchant_order_id, p_code, p_command_key);
$$;
revoke all on function public.apply_order_promotion(uuid, text, text) from public, anon;
grant execute on function public.apply_order_promotion(uuid, text, text) to authenticated;

create or replace function public.apply_order_promotion(
  p_merchant_order_id uuid,
  p_code text
)
returns jsonb language sql security invoker set search_path = public, pg_catalog
as $$
  select private.apply_order_promotion(p_merchant_order_id, p_code);
$$;
revoke all on function public.apply_order_promotion(uuid, text) from public, anon;
grant execute on function public.apply_order_promotion(uuid, text) to authenticated;
