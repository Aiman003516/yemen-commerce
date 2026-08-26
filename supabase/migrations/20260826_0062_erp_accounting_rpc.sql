-- Core ERP accounting authoring RPCs. All writes are audited and scope-checked.

create or replace function private.erp_create_legal_entity(p_organization_id uuid, p_code text, p_name_ar text, p_registration_reference text default null, p_tax_reference text default null)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_user uuid := (select auth.uid()); v_id uuid;
begin
  if v_user is null or not private.erp_org_visible(p_organization_id) then raise exception using errcode = '42501', message = 'ERP_SCOPE_DENIED'; end if;
  if length(trim(p_code)) < 2 or length(trim(p_name_ar)) < 2 then raise exception using errcode = '22023', message = 'ERP_ENTITY_INPUT_INVALID'; end if;
  insert into public.erp_legal_entities(organization_id, code, name_ar, registration_reference, tax_reference)
  values(p_organization_id, upper(trim(p_code)), trim(p_name_ar), nullif(trim(p_registration_reference), ''), nullif(trim(p_tax_reference), ''))
  on conflict (organization_id, code) do update set name_ar = excluded.name_ar, registration_reference = excluded.registration_reference, tax_reference = excluded.tax_reference, updated_at = now()
  returning id into v_id;
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata) values(v_user, 'erp.legal_entity_saved', 'erp_legal_entity', v_id::text, jsonb_build_object('organization_id', p_organization_id, 'code', upper(trim(p_code))));
  return jsonb_build_object('legal_entity_id', v_id, 'status', 'saved');
end;
$$;
revoke all on function private.erp_create_legal_entity(uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function private.erp_create_legal_entity(uuid, text, text, text, text) to authenticated, service_role;
create or replace function public.erp_create_legal_entity(p_organization_id uuid, p_code text, p_name_ar text, p_registration_reference text default null, p_tax_reference text default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.erp_create_legal_entity(p_organization_id, p_code, p_name_ar, p_registration_reference, p_tax_reference); $$;
revoke all on function public.erp_create_legal_entity(uuid, text, text, text, text) from public, anon;
grant execute on function public.erp_create_legal_entity(uuid, text, text, text, text) to authenticated;

create or replace function private.erp_create_book(p_legal_entity_id uuid, p_code text, p_name_ar text, p_accounting_basis text, p_currency text default 'YER')
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_user uuid := (select auth.uid()); v_id uuid; v_org uuid;
begin
  select organization_id into v_org from public.erp_legal_entities where id = p_legal_entity_id;
  if v_user is null or v_org is null or not private.erp_org_visible(v_org) then raise exception using errcode = '42501', message = 'ERP_SCOPE_DENIED'; end if;
  if length(trim(p_code)) < 2 or length(trim(p_name_ar)) < 2 or p_accounting_basis not in ('local_tax','ifrs','us_gaap','management','fund') or char_length(upper(trim(p_currency))) <> 3 then raise exception using errcode = '22023', message = 'ERP_BOOK_INPUT_INVALID'; end if;
  insert into public.erp_accounting_books(legal_entity_id, code, name_ar, accounting_basis, currency)
  values(p_legal_entity_id, upper(trim(p_code)), trim(p_name_ar), p_accounting_basis, upper(trim(p_currency)))
  on conflict (legal_entity_id, code) do update set name_ar = excluded.name_ar, accounting_basis = excluded.accounting_basis, currency = excluded.currency, updated_at = now()
  returning id into v_id;
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata) values(v_user, 'erp.accounting_book_saved', 'erp_accounting_book', v_id::text, jsonb_build_object('legal_entity_id', p_legal_entity_id, 'basis', p_accounting_basis));
  return jsonb_build_object('book_id', v_id, 'status', 'saved');
end;
$$;
revoke all on function private.erp_create_book(uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function private.erp_create_book(uuid, text, text, text, text) to authenticated, service_role;
create or replace function public.erp_create_book(p_legal_entity_id uuid, p_code text, p_name_ar text, p_accounting_basis text, p_currency text default 'YER')
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.erp_create_book(p_legal_entity_id, p_code, p_name_ar, p_accounting_basis, p_currency); $$;
revoke all on function public.erp_create_book(uuid, text, text, text, text) from public, anon;
grant execute on function public.erp_create_book(uuid, text, text, text, text) to authenticated;

create or replace function private.erp_create_account(p_book_id uuid, p_parent_account_id uuid, p_code text, p_name_ar text, p_account_type text, p_normal_balance text)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_user uuid := (select auth.uid()); v_id uuid; v_org uuid;
begin
  select e.organization_id into v_org from public.erp_accounting_books b join public.erp_legal_entities e on e.id = b.legal_entity_id where b.id = p_book_id;
  if v_user is null or v_org is null or not private.erp_org_visible(v_org) then raise exception using errcode = '42501', message = 'ERP_SCOPE_DENIED'; end if;
  if length(trim(p_code)) < 2 or length(trim(p_name_ar)) < 2 or p_account_type not in ('asset','liability','equity','revenue','expense','memorandum') or p_normal_balance not in ('debit','credit') then raise exception using errcode = '22023', message = 'ERP_ACCOUNT_INPUT_INVALID'; end if;
  if p_parent_account_id is not null and not exists(select 1 from public.erp_accounts a where a.id = p_parent_account_id and a.book_id = p_book_id) then raise exception using errcode = '22023', message = 'ERP_PARENT_ACCOUNT_INVALID'; end if;
  insert into public.erp_accounts(book_id, parent_account_id, code, name_ar, account_type, normal_balance)
  values(p_book_id, p_parent_account_id, upper(trim(p_code)), trim(p_name_ar), p_account_type, p_normal_balance)
  on conflict (book_id, code) do update set name_ar = excluded.name_ar, parent_account_id = excluded.parent_account_id, account_type = excluded.account_type, normal_balance = excluded.normal_balance
  returning id into v_id;
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata) values(v_user, 'erp.account_saved', 'erp_account', v_id::text, jsonb_build_object('book_id', p_book_id, 'code', upper(trim(p_code))));
  return jsonb_build_object('account_id', v_id, 'status', 'saved');
end;
$$;
revoke all on function private.erp_create_account(uuid, uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function private.erp_create_account(uuid, uuid, text, text, text, text) to authenticated, service_role;
create or replace function public.erp_create_account(p_book_id uuid, p_parent_account_id uuid, p_code text, p_name_ar text, p_account_type text, p_normal_balance text)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.erp_create_account(p_book_id, p_parent_account_id, p_code, p_name_ar, p_account_type, p_normal_balance); $$;
revoke all on function public.erp_create_account(uuid, uuid, text, text, text, text) from public, anon;
grant execute on function public.erp_create_account(uuid, uuid, text, text, text, text) to authenticated;

create or replace function private.erp_add_journal_line(p_batch_id uuid, p_account_id uuid, p_line_number integer, p_debit_minor bigint, p_credit_minor bigint, p_description_ar text default null, p_dimensions jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare v_user uuid := (select auth.uid()); v_id uuid; v_org uuid; v_book uuid; v_batch_book uuid;
begin
  select b.organization_id, b.book_id into v_org, v_batch_book from public.erp_journal_batches b where b.id = p_batch_id and b.status = 'draft';
  select b.id, e.organization_id into v_book, v_org from public.erp_accounts a join public.erp_accounting_books b on b.id = a.book_id join public.erp_legal_entities e on e.id = b.legal_entity_id where a.id = p_account_id;
  if v_user is null or v_org is null or not private.erp_org_visible(v_org) then raise exception using errcode = '42501', message = 'ERP_SCOPE_DENIED'; end if;
  if v_batch_book is null or v_book <> v_batch_book then raise exception using errcode = '22023', message = 'ERP_ACCOUNT_BOOK_MISMATCH'; end if;
  if p_line_number <= 0 or p_debit_minor < 0 or p_credit_minor < 0 or (p_debit_minor = 0 and p_credit_minor = 0) or (p_debit_minor > 0 and p_credit_minor > 0) then raise exception using errcode = '22023', message = 'ERP_JOURNAL_LINE_INVALID'; end if;
  insert into public.erp_journal_lines(batch_id, account_id, line_number, debit_minor, credit_minor, currency, description_ar, dimensions)
  values(p_batch_id, p_account_id, p_line_number, p_debit_minor, p_credit_minor, 'YER', nullif(trim(p_description_ar), ''), coalesce(p_dimensions, '{}'::jsonb))
  on conflict (batch_id, line_number) do update set account_id = excluded.account_id, debit_minor = excluded.debit_minor, credit_minor = excluded.credit_minor, description_ar = excluded.description_ar, dimensions = excluded.dimensions
  returning id into v_id;
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata) values(v_user, 'erp.journal_line_saved', 'erp_journal_line', v_id::text, jsonb_build_object('batch_id', p_batch_id, 'line_number', p_line_number));
  return jsonb_build_object('journal_line_id', v_id, 'status', 'saved');
end;
$$;
revoke all on function private.erp_add_journal_line(uuid, uuid, integer, bigint, bigint, text, jsonb) from public, anon, authenticated;
grant execute on function private.erp_add_journal_line(uuid, uuid, integer, bigint, bigint, text, jsonb) to authenticated, service_role;
create or replace function public.erp_add_journal_line(p_batch_id uuid, p_account_id uuid, p_line_number integer, p_debit_minor bigint, p_credit_minor bigint, p_description_ar text default null, p_dimensions jsonb default '{}'::jsonb)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.erp_add_journal_line(p_batch_id, p_account_id, p_line_number, p_debit_minor, p_credit_minor, p_description_ar, p_dimensions); $$;
revoke all on function public.erp_add_journal_line(uuid, uuid, integer, bigint, bigint, text, jsonb) from public, anon;
grant execute on function public.erp_add_journal_line(uuid, uuid, integer, bigint, bigint, text, jsonb) to authenticated;
