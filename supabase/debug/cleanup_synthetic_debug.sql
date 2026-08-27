-- Yemen Commerce synthetic debug cleanup.
-- Run only against the explicitly authorized mock/debug project.
-- This removes the fixed fixture graph, dynamic workflow fixtures created by the
-- authenticated harnesses, legacy direct-SQL example.invalid users, and the six
-- exact *.auth.debug@mock.yemencommerce.dev accounts. It does not target any
-- unrelated user or real business data.

begin;

-- Mock cleanup needs to remove test rows protected by immutable-record triggers.
-- The trigger definitions are recreated verbatim before commit.
drop trigger if exists shipment_events_append_only on public.shipment_events;
drop trigger if exists return_logistics_events_append_only on public.return_logistics_events;
drop trigger if exists cod_collection_records_immutable on public.cod_collection_records;
drop trigger if exists ai_runs_immutable_core_trigger on public.ai_runs;
drop trigger if exists ai_tool_calls_immutable_core_trigger on public.ai_tool_calls;
drop trigger if exists ai_approvals_immutable_core_trigger on public.ai_approvals;
drop trigger if exists ai_policies_no_update_trigger on public.ai_policies;

-- Dynamic B2B quote and daily-rollup fixtures.
delete from public.wholesale_quote_items
where quote_version_id in (
  select v.id from public.wholesale_quote_versions v
  join public.wholesale_quotes q on q.id = v.quote_id
  where q.shop_id = '50000000-0000-0000-0000-000000000001'
);
delete from public.wholesale_quote_versions
where quote_id in (select id from public.wholesale_quotes where shop_id = '50000000-0000-0000-0000-000000000001');
delete from public.wholesale_quotes where shop_id = '50000000-0000-0000-0000-000000000001';
delete from public.wholesale_requests where shop_id = '50000000-0000-0000-0000-000000000001';
delete from public.merchant_daily_rollups where shop_id = '50000000-0000-0000-0000-000000000001';

-- Dynamic COD collection and reconciliation fixtures.
delete from public.cod_collection_records
where merchant_order_id in (
  select id from public.merchant_orders
  where shop_id = '50000000-0000-0000-0000-000000000001'
);
delete from public.cod_reconciliation_batches where shop_id = '50000000-0000-0000-0000-000000000001';

-- Dynamic inventory commands and all location-scoped stock state.
delete from public.inventory_movements where shop_id = '50000000-0000-0000-0000-000000000001';
delete from public.inventory_transfer_items
where transfer_id in (select id from public.inventory_transfers where shop_id = '50000000-0000-0000-0000-000000000001');
delete from public.inventory_transfers where shop_id = '50000000-0000-0000-0000-000000000001';
delete from public.inventory_count_items
where count_id in (select id from public.inventory_counts where shop_id = '50000000-0000-0000-0000-000000000001');
delete from public.inventory_counts where shop_id = '50000000-0000-0000-0000-000000000001';
delete from public.inventory_reservations
where merchant_order_id in (select id from public.merchant_orders where shop_id = '50000000-0000-0000-0000-000000000001');
delete from public.product_location_inventory
where location_id in (select id from public.inventory_locations where shop_id = '50000000-0000-0000-0000-000000000001');
delete from public.inventory_locations where shop_id = '50000000-0000-0000-0000-000000000001';

-- Fixed and dynamic event/AI records. Event rows are immutable in normal use;
-- they are disposable synthetic fixtures here, and the triggers are restored below.
delete from public.return_logistics_events where return_logistics_id = 'aa000000-0000-0000-0000-000000000001';
delete from public.return_logistics where id = 'aa000000-0000-0000-0000-000000000001';
delete from public.delivery_exceptions where id = 'a9000000-0000-0000-0000-000000000001';
delete from public.shipment_events where shipment_plan_id = 'a7000000-0000-0000-0000-000000000001';
delete from public.shipment_plans where id = 'a7000000-0000-0000-0000-000000000001';
delete from public.ai_approvals where id = 'b2000000-0000-0000-0000-000000000001';
delete from public.ai_tool_calls where id = 'b1000000-0000-0000-0000-000000000001';
delete from public.ai_runs where id = 'b0000000-0000-0000-0000-000000000001';
delete from public.ai_policies where id = 'b3000000-0000-0000-0000-000000000001';

-- Leaf records for the fixed commerce graph and dedicated B2B/COD orders.
delete from public.payment_proofs where payment_claim_id in ('a2000000-0000-0000-0000-000000000001', 'a2000000-0000-0000-0000-000000000002');
delete from public.payment_claims where merchant_order_id in ('a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002', 'b5000000-0000-0000-0000-000000000001', 'b8000000-0000-0000-0000-000000000001');
delete from public.order_status_history where merchant_order_id in ('a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002', 'b5000000-0000-0000-0000-000000000001', 'b8000000-0000-0000-0000-000000000001');
delete from public.order_cases where id = 'a4000000-0000-0000-0000-000000000001';
delete from public.merchant_order_items where merchant_order_id in ('a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002', 'b5000000-0000-0000-0000-000000000001', 'b8000000-0000-0000-0000-000000000001');
delete from public.merchant_orders where id in ('a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002', 'b5000000-0000-0000-0000-000000000001', 'b8000000-0000-0000-0000-000000000001');
delete from public.checkout_sessions where id in ('90000000-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000002', 'b4000000-0000-0000-0000-000000000001', 'b7000000-0000-0000-0000-000000000001');
delete from public.cart_items where id = '80000000-0000-0000-0000-000000000002';
delete from public.carts where id = '80000000-0000-0000-0000-000000000001';
delete from public.customer_addresses where id = 'ac000000-0000-0000-0000-000000000001';
delete from public.merchant_delivery_zones where id = 'ad000000-0000-0000-0000-000000000001';
delete from public.shop_fulfilment_methods where shop_id = '50000000-0000-0000-0000-000000000001';
delete from public.payment_methods where id = '70000000-0000-0000-0000-000000000001';

delete from public.reports where id = 'af000000-0000-0000-0000-000000000001';
delete from public.identity_evidence where identity_case_id = 'ae000000-0000-0000-0000-000000000001';
delete from public.identity_verification_cases where id = 'ae000000-0000-0000-0000-000000000001';
delete from public.channel_listings where id = 'a6000000-0000-0000-0000-000000000001';
delete from public.commerce_channels where id = 'a5000000-0000-0000-0000-000000000001';
delete from public.products where id in ('60000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000003');
delete from public.categories where id = '60000000-0000-0000-0000-000000000001';
delete from public.shops where id = '50000000-0000-0000-0000-000000000001';
delete from public.merchants where id = '40000000-0000-0000-0000-000000000001';
delete from public.pickup_points where id = '30000000-0000-0000-0000-000000000002';
delete from public.market_service_areas where id = '30000000-0000-0000-0000-000000000001';

-- Remove synthetic operational/audit rows created by the fixed seed and RPC tests.
delete from public.audit_events
where actor_user_id in (
  select id from public.profiles
  where email like '%.auth.debug@mock.yemencommerce.dev'
     or email like '%.debug@example.invalid'
)
   or resource_type = 'debug_fixture'
   or action like 'debug.%';

delete from public.business_profiles
where user_id in (
  select id from public.profiles
  where email like '%.auth.debug@mock.yemencommerce.dev'
);
delete from public.user_capabilities
where user_id in (
  select id from public.profiles
  where email like '%.auth.debug@mock.yemencommerce.dev'
     or email like '%.debug@example.invalid'
);
delete from public.creator_operator_assignments
where user_id in (
  select id from public.profiles
  where email like '%.auth.debug@mock.yemencommerce.dev'
     or email like '%.debug@example.invalid'
)
   or granted_by_user_id in (
  select id from public.profiles
  where email like '%.auth.debug@mock.yemencommerce.dev'
     or email like '%.debug@example.invalid'
);
delete from public.user_roles
where user_id in (
  select id from public.profiles
  where email like '%.auth.debug@mock.yemencommerce.dev'
     or email like '%.debug@example.invalid'
);
delete from public.user_access_controls
where user_id in (
  select id from public.profiles
  where email like '%.auth.debug@mock.yemencommerce.dev'
     or email like '%.debug@example.invalid'
);

-- Delete only the six exact supported debug accounts and the six legacy fixed IDs.
delete from auth.users
where email in (
  'creator.auth.debug@mock.yemencommerce.dev',
  'merchant.auth.debug@mock.yemencommerce.dev',
  'customer.auth.debug@mock.yemencommerce.dev',
  'customer2.auth.debug@mock.yemencommerce.dev',
  'reviewer.auth.debug@mock.yemencommerce.dev',
  'support.auth.debug@mock.yemencommerce.dev',
  'creator.debug@example.invalid',
  'merchant.debug@example.invalid',
  'customer.debug@example.invalid',
  'customer2.debug@example.invalid',
  'reviewer.debug@example.invalid',
  'support.debug@example.invalid'
);

-- Restore immutable protections exactly as defined by the migrations.
create trigger shipment_events_append_only
before update or delete on public.shipment_events
for each row execute function private.commerce_event_append_only();
create trigger return_logistics_events_append_only
before update or delete on public.return_logistics_events
for each row execute function private.commerce_event_append_only();
create trigger cod_collection_records_immutable
before update or delete on public.cod_collection_records
for each row execute function private.prevent_cod_record_mutation();
create trigger ai_runs_immutable_core_trigger
before update on public.ai_runs for each row execute function private.ai_runs_immutable_core();
create trigger ai_tool_calls_immutable_core_trigger
before update on public.ai_tool_calls for each row execute function private.ai_tool_calls_immutable_core();
create trigger ai_approvals_immutable_core_trigger
before update on public.ai_approvals for each row execute function private.ai_approvals_immutable_core();
create trigger ai_policies_no_update_trigger
before update or delete on public.ai_policies for each row execute function private.ai_policies_append_only();

commit;
