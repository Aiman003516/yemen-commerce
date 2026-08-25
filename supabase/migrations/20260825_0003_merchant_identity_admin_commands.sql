-- Merchant, identity, and administrator command layer.
-- Privileged implementations live in private; public wrappers are SECURITY INVOKER.

create or replace function private.submit_merchant_application(p_phone text, p_owner_name text, p_market_id uuid)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_user uuid := (select auth.uid()); v_merchant merchants%rowtype;
begin
  if v_user is null then raise exception using errcode = '28000', message = 'AUTH_REQUIRED'; end if;
  if nullif(trim(p_phone), '') is null or length(trim(p_owner_name)) < 2 then raise exception using errcode = 'P0001', message = 'INVALID_MERCHANT_APPLICATION'; end if;
  if not exists(select 1 from markets where id = p_market_id and status = 'active') then raise exception using errcode = 'P0001', message = 'MARKET_UNAVAILABLE'; end if;
  select * into v_merchant from merchants where owner_user_id = v_user and market_id = p_market_id order by created_at desc limit 1;
  if found then return jsonb_build_object('merchant_id', v_merchant.id, 'verification_status', v_merchant.verification_status); end if;
  insert into merchants(owner_user_id, market_id, phone, owner_name, verification_status) values(v_user, p_market_id, trim(p_phone), trim(p_owner_name), 'pending') returning * into v_merchant;
  insert into user_roles(user_id, role, market_id) values(v_user, 'merchant', p_market_id) on conflict do nothing;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata) values(v_user, 'merchant.application_submitted', 'merchant', v_merchant.id::text, jsonb_build_object('market_id', p_market_id));
  return jsonb_build_object('merchant_id', v_merchant.id, 'verification_status', v_merchant.verification_status);
end;
$$;
revoke all on function private.submit_merchant_application(text, text, uuid) from public, anon;
grant execute on function private.submit_merchant_application(text, text, uuid) to authenticated, service_role;
create or replace function public.submit_merchant_application(p_phone text, p_owner_name text, p_market_id uuid)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.submit_merchant_application(p_phone, p_owner_name, p_market_id); $$;
revoke all on function public.submit_merchant_application(text, text, uuid) from public, anon;
grant execute on function public.submit_merchant_application(text, text, uuid) to authenticated;

create or replace function private.create_shop(p_name text, p_slug text, p_area_label text, p_market_id uuid)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_user uuid := (select auth.uid()); v_merchant merchants%rowtype; v_shop shops%rowtype;
begin
  select * into v_merchant from merchants where owner_user_id = v_user and market_id = p_market_id order by created_at desc limit 1;
  if not found then raise exception using errcode = '42501', message = 'MERCHANT_CONTEXT_REQUIRED'; end if;
  if length(trim(p_name)) < 2 or length(trim(p_slug)) < 2 then raise exception using errcode = 'P0001', message = 'INVALID_SHOP'; end if;
  insert into shops(merchant_id, market_id, name, slug, area_label, status) values(v_merchant.id, p_market_id, trim(p_name), lower(trim(p_slug)), nullif(trim(p_area_label), ''), 'pending') returning * into v_shop;
  insert into audit_events(actor_user_id, action, resource_type, resource_id) values(v_user, 'merchant.shop_submitted', 'shop', v_shop.id::text);
  return jsonb_build_object('shop_id', v_shop.id, 'status', v_shop.status);
exception when unique_violation then raise exception using errcode = '23505', message = 'SHOP_SLUG_ALREADY_EXISTS';
end;
$$;
revoke all on function private.create_shop(text, text, text, uuid) from public, anon;
grant execute on function private.create_shop(text, text, text, uuid) to authenticated, service_role;
create or replace function public.create_shop(p_name text, p_slug text, p_area_label text, p_market_id uuid)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.create_shop(p_name, p_slug, p_area_label, p_market_id); $$;
revoke all on function public.create_shop(text, text, text, uuid) from public, anon;
grant execute on function public.create_shop(text, text, text, uuid) to authenticated;

create or replace function private.save_merchant_payment_method(p_id uuid, p_name text, p_account_holder_name text, p_receiving_identifier text, p_instructions text, p_proof_requirement text)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_user uuid := (select auth.uid()); v_merchant_id uuid; v_id uuid;
begin
  select id into v_merchant_id from merchants where owner_user_id = v_user order by created_at desc limit 1;
  if v_merchant_id is null then raise exception using errcode = '42501', message = 'MERCHANT_CONTEXT_REQUIRED'; end if;
  if length(trim(p_name)) < 2 or length(trim(p_account_holder_name)) < 2 or length(trim(p_receiving_identifier)) < 3 or length(trim(p_instructions)) < 10 or p_proof_requirement not in ('none','reference','screenshot','both') then raise exception using errcode = 'P0001', message = 'INVALID_PAYMENT_METHOD'; end if;
  if p_id is null then
    insert into payment_methods(merchant_id, name, account_holder_name, receiving_identifier, customer_instructions, proof_requirement, mode, provider_verification) values(v_merchant_id, trim(p_name), trim(p_account_holder_name), trim(p_receiving_identifier), trim(p_instructions), p_proof_requirement, 'manual', 'manual_only') returning id into v_id;
  else
    update payment_methods set name = trim(p_name), account_holder_name = trim(p_account_holder_name), receiving_identifier = trim(p_receiving_identifier), customer_instructions = trim(p_instructions), proof_requirement = p_proof_requirement where id = p_id and merchant_id = v_merchant_id returning id into v_id;
    if v_id is null then raise exception using errcode = '42501', message = 'PAYMENT_METHOD_NOT_FOUND'; end if;
  end if;
  insert into audit_events(actor_user_id, action, resource_type, resource_id) values(v_user, 'merchant.payment_method_saved', 'payment_method', v_id::text);
  return jsonb_build_object('payment_method_id', v_id);
end;
$$;
revoke all on function private.save_merchant_payment_method(uuid, text, text, text, text, text) from public, anon;
grant execute on function private.save_merchant_payment_method(uuid, text, text, text, text, text) to authenticated, service_role;
create or replace function public.save_merchant_payment_method(p_id uuid, p_name text, p_account_holder_name text, p_receiving_identifier text, p_instructions text, p_proof_requirement text)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.save_merchant_payment_method(p_id, p_name, p_account_holder_name, p_receiving_identifier, p_instructions, p_proof_requirement); $$;
revoke all on function public.save_merchant_payment_method(uuid, text, text, text, text, text) from public, anon;
grant execute on function public.save_merchant_payment_method(uuid, text, text, text, text, text) to authenticated;

create or replace function private.set_merchant_fulfilment(p_shop_id uuid, p_method text, p_instructions text, p_is_active boolean)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_user uuid := (select auth.uid()); v_id uuid;
begin
  if not exists(select 1 from shops s join merchants m on m.id = s.merchant_id where s.id = p_shop_id and m.owner_user_id = v_user) then raise exception using errcode = '42501', message = 'SHOP_NOT_OWNED'; end if;
  if p_method not in ('collection','digital','seller_arranged') then raise exception using errcode = 'P0001', message = 'INVALID_FULFILMENT_METHOD'; end if;
  insert into shop_fulfilment_methods(shop_id, method, instructions, is_active) values(p_shop_id, p_method, nullif(trim(p_instructions), ''), p_is_active)
  on conflict (shop_id, method) do update set instructions = excluded.instructions, is_active = excluded.is_active returning id into v_id;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata) values(v_user, 'merchant.fulfilment_saved', 'shop', p_shop_id::text, jsonb_build_object('method', p_method));
  return jsonb_build_object('fulfilment_id', v_id);
end;
$$;
revoke all on function private.set_merchant_fulfilment(uuid, text, text, boolean) from public, anon;
grant execute on function private.set_merchant_fulfilment(uuid, text, text, boolean) to authenticated, service_role;
create or replace function public.set_merchant_fulfilment(p_shop_id uuid, p_method text, p_instructions text, p_is_active boolean)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.set_merchant_fulfilment(p_shop_id, p_method, p_instructions, p_is_active); $$;
revoke all on function public.set_merchant_fulfilment(uuid, text, text, boolean) from public, anon;
grant execute on function public.set_merchant_fulfilment(uuid, text, text, boolean) to authenticated;

create or replace function private.submit_identity_case(p_passport_storage_key text, p_passport_mime_type text, p_passport_original_name text, p_selfie_storage_key text, p_selfie_mime_type text, p_selfie_original_name text, p_consent boolean)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_user uuid := (select auth.uid()); v_merchant_id uuid; v_case_id uuid;
begin
  if v_user is null or not p_consent then raise exception using errcode = 'P0001', message = 'CONSENT_REQUIRED'; end if;
  select id into v_merchant_id from merchants where owner_user_id = v_user order by created_at desc limit 1;
  if v_merchant_id is null then raise exception using errcode = '42501', message = 'MERCHANT_CONTEXT_REQUIRED'; end if;
  insert into identity_verification_cases(merchant_id, submitted_by_user_id, consent_at, status) values(v_merchant_id, v_user, now(), 'submitted')
  on conflict (merchant_id) do update set submitted_by_user_id = excluded.submitted_by_user_id, consent_at = excluded.consent_at, status = 'submitted', reviewed_by_user_id = null, reviewed_at = null, decision_note = null returning id into v_case_id;
  delete from identity_evidence where identity_case_id = v_case_id;
  insert into identity_evidence(identity_case_id, kind, storage_key, mime_type, original_name) values
    (v_case_id, 'passport', p_passport_storage_key, p_passport_mime_type, p_passport_original_name),
    (v_case_id, 'selfie', p_selfie_storage_key, p_selfie_mime_type, p_selfie_original_name);
  update merchants set verification_status = 'pending' where id = v_merchant_id;
  insert into audit_events(actor_user_id, action, resource_type, resource_id) values(v_user, 'identity.case_submitted', 'identity_case', v_case_id::text);
  return jsonb_build_object('identity_case_id', v_case_id, 'status', 'submitted');
end;
$$;
revoke all on function private.submit_identity_case(text, text, text, text, text, text, boolean) from public, anon;
grant execute on function private.submit_identity_case(text, text, text, text, text, text, boolean) to authenticated, service_role;
create or replace function public.submit_identity_case(p_passport_storage_key text, p_passport_mime_type text, p_passport_original_name text, p_selfie_storage_key text, p_selfie_mime_type text, p_selfie_original_name text, p_consent boolean)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.submit_identity_case(p_passport_storage_key, p_passport_mime_type, p_passport_original_name, p_selfie_storage_key, p_selfie_mime_type, p_selfie_original_name, p_consent); $$;
revoke all on function public.submit_identity_case(text, text, text, text, text, text, boolean) from public, anon;
grant execute on function public.submit_identity_case(text, text, text, text, text, text, boolean) to authenticated;

create or replace function private.review_identity_case(p_identity_case_id uuid, p_decision text, p_note text)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_user uuid := (select auth.uid()); v_case identity_verification_cases%rowtype;
begin
  if not private.is_admin() then raise exception using errcode = '42501', message = 'FORBIDDEN'; end if;
  if p_decision not in ('verified','rejected') or length(trim(p_note)) < 3 then raise exception using errcode = 'P0001', message = 'INVALID_IDENTITY_REVIEW'; end if;
  select * into v_case from identity_verification_cases where id = p_identity_case_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'IDENTITY_CASE_NOT_FOUND'; end if;
  update identity_verification_cases set status = p_decision, reviewed_by_user_id = v_user, reviewed_at = now(), decision_note = trim(p_note) where id = p_identity_case_id;
  update merchants set verification_status = p_decision where id = v_case.merchant_id;
  insert into audit_events(actor_user_id, action, resource_type, resource_id, metadata) values(v_user, 'identity.case_' || p_decision, 'identity_case', p_identity_case_id::text, jsonb_build_object('note', p_note));
  return jsonb_build_object('identity_case_id', p_identity_case_id, 'status', p_decision);
end;
$$;
revoke all on function private.review_identity_case(uuid, text, text) from public, anon;
grant execute on function private.review_identity_case(uuid, text, text) to authenticated, service_role;
create or replace function public.review_identity_case(p_identity_case_id uuid, p_decision text, p_note text)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.review_identity_case(p_identity_case_id, p_decision, p_note); $$;
revoke all on function public.review_identity_case(uuid, text, text) from public, anon;
grant execute on function public.review_identity_case(uuid, text, text) to authenticated;

-- Allow the public wrapper to return only safe, owner/admin-scoped data; all writes above remain RPC-only.
grant usage on schema private to authenticated;
