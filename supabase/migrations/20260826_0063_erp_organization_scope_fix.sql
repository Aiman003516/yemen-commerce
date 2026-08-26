-- Fix organization upsert authorization: uniqueness conflicts must not become cross-merchant updates.
create or replace function private.erp_create_organization(p_market_id uuid, p_code text, p_name_ar text, p_legal_name text default null, p_merchant_id uuid default null)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare
  v_user uuid := (select auth.uid());
  v_id uuid;
  v_existing_owner uuid;
  v_is_creator boolean := private.current_user_is_creator();
begin
  if v_user is null then raise exception using errcode = '42501', message = 'AUTH_REQUIRED'; end if;
  if p_market_id is null or length(trim(p_code)) < 2 or length(trim(p_name_ar)) < 2 then raise exception using errcode = '22023', message = 'ERP_ORGANIZATION_INPUT_INVALID'; end if;
  if p_merchant_id is not null and not exists(select 1 from public.merchants m where m.id = p_merchant_id and m.owner_user_id = v_user) and not v_is_creator then raise exception using errcode = '42501', message = 'ERP_MERCHANT_SCOPE_DENIED'; end if;

  select id, owner_user_id into v_id, v_existing_owner
  from public.erp_organizations
  where market_id = p_market_id and code = upper(trim(p_code))
  limit 1;
  if v_id is not null and v_existing_owner <> v_user and not v_is_creator then
    raise exception using errcode = '42501', message = 'ERP_ORGANIZATION_CONFLICT';
  end if;

  if v_id is null then
    insert into public.erp_organizations(owner_user_id, merchant_id, market_id, code, name_ar, legal_name, status)
    values(v_user, p_merchant_id, p_market_id, upper(trim(p_code)), trim(p_name_ar), nullif(trim(p_legal_name), ''), case when v_is_creator then 'active' else 'draft' end)
    returning id into v_id;
  else
    update public.erp_organizations
    set name_ar = trim(p_name_ar), legal_name = nullif(trim(p_legal_name), ''), updated_at = now()
    where id = v_id;
  end if;

  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'erp.organization_saved', 'erp_organization', v_id::text, jsonb_build_object('market_id', p_market_id, 'code', upper(trim(p_code)), 'existing', v_existing_owner is not null));
  return jsonb_build_object('organization_id', v_id, 'status', 'saved');
end;
$$;
revoke all on function private.erp_create_organization(uuid, text, text, text, uuid) from public, anon, authenticated;
grant execute on function private.erp_create_organization(uuid, text, text, text, uuid) to authenticated, service_role;
