-- AI-0 performance remediation: cover the policy author foreign key used by
-- creator policy inspection and audit-oriented joins.
create index if not exists ai_policies_created_by_idx
  on public.ai_policies(created_by_user_id, created_at desc);
