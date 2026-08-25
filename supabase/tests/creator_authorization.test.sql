-- Creator authorization test starter.
-- Execute in an isolated Supabase test project with synthetic Auth users.
-- Setup/teardown may use service_role; assertions must use Data API/RPC caller roles.

begin;

select plan(14);

select has_table('public', 'user_capabilities', 'capabilities table exists');
select has_table('public', 'user_access_controls', 'access-control table exists');
select has_table('public', 'creator_operator_assignments', 'delegation table exists');
select has_index('public', 'user_capabilities_user_idx', 'capabilities are indexed by user');
select has_index('public', 'creator_assignments_user_idx', 'delegations are indexed by user');
select has_function('public', 'creator_current_access', 'creator access RPC exists');
select has_function('public', 'creator_dashboard_summary', 'creator dashboard RPC exists');
select has_function('public', 'creator_people_search', 'creator people search RPC exists');
select has_function('public', 'creator_set_user_role', 'creator role RPC exists');
select has_function('public', 'creator_revoke_user_role', 'creator revoke RPC exists');
select has_function('public', 'creator_set_account_status', 'creator suspension RPC exists');
select has_function('public', 'creator_set_capability', 'creator capability RPC exists');

select ok(not has_function_privilege('anon', 'public.creator_dashboard_summary()', 'execute'), 'anonymous users cannot execute creator dashboard');
select ok(not has_function_privilege('anon', 'public.creator_set_user_role(uuid,text,uuid,timestamptz,text)', 'execute'), 'anonymous users cannot execute role assignment');

-- Required API-level cases for the isolated synthetic-user runner:
-- 1. customer -> creator_dashboard_summary must return FORBIDDEN.
-- 2. merchant -> creator_people_search must return FORBIDDEN.
-- 3. review_agent without manage_people -> creator_set_user_role must return FORBIDDEN.
-- 4. creator -> people search returns only minimized profile fields and is paginated.
-- 5. creator cannot suspend itself or another creator.
-- 6. creator cannot revoke the final creator role.
-- 7. creator can grant an expiring review_agent assignment with reason and audit event.
-- 8. delegated operator can act only within its market scope.
-- 9. suspended users cannot use privileged RPCs even when a capability row remains.
-- 10. users cannot write user_roles, user_capabilities, user_access_controls, or assignments directly.

select * from finish();
rollback;
