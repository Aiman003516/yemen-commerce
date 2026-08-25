-- Creator and delegated-operator authorization foundation.
-- No role or capability is granted by public sign-up; all privileged writes are RPC-only.

alter table public.user_roles drop constraint if exists user_roles_role_check;
alter table public.user_roles add constraint user_roles_role_allowed check (role in ('customer','merchant','admin','creator','platform_operator','review_agent','support_agent'));

create table if not exists public.user_capabilities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  capability text not null check (capability in ('manage_people','manage_merchants','review_identity','manage_markets','manage_policies','manage_capabilities','view_audit','view_sensitive_evidence','manage_reports','export_operational_data')),
  market_id uuid references public.markets(id) on delete cascade,
  granted_by_user_id uuid not null references public.profiles(id) on delete restrict,
  reason text not null,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, capability, market_id)
);
create index if not exists user_capabilities_user_idx on public.user_capabilities(user_id, capability);
create index if not exists user_capabilities_market_idx on public.user_capabilities(market_id, capability);

create table if not exists public.user_access_controls (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  account_status text not null default 'active' check (account_status in ('active','suspended')),
  suspended_at timestamptz,
  suspended_by_user_id uuid references public.profiles(id) on delete set null,
  suspension_reason text,
  suspension_until timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.creator_operator_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('platform_operator','review_agent','support_agent')),
  market_id uuid references public.markets(id) on delete cascade,
  granted_by_user_id uuid not null references public.profiles(id) on delete restrict,
  reason text not null,
  expires_at timestamptz,
  revoked_at timestamptz,
  revoked_by_user_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists creator_assignments_user_idx on public.creator_operator_assignments(user_id, revoked_at, expires_at);
create index if not exists creator_assignments_market_idx on public.creator_operator_assignments(market_id, role);

alter table public.user_capabilities enable row level security;
alter table public.user_access_controls enable row level security;
alter table public.creator_operator_assignments enable row level security;
revoke all on public.user_capabilities, public.user_access_controls, public.creator_operator_assignments from anon, authenticated;
grant select on public.user_capabilities, public.user_access_controls, public.creator_operator_assignments to authenticated;

create or replace function private.current_user_is_creator()
returns boolean language sql stable security definer set search_path = public, pg_catalog as $$
  select exists(
    select 1 from public.user_roles ur
    join public.user_access_controls uac on uac.user_id = ur.user_id and uac.account_status = 'active'
    where ur.user_id = (select auth.uid()) and ur.role = 'creator'
  );
$$;

create or replace function private.current_user_has_capability(p_capability text, p_market_id uuid default null)
returns boolean language sql stable security definer set search_path = public, pg_catalog as $$
  select private.current_user_is_creator()
    or exists(
      select 1 from public.user_capabilities uc
      join public.user_access_controls uac on uac.user_id = uc.user_id and uac.account_status = 'active'
      where uc.user_id = (select auth.uid())
        and uc.capability = p_capability
        and (uc.expires_at is null or uc.expires_at > now())
        and (p_market_id is null or uc.market_id is null or uc.market_id = p_market_id)
    );
$$;

create or replace function private.actor_is_active(p_user_id uuid)
returns boolean language sql stable security definer set search_path = public, pg_catalog as $$
  select not exists(select 1 from public.user_access_controls where user_id = p_user_id and account_status = 'suspended');
$$;

revoke all on function private.current_user_is_creator() from public, anon, authenticated;
revoke all on function private.current_user_has_capability(text, uuid) from public, anon, authenticated;
revoke all on function private.actor_is_active(uuid) from public, anon, authenticated;

drop policy if exists creator_capabilities_read on public.user_capabilities;
create policy creator_capabilities_read on public.user_capabilities for select to authenticated using (user_id = (select auth.uid()) or private.current_user_is_creator() or private.current_user_has_capability('manage_people', market_id));
drop policy if exists creator_access_controls_read on public.user_access_controls;
create policy creator_access_controls_read on public.user_access_controls for select to authenticated using (user_id = (select auth.uid()) or private.current_user_is_creator() or private.current_user_has_capability('manage_people', null));
drop policy if exists creator_assignments_read on public.creator_operator_assignments;
create policy creator_assignments_read on public.creator_operator_assignments for select to authenticated using (user_id = (select auth.uid()) or private.current_user_is_creator() or private.current_user_has_capability('manage_people', market_id));

create or replace function private.record_role_audit(p_actor uuid, p_action text, p_user_id uuid, p_metadata jsonb)
returns void language plpgsql security definer set search_path = public, pg_catalog as $$
begin
  insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata)
  values(p_actor, p_action, 'user', p_user_id::text, p_metadata);
end;
$$;
revoke all on function private.record_role_audit(uuid, text, uuid, jsonb) from public, anon, authenticated;
grant execute on function private.record_role_audit(uuid, text, uuid, jsonb) to authenticated, service_role;

-- Ensure every Auth profile has an explicit active access row without granting privilege.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public, pg_catalog as $$
begin
  insert into public.profiles(id, display_name, email, phone)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'), new.email, new.phone)
  on conflict (id) do update set email = excluded.email, phone = excluded.phone, updated_at = now();
  insert into public.user_roles(user_id, role) values (new.id, 'customer') on conflict do nothing;
  insert into public.user_access_controls(user_id, account_status) values (new.id, 'active') on conflict (user_id) do nothing;
  return new;
end;
$$;
revoke all on function public.handle_new_user() from public, anon, authenticated;
grant execute on function public.handle_new_user() to postgres, service_role;

-- Existing profiles in a fresh project are also initialized safely.
insert into public.user_access_controls(user_id, account_status)
select p.id, 'active' from public.profiles p
on conflict (user_id) do nothing;
