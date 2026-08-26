-- Require a non-empty audit reason for Creator ERP authoring mutations.
-- Existing signatures are removed so callers cannot bypass the reason contract.

drop function if exists public.erp_create_organization(uuid, text, text, text, uuid);
drop function if exists private.erp_create_organization(uuid, text, text, text, uuid);
create function private.erp_create_organization(p_market_id uuid, p_code text, p_name_ar text, p_reason text, p_legal_name text default null, p_merchant_id uuid default null)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare
  v_user uuid := (select auth.uid());
  v_id uuid;
  v_existing_owner uuid;
  v_is_creator boolean := private.current_user_is_creator();
begin
  if v_user is null then raise exception using errcode = '42501', message = 'AUTH_REQUIRED'; end if;
  if p_market_id is null or length(trim(p_code)) < 2 or length(trim(p_name_ar)) < 2 then raise exception using errcode = '22023', message = 'ERP_ORGANIZATION_INPUT_INVALID'; end if;
  if length(trim(coalesce(p_reason, ''))) < 3 then raise exception using errcode = '22023', message = 'ERP_REASON_REQUIRED'; end if;
  if p_merchant_id is not null and not exists(select 1 from public.merchants m where m.id = p_merchant_id and m.owner_user_id = v_user) and not v_is_creator then raise exception using errcode = '42501', message = 'ERP_MERCHANT_SCOPE_DENIED'; end if;

  select id, owner_user_id into v_id, v_existing_owner
  from public.erp_organizations
  where market_id = p_market_id and code = upper(trim(p_code))
  limit 1;
  if v_id is not null and v_existing_owner <> v_user and not v_is_creator then
    raise exception using errcode = '42501', message = 'ERP_ORGANIZATION_CONFLICT';
  end if;

  insert into public.erp_organizations(owner_user_id, merchant_id, market_id, code, name_ar, legal_name, status)
  values(v_user, p_merchant_id, p_market_id, upper(trim(p_code)), trim(p_name_ar), nullif(trim(p_legal_name), ''), case when v_is_creator then 'active' else 'draft' end)
  on conflict (market_id, code) do update set name_ar = excluded.name_ar, legal_name = excluded.legal_name, updated_at = now()
  returning id into v_id;
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'erp.organization_saved', 'erp_organization', v_id::text, jsonb_build_object('market_id', p_market_id, 'code', upper(trim(p_code)), 'reason', trim(p_reason)));
  return jsonb_build_object('organization_id', v_id, 'status', 'saved');
end;
$$;
revoke all on function private.erp_create_organization(uuid, text, text, text, text, uuid) from public, anon, authenticated;
grant execute on function private.erp_create_organization(uuid, text, text, text, text, uuid) to authenticated, service_role;
create function public.erp_create_organization(p_market_id uuid, p_code text, p_name_ar text, p_reason text, p_legal_name text default null, p_merchant_id uuid default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.erp_create_organization(p_market_id, p_code, p_name_ar, p_reason, p_legal_name, p_merchant_id); $$;
revoke all on function public.erp_create_organization(uuid, text, text, text, text, uuid) from public, anon;
grant execute on function public.erp_create_organization(uuid, text, text, text, text, uuid) to authenticated;

-- Legal entity
 drop function if exists public.erp_create_legal_entity(uuid, text, text, text, text);
drop function if exists private.erp_create_legal_entity(uuid, text, text, text, text);
create function private.erp_create_legal_entity(p_organization_id uuid, p_code text, p_name_ar text, p_reason text, p_registration_reference text default null, p_tax_reference text default null)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_user uuid := (select auth.uid()); v_id uuid;
begin
  if v_user is null or not private.erp_org_visible(p_organization_id) then raise exception using errcode = '42501', message = 'ERP_SCOPE_DENIED'; end if;
  if length(trim(p_code)) < 2 or length(trim(p_name_ar)) < 2 then raise exception using errcode = '22023', message = 'ERP_ENTITY_INPUT_INVALID'; end if;
  if length(trim(coalesce(p_reason, ''))) < 3 then raise exception using errcode = '22023', message = 'ERP_REASON_REQUIRED'; end if;
  insert into public.erp_legal_entities(organization_id, code, name_ar, registration_reference, tax_reference)
  values(p_organization_id, upper(trim(p_code)), trim(p_name_ar), nullif(trim(p_registration_reference), ''), nullif(trim(p_tax_reference), ''))
  on conflict (organization_id, code) do update set name_ar = excluded.name_ar, registration_reference = excluded.registration_reference, tax_reference = excluded.tax_reference, updated_at = now()
  returning id into v_id;
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'erp.legal_entity_saved', 'erp_legal_entity', v_id::text, jsonb_build_object('organization_id', p_organization_id, 'code', upper(trim(p_code)), 'reason', trim(p_reason)));
  return jsonb_build_object('legal_entity_id', v_id, 'status', 'saved');
end;
$$;
revoke all on function private.erp_create_legal_entity(uuid, text, text, text, text, text) from public, anon, authenticated;
grant execute on function private.erp_create_legal_entity(uuid, text, text, text, text, text) to authenticated, service_role;
create function public.erp_create_legal_entity(p_organization_id uuid, p_code text, p_name_ar text, p_reason text, p_registration_reference text default null, p_tax_reference text default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.erp_create_legal_entity(p_organization_id, p_code, p_name_ar, p_reason, p_registration_reference, p_tax_reference); $$;
revoke all on function public.erp_create_legal_entity(uuid, text, text, text, text, text) from public, anon;
grant execute on function public.erp_create_legal_entity(uuid, text, text, text, text, text) to authenticated;

-- Accounting book
 drop function if exists public.erp_create_book(uuid, text, text, text, text);
drop function if exists private.erp_create_book(uuid, text, text, text, text);
create function private.erp_create_book(p_legal_entity_id uuid, p_code text, p_name_ar text, p_accounting_basis text, p_reason text, p_currency text default 'YER')
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_user uuid := (select auth.uid()); v_id uuid; v_org uuid;
begin
  select organization_id into v_org from public.erp_legal_entities where id = p_legal_entity_id;
  if v_user is null or v_org is null or not private.erp_org_visible(v_org) then raise exception using errcode = '42501', message = 'ERP_SCOPE_DENIED'; end if;
  if length(trim(p_code)) < 2 or length(trim(p_name_ar)) < 2 or p_accounting_basis not in ('local_tax','ifrs','us_gaap','management','fund') or char_length(upper(trim(p_currency))) <> 3 then raise exception using errcode = '22023', message = 'ERP_BOOK_INPUT_INVALID'; end if;
  if length(trim(coalesce(p_reason, ''))) < 3 then raise exception using errcode = '22023', message = 'ERP_REASON_REQUIRED'; end if;
  insert into public.erp_accounting_books(legal_entity_id, code, name_ar, accounting_basis, currency)
  values(p_legal_entity_id, upper(trim(p_code)), trim(p_name_ar), p_accounting_basis, upper(trim(p_currency)))
  on conflict (legal_entity_id, code) do update set name_ar = excluded.name_ar, accounting_basis = excluded.accounting_basis, currency = excluded.currency, updated_at = now()
  returning id into v_id;
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'erp.accounting_book_saved', 'erp_accounting_book', v_id::text, jsonb_build_object('legal_entity_id', p_legal_entity_id, 'basis', p_accounting_basis, 'reason', trim(p_reason)));
  return jsonb_build_object('book_id', v_id, 'status', 'saved');
end;
$$;
revoke all on function private.erp_create_book(uuid, text, text, text, text, text) from public, anon, authenticated;
grant execute on function private.erp_create_book(uuid, text, text, text, text, text) to authenticated, service_role;
create function public.erp_create_book(p_legal_entity_id uuid, p_code text, p_name_ar text, p_accounting_basis text, p_reason text, p_currency text default 'YER')
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.erp_create_book(p_legal_entity_id, p_code, p_name_ar, p_accounting_basis, p_reason, p_currency); $$;
revoke all on function public.erp_create_book(uuid, text, text, text, text, text) from public, anon;
grant execute on function public.erp_create_book(uuid, text, text, text, text, text) to authenticated;

-- Chart of accounts
 drop function if exists public.erp_create_account(uuid, uuid, text, text, text, text);
drop function if exists private.erp_create_account(uuid, uuid, text, text, text, text);
create function private.erp_create_account(p_book_id uuid, p_parent_account_id uuid, p_code text, p_name_ar text, p_account_type text, p_normal_balance text, p_reason text)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_user uuid := (select auth.uid()); v_id uuid; v_org uuid;
begin
  select e.organization_id into v_org from public.erp_accounting_books b join public.erp_legal_entities e on e.id = b.legal_entity_id where b.id = p_book_id;
  if v_user is null or v_org is null or not private.erp_org_visible(v_org) then raise exception using errcode = '42501', message = 'ERP_SCOPE_DENIED'; end if;
  if length(trim(p_code)) < 2 or length(trim(p_name_ar)) < 2 or p_account_type not in ('asset','liability','equity','revenue','expense','memorandum') or p_normal_balance not in ('debit','credit') then raise exception using errcode = '22023', message = 'ERP_ACCOUNT_INPUT_INVALID'; end if;
  if length(trim(coalesce(p_reason, ''))) < 3 then raise exception using errcode = '22023', message = 'ERP_REASON_REQUIRED'; end if;
  if p_parent_account_id is not null and not exists(select 1 from public.erp_accounts a where a.id = p_parent_account_id and a.book_id = p_book_id) then raise exception using errcode = '22023', message = 'ERP_PARENT_ACCOUNT_INVALID'; end if;
  insert into public.erp_accounts(book_id, parent_account_id, code, name_ar, account_type, normal_balance)
  values(p_book_id, p_parent_account_id, upper(trim(p_code)), trim(p_name_ar), p_account_type, p_normal_balance)
  on conflict (book_id, code) do update set name_ar = excluded.name_ar, parent_account_id = excluded.parent_account_id, account_type = excluded.account_type, normal_balance = excluded.normal_balance
  returning id into v_id;
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'erp.account_saved', 'erp_account', v_id::text, jsonb_build_object('book_id', p_book_id, 'code', upper(trim(p_code)), 'reason', trim(p_reason)));
  return jsonb_build_object('account_id', v_id, 'status', 'saved');
end;
$$;
revoke all on function private.erp_create_account(uuid, uuid, text, text, text, text, text) from public, anon, authenticated;
grant execute on function private.erp_create_account(uuid, uuid, text, text, text, text, text) to authenticated, service_role;
create function public.erp_create_account(p_book_id uuid, p_parent_account_id uuid, p_code text, p_name_ar text, p_account_type text, p_normal_balance text, p_reason text)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.erp_create_account(p_book_id, p_parent_account_id, p_code, p_name_ar, p_account_type, p_normal_balance, p_reason); $$;
revoke all on function public.erp_create_account(uuid, uuid, text, text, text, text, text) from public, anon;
grant execute on function public.erp_create_account(uuid, uuid, text, text, text, text, text) to authenticated;

-- Journal batch draft creation
 drop function if exists public.erp_create_journal_batch(uuid, uuid, text, text, text, text);
drop function if exists private.erp_create_journal_batch(uuid, uuid, text, text, text, text);
create function private.erp_create_journal_batch(p_organization_id uuid, p_book_id uuid, p_source_type text, p_source_id text, p_idempotency_key text, p_reason text, p_description_ar text default null)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_user uuid := (select auth.uid()); v_id uuid;
begin
  if v_user is null or not private.erp_org_visible(p_organization_id) then raise exception using errcode = '42501', message = 'ERP_SCOPE_DENIED'; end if;
  if not exists(select 1 from public.erp_accounting_books b join public.erp_legal_entities e on e.id = b.legal_entity_id where b.id = p_book_id and e.organization_id = p_organization_id) then raise exception using errcode = '22023', message = 'ERP_BOOK_SCOPE_INVALID'; end if;
  if length(trim(p_source_type)) < 2 or length(trim(p_idempotency_key)) < 8 then raise exception using errcode = '22023', message = 'ERP_JOURNAL_INPUT_INVALID'; end if;
  if length(trim(coalesce(p_reason, ''))) < 3 then raise exception using errcode = '22023', message = 'ERP_REASON_REQUIRED'; end if;
  insert into public.erp_journal_batches(organization_id, book_id, source_type, source_id, idempotency_key, description_ar, created_by_user_id)
  values(p_organization_id, p_book_id, trim(p_source_type), nullif(trim(p_source_id), ''), trim(p_idempotency_key), nullif(trim(p_description_ar), ''), v_user)
  on conflict (organization_id, idempotency_key) do nothing
  returning id into v_id;
  if v_id is null then select id into v_id from public.erp_journal_batches where organization_id = p_organization_id and idempotency_key = trim(p_idempotency_key); end if;
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'erp.journal_batch_created', 'erp_journal_batch', v_id::text, jsonb_build_object('source_type', trim(p_source_type), 'idempotency_key', trim(p_idempotency_key), 'reason', trim(p_reason)));
  return jsonb_build_object('journal_batch_id', v_id, 'status', 'draft');
end;
$$;
revoke all on function private.erp_create_journal_batch(uuid, uuid, text, text, text, text, text) from public, anon, authenticated;
grant execute on function private.erp_create_journal_batch(uuid, uuid, text, text, text, text, text) to authenticated, service_role;
create function public.erp_create_journal_batch(p_organization_id uuid, p_book_id uuid, p_source_type text, p_source_id text, p_idempotency_key text, p_reason text, p_description_ar text default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.erp_create_journal_batch(p_organization_id, p_book_id, p_source_type, p_source_id, p_idempotency_key, p_reason, p_description_ar); $$;
revoke all on function public.erp_create_journal_batch(uuid, uuid, text, text, text, text, text) from public, anon;
grant execute on function public.erp_create_journal_batch(uuid, uuid, text, text, text, text, text) to authenticated;
