-- AI-0 advisor remediation: retain deny-by-default policy metadata while
-- giving only creator principals direct authenticated read access. Runtime
-- callers should prefer the bounded ai_list_effective_policies() RPC.

drop policy if exists ai_policies_creator_read on public.ai_policies;
create policy ai_policies_creator_read on public.ai_policies
for select to authenticated
using (private.current_user_is_creator());
