-- Keep the external usage ledger inaccessible to direct client table reads while
-- making the intentional deny posture explicit for security linting.

drop policy if exists ai_external_usage_daily_no_direct_access on public.ai_external_usage_daily;
create policy ai_external_usage_daily_no_direct_access
on public.ai_external_usage_daily
for all to authenticated
using (false)
with check (false);

commit;
