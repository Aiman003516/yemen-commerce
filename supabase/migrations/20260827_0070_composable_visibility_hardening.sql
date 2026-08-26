-- Visibility hardening for composable ERP projections.
-- Merchant clients receive safe module metadata only; financial/event control views remain creator-only.

drop policy if exists erp_module_registry_read on public.erp_module_registry;
create policy erp_module_registry_read on public.erp_module_registry for select to authenticated
using ((owner_surface <> 'creator' and enabled) or private.current_user_is_creator());

drop policy if exists erp_module_contracts_read on public.erp_module_contracts;
create policy erp_module_contracts_read on public.erp_module_contracts for select to authenticated
using (
  status = 'active'
  and exists(
    select 1
    from public.erp_module_registry m
    where m.module_key = public.erp_module_contracts.module_key
      and ((m.owner_surface <> 'creator' and m.enabled) or private.current_user_is_creator())
  )
);

create or replace function private.erp_list_composable_modules()
returns table(module_key text, bounded_context text, owner_surface text, api_version text, implementation_status text, provider_required boolean, enabled boolean, route_key text, name_ar text, description_ar text, extension_slots jsonb)
language sql stable security definer set search_path = public, private, pg_catalog as $$
  select module_key, bounded_context, owner_surface, api_version, implementation_status, provider_required, enabled, route_key, name_ar, description_ar, extension_slots
  from public.erp_module_registry
  where ((owner_surface <> 'creator' and enabled) or private.current_user_is_creator())
  order by owner_surface, module_key
$$;

create or replace function private.erp_get_event_mesh_dashboard(p_organization_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public, private, pg_catalog as $$
declare v_result jsonb;
begin
  if not private.current_user_is_creator() then raise exception using errcode = '42501', message = 'CREATOR_SCOPE_DENIED'; end if;
  if p_organization_id is null or not private.erp_org_visible(p_organization_id) then raise exception using errcode = '42501', message = 'ERP_SCOPE_DENIED'; end if;
  select jsonb_build_object(
    'pending_event_count', (select count(*) from public.erp_event_outbox where organization_id = p_organization_id and status in ('pending','leased','failed')),
    'dead_letter_event_count', (select count(*) from public.erp_event_outbox where organization_id = p_organization_id and status = 'dead_letter'),
    'inbox_failed_count', (select count(*) from public.erp_event_inbox i join public.erp_event_outbox e on e.id = i.event_id where e.organization_id = p_organization_id and i.status in ('failed','dead_letter')),
    'checkpoint_count', (select count(*) from public.erp_projection_checkpoints),
    'active_module_count', (select count(*) from public.erp_module_registry where enabled),
    'external_delivery_enabled', false,
    'worker_state', 'disabled_by_default'
  ) into v_result;
  return v_result;
end;
$$;

create or replace function private.erp_list_universal_journal(p_organization_id uuid, p_from_date date default null, p_to_date date default null, p_limit integer default 50)
returns table(entry_id uuid, posting_date date, ledger_class text, entry_status text, account_id uuid, debit_minor bigint, credit_minor bigint, currency text, source_type text, source_id text, worktags jsonb, projected_at timestamptz)
language sql stable security definer set search_path = public, private, pg_catalog as $$
  select id, posting_date, ledger_class, entry_status, account_id, debit_minor, credit_minor, currency, source_type, source_id, worktags, projected_at
  from public.erp_universal_journal_entries
  where private.current_user_is_creator()
    and private.erp_org_visible(p_organization_id)
    and organization_id = p_organization_id
    and (p_from_date is null or posting_date >= p_from_date)
    and (p_to_date is null or posting_date <= p_to_date)
  order by posting_date desc, projected_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 100)
$$;
