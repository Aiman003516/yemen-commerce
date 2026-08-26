-- Performance remediation for the new COD reconciliation foreign keys.
create index if not exists cod_reconciliation_batches_created_by_user_id_idx
  on public.cod_reconciliation_batches(created_by_user_id);
create index if not exists cod_reconciliation_batches_closed_by_user_id_idx
  on public.cod_reconciliation_batches(closed_by_user_id);
