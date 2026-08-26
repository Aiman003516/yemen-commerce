-- ERP merchant-safe read projections. No creator configuration or sensitive financial evidence is exposed.

create or replace function private.erp_list_feature_catalog()
returns table(feature_key text, module_key text, name_ar text, name_en text, implementation_status text, provider_required boolean, enabled boolean, description text)
language sql security definer set search_path = public, private, pg_catalog as $$
  select feature_key, module_key, name_ar, name_en, implementation_status, provider_required, enabled, description
  from public.erp_feature_registry
  order by module_key, feature_key
  limit 100;
$$;
revoke all on function private.erp_list_feature_catalog() from public, anon, authenticated;
grant execute on function private.erp_list_feature_catalog() to authenticated, service_role;
create or replace function public.erp_list_feature_catalog()
returns table(feature_key text, module_key text, name_ar text, name_en text, implementation_status text, provider_required boolean, enabled boolean, description text)
language sql security invoker set search_path = public, pg_catalog as $$ select * from private.erp_list_feature_catalog(); $$;
revoke all on function public.erp_list_feature_catalog() from public, anon;
grant execute on function public.erp_list_feature_catalog() to authenticated;

create or replace function private.erp_get_my_organization_dashboard()
returns jsonb language sql security definer set search_path = public, private, pg_catalog as $$
  select jsonb_build_object(
    'organization_id', o.id,
    'name_ar', o.name_ar,
    'status', o.status,
    'currency', o.base_currency,
    'legal_entity_count', (select count(*) from public.erp_legal_entities e where e.organization_id = o.id),
    'active_book_count', (select count(*) from public.erp_accounting_books b join public.erp_legal_entities e on e.id = b.legal_entity_id where e.organization_id = o.id and b.status = 'active'),
    'draft_journal_count', (select count(*) from public.erp_journal_batches j where j.organization_id = o.id and j.status = 'draft'),
    'open_bill_count', (select count(*) from public.erp_bills b where b.organization_id = o.id and b.status in ('pending_match','pending_approval','approved','partially_paid')),
    'open_event_count', (select count(*) from public.erp_event_outbox e where e.organization_id = o.id and e.status in ('pending','leased','failed')),
    'open_anomaly_count', (select count(*) from public.erp_anomaly_findings a where a.organization_id = o.id and a.status = 'open')
  )
  from public.erp_organizations o
  where o.owner_user_id = (select auth.uid())
     or exists(
       select 1 from public.merchants m
       where m.id = o.merchant_id and m.owner_user_id = (select auth.uid())
     )
  order by o.created_at desc
  limit 1;
$$;
revoke all on function private.erp_get_my_organization_dashboard() from public, anon, authenticated;
grant execute on function private.erp_get_my_organization_dashboard() to authenticated, service_role;
create or replace function public.erp_get_my_organization_dashboard()
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$ select private.erp_get_my_organization_dashboard(); $$;
revoke all on function public.erp_get_my_organization_dashboard() from public, anon;
grant execute on function public.erp_get_my_organization_dashboard() to authenticated;
