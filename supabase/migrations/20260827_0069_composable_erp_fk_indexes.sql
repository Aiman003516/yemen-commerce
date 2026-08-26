-- Performance remediation for composable ERP foreign keys identified after 0068.
create index if not exists erp_event_inbox_event_idx on public.erp_event_inbox(event_id, created_at desc);
create index if not exists erp_projection_checkpoints_event_idx on public.erp_projection_checkpoints(last_event_id, updated_at desc);
create index if not exists erp_universal_journal_entries_book_idx on public.erp_universal_journal_entries(book_id, posting_date desc);
