-- Harden journal-line scope validation: never overwrite the batch organization while resolving the account.
create or replace function private.erp_add_journal_line(p_batch_id uuid, p_account_id uuid, p_line_number integer, p_debit_minor bigint, p_credit_minor bigint, p_description_ar text default null, p_dimensions jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = public, private, pg_catalog as $$
declare
  v_user uuid := (select auth.uid());
  v_id uuid;
  v_batch_org uuid;
  v_account_org uuid;
  v_batch_book uuid;
  v_account_book uuid;
begin
  select b.organization_id, b.book_id
    into v_batch_org, v_batch_book
  from public.erp_journal_batches b
  where b.id = p_batch_id
    and b.status = 'draft';

  select b.id, e.organization_id
    into v_account_book, v_account_org
  from public.erp_accounts a
  join public.erp_accounting_books b on b.id = a.book_id
  join public.erp_legal_entities e on e.id = b.legal_entity_id
  where a.id = p_account_id;

  if v_user is null or v_batch_org is null or v_account_org is null
     or not private.erp_org_visible(v_batch_org)
     or v_account_org <> v_batch_org then
    raise exception using errcode = '42501', message = 'ERP_SCOPE_DENIED';
  end if;
  if v_batch_book is null or v_account_book <> v_batch_book then
    raise exception using errcode = '22023', message = 'ERP_ACCOUNT_BOOK_MISMATCH';
  end if;
  if p_line_number <= 0
     or p_debit_minor < 0
     or p_credit_minor < 0
     or (p_debit_minor = 0 and p_credit_minor = 0)
     or (p_debit_minor > 0 and p_credit_minor > 0) then
    raise exception using errcode = '22023', message = 'ERP_JOURNAL_LINE_INVALID';
  end if;

  insert into public.erp_journal_lines(batch_id, account_id, line_number, debit_minor, credit_minor, currency, description_ar, dimensions)
  values(p_batch_id, p_account_id, p_line_number, p_debit_minor, p_credit_minor, 'YER', nullif(trim(p_description_ar), ''), coalesce(p_dimensions, '{}'::jsonb))
  on conflict (batch_id, line_number) do update
    set account_id = excluded.account_id,
        debit_minor = excluded.debit_minor,
        credit_minor = excluded.credit_minor,
        description_ar = excluded.description_ar,
        dimensions = excluded.dimensions
  returning id into v_id;

  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(v_user, 'erp.journal_line_saved', 'erp_journal_line', v_id::text,
         jsonb_build_object('batch_id', p_batch_id, 'line_number', p_line_number));
  return jsonb_build_object('journal_line_id', v_id, 'status', 'saved');
end;
$$;

revoke all on function private.erp_add_journal_line(uuid, uuid, integer, bigint, bigint, text, jsonb) from public, anon, authenticated;
grant execute on function private.erp_add_journal_line(uuid, uuid, integer, bigint, bigint, text, jsonb) to authenticated, service_role;

create or replace function public.erp_add_journal_line(p_batch_id uuid, p_account_id uuid, p_line_number integer, p_debit_minor bigint, p_credit_minor bigint, p_description_ar text default null, p_dimensions jsonb default '{}'::jsonb)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$
  select private.erp_add_journal_line(p_batch_id, p_account_id, p_line_number, p_debit_minor, p_credit_minor, p_description_ar, p_dimensions);
$$;
revoke all on function public.erp_add_journal_line(uuid, uuid, integer, bigint, bigint, text, jsonb) from public, anon;
grant execute on function public.erp_add_journal_line(uuid, uuid, integer, bigint, bigint, text, jsonb) to authenticated;
