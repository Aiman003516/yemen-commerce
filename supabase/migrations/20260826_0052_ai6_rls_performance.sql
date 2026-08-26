begin;

drop policy if exists ai_workflows_actor_select on public.ai_workflows;
create policy ai_workflows_actor_select on public.ai_workflows for select to authenticated
using (actor_user_id = (select auth.uid()) or private.current_user_is_creator());

drop policy if exists ai_external_consents_owner_select on public.ai_external_consents;
create policy ai_external_consents_owner_select on public.ai_external_consents for select to authenticated
using (user_id = (select auth.uid()) or private.current_user_is_creator());

commit;
