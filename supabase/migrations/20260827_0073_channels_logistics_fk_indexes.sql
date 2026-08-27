-- Performance remediation for migration 0072 operational records.
create index if not exists delivery_exceptions_opened_by_user_idx
  on public.delivery_exceptions(opened_by_user_id);
create index if not exists delivery_exceptions_resolved_by_user_idx
  on public.delivery_exceptions(resolved_by_user_id);
create index if not exists return_logistics_created_by_user_idx
  on public.return_logistics(created_by_user_id);
create index if not exists return_logistics_events_recorded_by_user_idx
  on public.return_logistics_events(recorded_by_user_id);
create index if not exists shipment_events_recorded_by_user_idx
  on public.shipment_events(recorded_by_user_id);
create index if not exists shipment_plans_created_by_user_idx
  on public.shipment_plans(created_by_user_id);
