begin;

create table if not exists public.ai_action_definitions (
  action_key text primary key,
  app_surface text not null check (app_surface in ('merchant', 'developer')),
  action_class text not null check (action_class in ('reversible_write', 'high_impact_write', 'external_side_effect', 'sensitive_read')),
  approval_required boolean not null default true,
  enabled boolean not null default true,
  description text not null,
  created_at timestamptz not null default now()
);

alter table public.ai_action_definitions enable row level security;
revoke all on public.ai_action_definitions from anon, authenticated;
grant select on public.ai_action_definitions to authenticated;

drop policy if exists ai_action_definitions_creator_select on public.ai_action_definitions;
create policy ai_action_definitions_creator_select
on public.ai_action_definitions
for select to authenticated
using (private.current_user_is_creator());

create index if not exists ai_action_definitions_surface_enabled_idx
  on public.ai_action_definitions(app_surface, enabled, action_class);

insert into public.ai_action_definitions(action_key, app_surface, action_class, approval_required, description)
values
  ('merchant.catalog_bulk_save', 'merchant', 'reversible_write', true, 'Apply a bounded idempotent catalog batch after merchant review.'),
  ('merchant.save_price_list', 'merchant', 'reversible_write', true, 'Create or update a merchant-owned wholesale price list after review.'),
  ('merchant.save_price_list_item', 'merchant', 'reversible_write', true, 'Create or update one merchant-owned wholesale price-list line after review.'),
  ('merchant.save_promotion', 'merchant', 'reversible_write', true, 'Create or update a merchant-owned promotion after review.'),
  ('merchant.inventory_adjustment', 'merchant', 'reversible_write', true, 'Record one idempotent merchant inventory adjustment after review.'),
  ('merchant.inventory_transfer', 'merchant', 'reversible_write', true, 'Complete a bounded merchant inventory transfer after review.'),
  ('merchant.inventory_count', 'merchant', 'reversible_write', true, 'Apply a bounded merchant inventory count after review.'),
  ('merchant.open_support_ticket', 'merchant', 'reversible_write', true, 'Open a merchant support ticket after review.'),
  ('developer.ai_policy_change', 'developer', 'high_impact_write', true, 'Change an AI policy only through creator governance and approval controls.')
on conflict (action_key) do nothing;

create or replace function private.ai_list_action_definitions()
returns setof jsonb
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $$
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '28000', message = 'AUTH_REQUIRED';
  end if;
  if not private.current_user_is_creator() then
    raise exception using errcode = '42501', message = 'AI_DEVELOPER_CREATOR_REQUIRED';
  end if;
  return query
  select jsonb_build_object(
    'action_key', d.action_key,
    'app_surface', d.app_surface,
    'action_class', d.action_class,
    'approval_required', d.approval_required,
    'enabled', d.enabled,
    'description', d.description
  )
  from public.ai_action_definitions d
  order by d.app_surface, d.action_key
  limit 100;
end;
$$;
revoke all on function private.ai_list_action_definitions() from public, anon, authenticated;
grant execute on function private.ai_list_action_definitions() to authenticated, service_role;

create or replace function public.ai_list_action_definitions()
returns setof jsonb
language sql
security invoker
set search_path = public, pg_catalog
as $$ select * from private.ai_list_action_definitions(); $$;
revoke all on function public.ai_list_action_definitions() from public, anon;
grant execute on function public.ai_list_action_definitions() to authenticated;

insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata)
select null, 'ai.action_registry_seeded', 'ai_action_definitions', 'system', jsonb_build_object('version', 'ai3')
where not exists (
  select 1 from public.audit_events where action = 'ai.action_registry_seeded' and resource_id = 'system'
);

commit;
