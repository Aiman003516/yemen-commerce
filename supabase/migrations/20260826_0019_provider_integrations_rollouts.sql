-- Provider-ready integrations and staged market rollouts.
-- This migration stores configuration metadata and secret references only;
-- provider secrets and external calls belong in server-side adapters.

create table if not exists public.provider_catalog (
  provider_code text primary key,
  category text not null check (category in ('messaging','logistics','maps','sales_channel','analytics','financing','payments','other')),
  display_name_ar text not null,
  display_name_en text,
  integration_mode text not null check (integration_mode in ('mock','manual','adapter')),
  readiness_state text not null default 'mock' check (readiness_state in ('mock','manual','pending_approval','configured','blocked')),
  supports_webhooks boolean not null default false,
  active boolean not null default true,
  notes_ar text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.merchant_integrations (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  provider_code text not null references public.provider_catalog(provider_code) on delete restrict,
  status text not null default 'mock' check (status in ('mock','manual','pending_approval','configured','paused','blocked')),
  configuration jsonb not null default '{}'::jsonb,
  credential_reference text,
  webhook_endpoint_reference text,
  last_health_status text not null default 'not_checked' check (last_health_status in ('not_checked','healthy','degraded','failed')),
  last_health_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (shop_id, provider_code),
  check (jsonb_typeof(configuration) = 'object' and length(configuration::text) <= 8000),
  check (credential_reference is null or length(credential_reference) <= 200),
  check (webhook_endpoint_reference is null or length(webhook_endpoint_reference) <= 400)
);
create index if not exists merchant_integrations_shop_status_idx
  on public.merchant_integrations(shop_id, status);

create table if not exists public.integration_events (
  id uuid primary key default gen_random_uuid(),
  merchant_integration_id uuid not null references public.merchant_integrations(id) on delete cascade,
  direction text not null check (direction in ('inbound','outbound')),
  event_type text not null,
  external_event_id text,
  payload jsonb not null default '{}'::jsonb,
  processing_status text not null default 'received' check (processing_status in ('received','processed','failed','ignored')),
  error_code text,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  unique (merchant_integration_id, direction, external_event_id),
  check (jsonb_typeof(payload) = 'object' and length(payload::text) <= 16000)
);
create index if not exists integration_events_status_received_idx
  on public.integration_events(processing_status, received_at desc);
create index if not exists integration_events_integration_received_idx
  on public.integration_events(merchant_integration_id, received_at desc);

create table if not exists public.market_feature_rollouts (
  id uuid primary key default gen_random_uuid(),
  market_id uuid not null references public.markets(id) on delete cascade,
  feature_key text not null,
  enabled boolean not null default false,
  configuration jsonb not null default '{}'::jsonb,
  reason text not null,
  updated_by_user_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (market_id, feature_key),
  check (length(trim(feature_key)) between 2 and 100),
  check (jsonb_typeof(configuration) = 'object' and length(configuration::text) <= 4000)
);
create index if not exists market_feature_rollouts_market_enabled_idx
  on public.market_feature_rollouts(market_id, enabled);

alter table public.provider_catalog enable row level security;
alter table public.merchant_integrations enable row level security;
alter table public.integration_events enable row level security;
alter table public.market_feature_rollouts enable row level security;
grant select on public.provider_catalog to anon, authenticated;
grant select on public.merchant_integrations, public.integration_events, public.market_feature_rollouts to authenticated;

drop policy if exists provider_catalog_public_read on public.provider_catalog;
create policy provider_catalog_public_read on public.provider_catalog
for select to anon, authenticated using (active);

drop policy if exists merchant_integrations_owner_read on public.merchant_integrations;
create policy merchant_integrations_owner_read on public.merchant_integrations
for select to authenticated
using (
  exists (
    select 1 from public.shops s
    join public.merchants m on m.id = s.merchant_id
    where s.id = shop_id and (m.owner_user_id = (select auth.uid()) or private.is_admin() or private.current_user_is_creator())
  )
);

drop policy if exists integration_events_owner_read on public.integration_events;
create policy integration_events_owner_read on public.integration_events
for select to authenticated
using (
  exists (
    select 1 from public.merchant_integrations i
    join public.shops s on s.id = i.shop_id
    join public.merchants m on m.id = s.merchant_id
    where i.id = merchant_integration_id
      and (m.owner_user_id = (select auth.uid()) or private.is_admin() or private.current_user_is_creator() or private.has_role('support_agent', null))
  )
);

drop policy if exists market_feature_rollouts_public_read on public.market_feature_rollouts;
create policy market_feature_rollouts_public_read on public.market_feature_rollouts
for select to anon, authenticated
using (enabled and exists(select 1 from public.markets m where m.id = market_id and m.status = 'active'));

drop policy if exists market_feature_rollouts_internal_read on public.market_feature_rollouts;
create policy market_feature_rollouts_internal_read on public.market_feature_rollouts
for select to authenticated
using (private.is_admin() or private.current_user_is_creator() or private.current_user_has_capability('manage_capabilities', market_id));

insert into public.provider_catalog(provider_code, category, display_name_ar, display_name_en, integration_mode, readiness_state, supports_webhooks, notes_ar)
values
  ('whatsapp_business', 'messaging', 'واتساب للأعمال', 'WhatsApp Business', 'adapter', 'pending_approval', true, 'يتطلب حساب أعمال، موافقة القوالب، موافقة العميل، وتوقيع Webhook.'),
  ('yemen_sms', 'messaging', 'رسائل SMS اليمن', 'Yemen SMS', 'adapter', 'mock', true, 'مزود قابل للاستبدال؛ لا توجد رسائل فعلية في وضع المعاينة.'),
  ('local_courier', 'logistics', 'شبكة توصيل محلية', 'Local Courier', 'manual', 'manual', false, 'تشغيل يدوي حتى تتوفر اتفاقية وإجراء تتبع موثق.'),
  ('maps_geocoding', 'maps', 'خرائط وترميز جغرافي', 'Maps and Geocoding', 'adapter', 'pending_approval', false, 'الحي ونقطة الاستلام بديل أساسي عند غياب الموقع الدقيق.'),
  ('social_catalog', 'sales_channel', 'قنوات البيع الاجتماعية', 'Social Sales Channels', 'adapter', 'mock', true, 'المعاينة لا تنشر أو تزامن كتالوجاً خارجياً.'),
  ('merchant_finance', 'financing', 'تمويل التجار', 'Merchant Finance', 'adapter', 'blocked', false, 'يتطلب شريكاً مالياً مرخصاً ومراجعة قانونية منفصلة.'),
  ('analytics_basic', 'analytics', 'تحليلات أساسية', 'Basic Analytics', 'mock', 'mock', false, 'بيانات تشغيلية مجمعة داخل المنصة.'),
  ('jaib_manual', 'payments', 'جيب يدوي', 'Jaib Manual', 'manual', 'manual', false, 'QR/POS ومرجع عملية مع مراجعة التاجر؛ لا تحقق تلقائي.'),
  ('kuraimi_manual', 'payments', 'الكريمي يدوي', 'Kuraimi Manual', 'manual', 'manual', false, 'مرجع عملية مع مراجعة التاجر؛ لا تسوية آلية.'),
  ('cash_on_delivery', 'payments', 'الدفع عند الاستلام', 'Cash on Delivery', 'manual', 'manual', false, 'تحصيل ومطابقة منفصلان عن إثبات الدفع الإلكتروني.')
on conflict (provider_code) do update set
  category = excluded.category,
  display_name_ar = excluded.display_name_ar,
  display_name_en = excluded.display_name_en,
  integration_mode = excluded.integration_mode,
  readiness_state = excluded.readiness_state,
  supports_webhooks = excluded.supports_webhooks,
  notes_ar = excluded.notes_ar,
  updated_at = now();

create or replace function private.save_merchant_integration(
  p_shop_id uuid,
  p_provider_code text,
  p_status text default 'mock',
  p_configuration jsonb default '{}'::jsonb,
  p_credential_reference text default null,
  p_webhook_endpoint_reference text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_id uuid;
  v_status text := lower(trim(coalesce(p_status, 'mock')));
  v_provider provider_catalog%rowtype;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if not exists(
    select 1 from shops s join merchants m on m.id = s.merchant_id
    where s.id = p_shop_id and m.owner_user_id = v_user
  ) then raise exception using errcode = '42501', message = 'SHOP_NOT_OWNED'; end if;
  select * into v_provider from provider_catalog where provider_code = lower(trim(p_provider_code)) and active;
  if not found then raise exception using errcode = 'P0001', message = 'PROVIDER_UNAVAILABLE'; end if;
  if v_status not in ('mock','manual','pending_approval','paused','blocked') then
    raise exception using errcode = 'P0001', message = 'INVALID_INTEGRATION_STATUS';
  end if;
  if jsonb_typeof(coalesce(p_configuration, '{}'::jsonb)) <> 'object' or length(coalesce(p_configuration, '{}'::jsonb)::text) > 8000 then
    raise exception using errcode = 'P0001', message = 'INVALID_INTEGRATION_CONFIGURATION';
  end if;
  insert into merchant_integrations(shop_id, provider_code, status, configuration, credential_reference, webhook_endpoint_reference)
  values(p_shop_id, v_provider.provider_code, v_status, coalesce(p_configuration, '{}'::jsonb), nullif(trim(p_credential_reference), ''), nullif(trim(p_webhook_endpoint_reference), ''))
  on conflict (shop_id, provider_code) do update set
    status = excluded.status,
    configuration = excluded.configuration,
    credential_reference = excluded.credential_reference,
    webhook_endpoint_reference = excluded.webhook_endpoint_reference,
    updated_at = now()
  returning id into v_id;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'merchant.integration_saved', 'merchant_integration', v_id::text,
         jsonb_build_object('shop_id', p_shop_id, 'provider_code', v_provider.provider_code, 'status', v_status));
  return jsonb_build_object('integration_id', v_id, 'status', v_status, 'provider_code', v_provider.provider_code);
end;
$$;
revoke all on function private.save_merchant_integration(uuid, text, text, jsonb, text, text) from public, anon;
grant execute on function private.save_merchant_integration(uuid, text, text, jsonb, text, text) to authenticated, service_role;

create or replace function public.save_merchant_integration(
  p_shop_id uuid,
  p_provider_code text,
  p_status text default 'mock',
  p_configuration jsonb default '{}'::jsonb,
  p_credential_reference text default null,
  p_webhook_endpoint_reference text default null
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.save_merchant_integration(p_shop_id, p_provider_code, p_status, p_configuration, p_credential_reference, p_webhook_endpoint_reference);
$$;
revoke all on function public.save_merchant_integration(uuid, text, text, jsonb, text, text) from public, anon;
grant execute on function public.save_merchant_integration(uuid, text, text, jsonb, text, text) to authenticated;

create or replace function private.creator_set_integration_status(
  p_integration_id uuid,
  p_status text,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_provider text;
  v_shop uuid;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if not private.current_user_has_capability('manage_policies', null) then raise exception using errcode = '42501', message = 'FORBIDDEN'; end if;
  if p_status not in ('mock','manual','pending_approval','configured','paused','blocked') or length(trim(coalesce(p_reason, ''))) < 3 then
    raise exception using errcode = 'P0001', message = 'INVALID_PROVIDER_STATUS';
  end if;
  update merchant_integrations
  set status = p_status, updated_at = now()
  where id = p_integration_id
  returning provider_code, shop_id into v_provider, v_shop;
  if not found then raise exception using errcode = 'P0001', message = 'INTEGRATION_NOT_FOUND'; end if;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'creator.integration_status_changed', 'merchant_integration', p_integration_id::text,
         jsonb_build_object('provider_code', v_provider, 'shop_id', v_shop, 'status', p_status, 'reason', trim(p_reason)));
  return jsonb_build_object('integration_id', p_integration_id, 'status', p_status);
end;
$$;
revoke all on function private.creator_set_integration_status(uuid, text, text) from public, anon, authenticated;
grant execute on function private.creator_set_integration_status(uuid, text, text) to authenticated, service_role;

create or replace function public.creator_set_integration_status(
  p_integration_id uuid,
  p_status text,
  p_reason text
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.creator_set_integration_status(p_integration_id, p_status, p_reason);
$$;
revoke all on function public.creator_set_integration_status(uuid, text, text) from public, anon;
grant execute on function public.creator_set_integration_status(uuid, text, text) to authenticated;

create or replace function private.creator_set_feature_rollout(
  p_market_id uuid,
  p_feature_key text,
  p_enabled boolean,
  p_configuration jsonb default '{}'::jsonb,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
declare
  v_user uuid := (select auth.uid());
  v_id uuid;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if not private.current_user_has_capability('manage_capabilities', p_market_id) then raise exception using errcode = '42501', message = 'FORBIDDEN'; end if;
  if not exists(select 1 from markets where id = p_market_id) then raise exception using errcode = 'P0001', message = 'MARKET_NOT_FOUND'; end if;
  if length(trim(coalesce(p_feature_key, ''))) < 2 or length(trim(coalesce(p_reason, ''))) < 3 or jsonb_typeof(coalesce(p_configuration, '{}'::jsonb)) <> 'object' then
    raise exception using errcode = 'P0001', message = 'INVALID_FEATURE_ROLLOUT';
  end if;
  insert into market_feature_rollouts(market_id, feature_key, enabled, configuration, reason, updated_by_user_id)
  values(p_market_id, trim(p_feature_key), p_enabled, coalesce(p_configuration, '{}'::jsonb), trim(p_reason), v_user)
  on conflict (market_id, feature_key) do update set
    enabled = excluded.enabled,
    configuration = excluded.configuration,
    reason = excluded.reason,
    updated_by_user_id = excluded.updated_by_user_id,
    updated_at = now()
  returning id into v_id;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'creator.feature_rollout_changed', 'market_feature_rollout', v_id::text,
         jsonb_build_object('market_id', p_market_id, 'feature_key', p_feature_key, 'enabled', p_enabled, 'reason', p_reason));
  return jsonb_build_object('rollout_id', v_id, 'enabled', p_enabled);
end;
$$;
revoke all on function private.creator_set_feature_rollout(uuid, text, boolean, jsonb, text) from public, anon, authenticated;
grant execute on function private.creator_set_feature_rollout(uuid, text, boolean, jsonb, text) to authenticated, service_role;

create or replace function public.creator_set_feature_rollout(
  p_market_id uuid,
  p_feature_key text,
  p_enabled boolean,
  p_configuration jsonb default '{}'::jsonb,
  p_reason text default null
)
returns jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$
  select private.creator_set_feature_rollout(p_market_id, p_feature_key, p_enabled, p_configuration, p_reason);
$$;
revoke all on function public.creator_set_feature_rollout(uuid, text, boolean, jsonb, text) from public, anon;
grant execute on function public.creator_set_feature_rollout(uuid, text, boolean, jsonb, text) to authenticated;
