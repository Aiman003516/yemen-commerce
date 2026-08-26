-- Targeted indexes for new inventory/catalog foreign keys.
-- These support RLS ownership checks, audit joins, and operational history reads.

create index if not exists catalog_import_batches_created_by_idx
  on public.catalog_import_batches(created_by_user_id, created_at desc);
create index if not exists inventory_counts_created_by_idx
  on public.inventory_counts(created_by_user_id, created_at desc);
create index if not exists inventory_movements_recorded_by_idx
  on public.inventory_movements(recorded_by_user_id, created_at desc);
create index if not exists inventory_transfers_created_by_idx
  on public.inventory_transfers(created_by_user_id, created_at desc);
create index if not exists inventory_transfers_from_location_idx
  on public.inventory_transfers(from_location_id, created_at desc);
create index if not exists inventory_transfers_to_location_idx
  on public.inventory_transfers(to_location_id, created_at desc);
