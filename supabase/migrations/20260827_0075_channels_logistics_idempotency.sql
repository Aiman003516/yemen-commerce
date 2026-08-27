-- Add replay-safe command keys to the 0072 channel, delivery, exception, and
-- return mutations without changing their existing legacy signatures.
-- The wrapped 0072 functions remain the authoritative state-machine logic.

create table if not exists public.commerce_command_keys (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid not null references public.profiles(id) on delete cascade,
  command_kind text not null check (command_kind in (
    'channel_upsert',
    'channel_listing_upsert',
    'shipment_plan_create',
    'shipment_event_record',
    'delivery_exception_open',
    'delivery_exception_resolve',
    'return_logistics_start',
    'return_event_record'
  )),
  command_key text not null check (length(command_key) between 16 and 120),
  request_hash text not null check (length(request_hash) = 32),
  result jsonb check (result is null or jsonb_typeof(result) = 'object'),
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (actor_user_id, command_kind, command_key)
);
create index if not exists commerce_command_keys_actor_created_idx
  on public.commerce_command_keys(actor_user_id, created_at desc);
create index if not exists commerce_command_keys_kind_created_idx
  on public.commerce_command_keys(command_kind, created_at desc);
alter table public.commerce_command_keys enable row level security;
revoke all on public.commerce_command_keys from anon, authenticated;
drop policy if exists commerce_command_keys_client_deny on public.commerce_command_keys;
create policy commerce_command_keys_client_deny
on public.commerce_command_keys
for all to public
using (false)
with check (false);

create or replace function private.commerce_command_lock(
  p_command_kind text,
  p_command_key text,
  p_request jsonb
)
returns public.commerce_command_keys
language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_command public.commerce_command_keys%rowtype;
  v_hash text := md5(coalesce(p_request, '{}'::jsonb)::text);
begin
  if v_user is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;
  if p_command_kind not in (
    'channel_upsert', 'channel_listing_upsert', 'shipment_plan_create',
    'shipment_event_record', 'delivery_exception_open',
    'delivery_exception_resolve', 'return_logistics_start', 'return_event_record'
  ) then
    raise exception using errcode = 'P0001', message = 'INVALID_COMMAND_KIND';
  end if;
  if length(trim(coalesce(p_command_key, ''))) < 16
     or length(trim(p_command_key)) > 120 then
    raise exception using errcode = 'P0001', message = 'INVALID_COMMAND_KEY';
  end if;

  insert into public.commerce_command_keys(
    actor_user_id, command_kind, command_key, request_hash
  )
  values(v_user, p_command_kind, trim(p_command_key), v_hash)
  on conflict (actor_user_id, command_kind, command_key) do nothing;

  select * into v_command
  from public.commerce_command_keys
  where actor_user_id = v_user
    and command_kind = p_command_kind
    and command_key = trim(p_command_key)
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'COMMAND_KEY_NOT_FOUND';
  end if;
  if v_command.request_hash <> v_hash then
    raise exception using errcode = 'P0001', message = 'COMMAND_KEY_REUSE';
  end if;
  return v_command;
end;
$$;
revoke all on function private.commerce_command_lock(text, text, jsonb) from public, anon, authenticated;
grant execute on function private.commerce_command_lock(text, text, jsonb) to authenticated, service_role;

-- Make the machine-readable command contracts advertise the replay key.
update public.erp_module_contracts
set input_schema = jsonb_set(input_schema, '{idempotency_key}', '"string"'::jsonb, true)
where module_key in ('commerce_channels', 'delivery_orchestration', 'returns_logistics')
  and contract_kind = 'command';

create or replace function private.merchant_upsert_channel(
  p_shop_id uuid,
  p_channel_key text,
  p_display_name text,
  p_channel_kind text,
  p_status text,
  p_reason text,
  p_idempotency_key text
)
returns jsonb language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_command public.commerce_command_keys%rowtype;
  v_request jsonb := jsonb_build_object(
    'shop_id', p_shop_id, 'channel_key', lower(trim(coalesce(p_channel_key, ''))),
    'display_name', trim(coalesce(p_display_name, '')), 'channel_kind', p_channel_kind,
    'status', p_status, 'reason', trim(coalesce(p_reason, ''))
  );
  v_result jsonb;
begin
  v_command := private.commerce_command_lock('channel_upsert', p_idempotency_key, v_request);
  if v_command.result is not null then
    return v_command.result || jsonb_build_object('idempotent', true);
  end if;
  v_result := private.merchant_upsert_channel(
    p_shop_id, p_channel_key, p_display_name, p_channel_kind, p_status, p_reason
  );
  update public.commerce_command_keys
  set result = v_result, completed_at = now()
  where id = v_command.id;
  return v_result || jsonb_build_object('idempotent', false);
end;
$$;
revoke all on function private.merchant_upsert_channel(uuid, text, text, text, text, text, text) from public, anon, authenticated;
grant execute on function private.merchant_upsert_channel(uuid, text, text, text, text, text, text) to authenticated, service_role;

create or replace function public.merchant_upsert_channel(
  p_shop_id uuid, p_channel_key text, p_display_name text, p_channel_kind text,
  p_status text, p_reason text, p_idempotency_key text
)
returns jsonb language sql security invoker
set search_path = public, pg_catalog
as $$
  select private.merchant_upsert_channel($1, $2, $3, $4, $5, $6, $7);
$$;
revoke all on function public.merchant_upsert_channel(uuid, text, text, text, text, text, text) from public, anon;
grant execute on function public.merchant_upsert_channel(uuid, text, text, text, text, text, text) to authenticated;

create or replace function private.merchant_upsert_channel_listing(
  p_channel_id uuid,
  p_product_id uuid,
  p_listing_status text,
  p_channel_title text,
  p_channel_description text,
  p_price_override_minor bigint,
  p_currency_override text,
  p_reason text,
  p_idempotency_key text
)
returns jsonb language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_command public.commerce_command_keys%rowtype;
  v_request jsonb := jsonb_build_object(
    'channel_id', p_channel_id, 'product_id', p_product_id,
    'listing_status', p_listing_status, 'channel_title', nullif(trim(coalesce(p_channel_title, '')), ''),
    'channel_description', nullif(trim(coalesce(p_channel_description, '')), ''),
    'price_override_minor', p_price_override_minor, 'currency_override', upper(nullif(trim(coalesce(p_currency_override, '')), '')),
    'reason', trim(coalesce(p_reason, ''))
  );
  v_result jsonb;
begin
  v_command := private.commerce_command_lock('channel_listing_upsert', p_idempotency_key, v_request);
  if v_command.result is not null then
    return v_command.result || jsonb_build_object('idempotent', true);
  end if;
  v_result := private.merchant_upsert_channel_listing(
    p_channel_id, p_product_id, p_listing_status, p_channel_title,
    p_channel_description, p_price_override_minor, p_currency_override, p_reason
  );
  update public.commerce_command_keys
  set result = v_result, completed_at = now()
  where id = v_command.id;
  return v_result || jsonb_build_object('idempotent', false);
end;
$$;
revoke all on function private.merchant_upsert_channel_listing(uuid, uuid, text, text, text, bigint, text, text, text) from public, anon, authenticated;
grant execute on function private.merchant_upsert_channel_listing(uuid, uuid, text, text, text, bigint, text, text, text) to authenticated, service_role;

create or replace function public.merchant_upsert_channel_listing(
  p_channel_id uuid, p_product_id uuid, p_listing_status text,
  p_channel_title text, p_channel_description text, p_price_override_minor bigint,
  p_currency_override text, p_reason text, p_idempotency_key text
)
returns jsonb language sql security invoker
set search_path = public, pg_catalog
as $$
  select private.merchant_upsert_channel_listing($1, $2, $3, $4, $5, $6, $7, $8, $9);
$$;
revoke all on function public.merchant_upsert_channel_listing(uuid, uuid, text, text, text, bigint, text, text, text) from public, anon;
grant execute on function public.merchant_upsert_channel_listing(uuid, uuid, text, text, text, bigint, text, text, text) to authenticated;

create or replace function private.merchant_create_shipment_plan(
  p_merchant_order_id uuid, p_carrier_key text, p_service_level text,
  p_reason text, p_idempotency_key text
)
returns jsonb language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_command public.commerce_command_keys%rowtype;
  v_request jsonb := jsonb_build_object(
    'merchant_order_id', p_merchant_order_id, 'carrier_key', lower(trim(coalesce(p_carrier_key, ''))),
    'service_level', nullif(trim(coalesce(p_service_level, '')), ''), 'reason', trim(coalesce(p_reason, ''))
  );
  v_result jsonb;
begin
  v_command := private.commerce_command_lock('shipment_plan_create', p_idempotency_key, v_request);
  if v_command.result is not null then
    return v_command.result || jsonb_build_object('idempotent', true);
  end if;
  v_result := private.merchant_create_shipment_plan(p_merchant_order_id, p_carrier_key, p_service_level, p_reason);
  update public.commerce_command_keys set result = v_result, completed_at = now() where id = v_command.id;
  return v_result || jsonb_build_object('idempotent', false);
end;
$$;
revoke all on function private.merchant_create_shipment_plan(uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function private.merchant_create_shipment_plan(uuid, text, text, text, text) to authenticated, service_role;

create or replace function public.merchant_create_shipment_plan(
  p_merchant_order_id uuid, p_carrier_key text, p_service_level text,
  p_reason text, p_idempotency_key text
)
returns jsonb language sql security invoker
set search_path = public, pg_catalog
as $$
  select private.merchant_create_shipment_plan($1, $2, $3, $4, $5);
$$;
revoke all on function public.merchant_create_shipment_plan(uuid, text, text, text, text) from public, anon;
grant execute on function public.merchant_create_shipment_plan(uuid, text, text, text, text) to authenticated;

create or replace function private.merchant_record_shipment_event(
  p_shipment_plan_id uuid, p_status text, p_customer_message text,
  p_reason text, p_idempotency_key text
)
returns jsonb language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_command public.commerce_command_keys%rowtype;
  v_request jsonb := jsonb_build_object(
    'shipment_plan_id', p_shipment_plan_id, 'status', p_status,
    'customer_message', nullif(trim(coalesce(p_customer_message, '')), ''),
    'reason', trim(coalesce(p_reason, ''))
  );
  v_result jsonb;
begin
  v_command := private.commerce_command_lock('shipment_event_record', p_idempotency_key, v_request);
  if v_command.result is not null then
    return v_command.result || jsonb_build_object('idempotent', true);
  end if;
  v_result := private.merchant_record_shipment_event(p_shipment_plan_id, p_status, p_customer_message, p_reason);
  update public.commerce_command_keys set result = v_result, completed_at = now() where id = v_command.id;
  return v_result || jsonb_build_object('idempotent', false);
end;
$$;
revoke all on function private.merchant_record_shipment_event(uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function private.merchant_record_shipment_event(uuid, text, text, text, text) to authenticated, service_role;

create or replace function public.merchant_record_shipment_event(
  p_shipment_plan_id uuid, p_status text, p_customer_message text,
  p_reason text, p_idempotency_key text
)
returns jsonb language sql security invoker
set search_path = public, pg_catalog
as $$
  select private.merchant_record_shipment_event($1, $2, $3, $4, $5);
$$;
revoke all on function public.merchant_record_shipment_event(uuid, text, text, text, text) from public, anon;
grant execute on function public.merchant_record_shipment_event(uuid, text, text, text, text) to authenticated;

create or replace function private.merchant_open_delivery_exception(
  p_shipment_plan_id uuid, p_code text, p_severity text,
  p_customer_message text, p_reason text, p_idempotency_key text
)
returns jsonb language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_command public.commerce_command_keys%rowtype;
  v_request jsonb := jsonb_build_object(
    'shipment_plan_id', p_shipment_plan_id, 'code', lower(trim(coalesce(p_code, ''))),
    'severity', p_severity, 'customer_message', trim(coalesce(p_customer_message, '')),
    'reason', trim(coalesce(p_reason, ''))
  );
  v_result jsonb;
begin
  v_command := private.commerce_command_lock('delivery_exception_open', p_idempotency_key, v_request);
  if v_command.result is not null then
    return v_command.result || jsonb_build_object('idempotent', true);
  end if;
  v_result := private.merchant_open_delivery_exception(
    p_shipment_plan_id, p_code, p_severity, p_customer_message, p_reason
  );
  update public.commerce_command_keys set result = v_result, completed_at = now() where id = v_command.id;
  return v_result || jsonb_build_object('idempotent', false);
end;
$$;
revoke all on function private.merchant_open_delivery_exception(uuid, text, text, text, text, text) from public, anon, authenticated;
grant execute on function private.merchant_open_delivery_exception(uuid, text, text, text, text, text) to authenticated, service_role;

create or replace function public.merchant_open_delivery_exception(
  p_shipment_plan_id uuid, p_code text, p_severity text,
  p_customer_message text, p_reason text, p_idempotency_key text
)
returns jsonb language sql security invoker
set search_path = public, pg_catalog
as $$
  select private.merchant_open_delivery_exception($1, $2, $3, $4, $5, $6);
$$;
revoke all on function public.merchant_open_delivery_exception(uuid, text, text, text, text, text) from public, anon;
grant execute on function public.merchant_open_delivery_exception(uuid, text, text, text, text, text) to authenticated;

create or replace function private.merchant_resolve_delivery_exception(
  p_exception_id uuid, p_status text, p_reason text, p_idempotency_key text
)
returns jsonb language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_command public.commerce_command_keys%rowtype;
  v_request jsonb := jsonb_build_object(
    'exception_id', p_exception_id, 'status', p_status, 'reason', trim(coalesce(p_reason, ''))
  );
  v_result jsonb;
begin
  v_command := private.commerce_command_lock('delivery_exception_resolve', p_idempotency_key, v_request);
  if v_command.result is not null then
    return v_command.result || jsonb_build_object('idempotent', true);
  end if;
  v_result := private.merchant_resolve_delivery_exception(p_exception_id, p_status, p_reason);
  update public.commerce_command_keys set result = v_result, completed_at = now() where id = v_command.id;
  return v_result || jsonb_build_object('idempotent', false);
end;
$$;
revoke all on function private.merchant_resolve_delivery_exception(uuid, text, text, text) from public, anon, authenticated;
grant execute on function private.merchant_resolve_delivery_exception(uuid, text, text, text) to authenticated, service_role;

create or replace function public.merchant_resolve_delivery_exception(
  p_exception_id uuid, p_status text, p_reason text, p_idempotency_key text
)
returns jsonb language sql security invoker
set search_path = public, pg_catalog
as $$
  select private.merchant_resolve_delivery_exception($1, $2, $3, $4);
$$;
revoke all on function public.merchant_resolve_delivery_exception(uuid, text, text, text) from public, anon;
grant execute on function public.merchant_resolve_delivery_exception(uuid, text, text, text) to authenticated;

create or replace function private.merchant_start_return_logistics(
  p_order_case_id uuid, p_method text, p_customer_message text,
  p_reason text, p_idempotency_key text
)
returns jsonb language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_command public.commerce_command_keys%rowtype;
  v_request jsonb := jsonb_build_object(
    'order_case_id', p_order_case_id, 'method', p_method,
    'customer_message', nullif(trim(coalesce(p_customer_message, '')), ''),
    'reason', trim(coalesce(p_reason, ''))
  );
  v_result jsonb;
begin
  v_command := private.commerce_command_lock('return_logistics_start', p_idempotency_key, v_request);
  if v_command.result is not null then
    return v_command.result || jsonb_build_object('idempotent', true);
  end if;
  v_result := private.merchant_start_return_logistics(p_order_case_id, p_method, p_customer_message, p_reason);
  update public.commerce_command_keys set result = v_result, completed_at = now() where id = v_command.id;
  return v_result || jsonb_build_object('idempotent', false);
end;
$$;
revoke all on function private.merchant_start_return_logistics(uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function private.merchant_start_return_logistics(uuid, text, text, text, text) to authenticated, service_role;

create or replace function public.merchant_start_return_logistics(
  p_order_case_id uuid, p_method text, p_customer_message text,
  p_reason text, p_idempotency_key text
)
returns jsonb language sql security invoker
set search_path = public, pg_catalog
as $$
  select private.merchant_start_return_logistics($1, $2, $3, $4, $5);
$$;
revoke all on function public.merchant_start_return_logistics(uuid, text, text, text, text) from public, anon;
grant execute on function public.merchant_start_return_logistics(uuid, text, text, text, text) to authenticated;

create or replace function private.merchant_record_return_event(
  p_return_logistics_id uuid, p_status text, p_customer_message text,
  p_reason text, p_idempotency_key text
)
returns jsonb language plpgsql security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_command public.commerce_command_keys%rowtype;
  v_request jsonb := jsonb_build_object(
    'return_logistics_id', p_return_logistics_id, 'status', p_status,
    'customer_message', nullif(trim(coalesce(p_customer_message, '')), ''),
    'reason', trim(coalesce(p_reason, ''))
  );
  v_result jsonb;
begin
  v_command := private.commerce_command_lock('return_event_record', p_idempotency_key, v_request);
  if v_command.result is not null then
    return v_command.result || jsonb_build_object('idempotent', true);
  end if;
  v_result := private.merchant_record_return_event(p_return_logistics_id, p_status, p_customer_message, p_reason);
  update public.commerce_command_keys set result = v_result, completed_at = now() where id = v_command.id;
  return v_result || jsonb_build_object('idempotent', false);
end;
$$;
revoke all on function private.merchant_record_return_event(uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function private.merchant_record_return_event(uuid, text, text, text, text) to authenticated, service_role;

create or replace function public.merchant_record_return_event(
  p_return_logistics_id uuid, p_status text, p_customer_message text,
  p_reason text, p_idempotency_key text
)
returns jsonb language sql security invoker
set search_path = public, pg_catalog
as $$
  select private.merchant_record_return_event($1, $2, $3, $4, $5);
$$;
revoke all on function public.merchant_record_return_event(uuid, text, text, text, text) from public, anon;
grant execute on function public.merchant_record_return_event(uuid, text, text, text, text) to authenticated;

comment on table public.commerce_command_keys is
  'Actor-scoped idempotency ledger for channel, shipment, delivery-exception, and return commands; raw command payloads are never retained.';
