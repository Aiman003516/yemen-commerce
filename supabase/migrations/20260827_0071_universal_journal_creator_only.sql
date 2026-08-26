-- Universal-journal projections are Creator-only governance/financial views.
-- Merchant organization ownership does not grant direct access to journal projections.
drop policy if exists erp_universal_journal_scope_read on public.erp_universal_journal_entries;
create policy erp_universal_journal_creator_read on public.erp_universal_journal_entries
for select to authenticated
using (private.current_user_is_creator());
