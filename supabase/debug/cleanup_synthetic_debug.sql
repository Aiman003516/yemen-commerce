-- Yemen Commerce disposable debug cleanup
-- RUN ONLY in the same isolated Supabase debug/test project as the seed.
-- This deletes only the fixed synthetic fixture graph and example.invalid users.

begin;

-- Leaf and append-only operational records first.
delete from public.return_logistics_events where id = 'ab000000-0000-0000-0000-000000000001';
delete from public.return_logistics where id = 'aa000000-0000-0000-0000-000000000001';
delete from public.delivery_exceptions where id = 'a9000000-0000-0000-0000-000000000001';
delete from public.shipment_events where id in ('a8000000-0000-0000-0000-000000000001', 'a8000000-0000-0000-0000-000000000002');
delete from public.shipment_plans where id = 'a7000000-0000-0000-0000-000000000001';
delete from public.channel_listings where id = 'a6000000-0000-0000-0000-000000000001';
delete from public.commerce_channels where id = 'a5000000-0000-0000-0000-000000000001';
delete from public.ai_approvals where id = 'b2000000-0000-0000-0000-000000000001';
delete from public.ai_tool_calls where id = 'b1000000-0000-0000-0000-000000000001';
delete from public.ai_runs where id = 'b0000000-0000-0000-0000-000000000001';
delete from public.ai_policies where id = 'b3000000-0000-0000-0000-000000000001';
delete from public.reports where id = 'af000000-0000-0000-0000-000000000001';
delete from public.identity_evidence where identity_case_id = 'ae000000-0000-0000-0000-000000000001';
delete from public.identity_verification_cases where id = 'ae000000-0000-0000-0000-000000000001';
delete from public.payment_proofs where payment_claim_id in ('a2000000-0000-0000-0000-000000000001', 'a2000000-0000-0000-0000-000000000002');
delete from public.payment_claims where id in ('a2000000-0000-0000-0000-000000000001', 'a2000000-0000-0000-0000-000000000002');
delete from public.order_status_history where id in ('a3000000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000002');
delete from public.order_cases where id = 'a4000000-0000-0000-0000-000000000001';
delete from public.merchant_order_items where id in ('a1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000002');
delete from public.merchant_orders where id in ('a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002');
delete from public.checkout_sessions where id in ('90000000-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000002');
delete from public.cart_items where id = '80000000-0000-0000-0000-000000000002';
delete from public.carts where id = '80000000-0000-0000-0000-000000000001';
delete from public.customer_addresses where id = 'ac000000-0000-0000-0000-000000000001';
delete from public.merchant_delivery_zones where id = 'ad000000-0000-0000-0000-000000000001';
delete from public.shop_fulfilment_methods where shop_id = '50000000-0000-0000-0000-000000000001';
delete from public.payment_methods where id = '70000000-0000-0000-0000-000000000001';
delete from public.products where id in ('60000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000003');
delete from public.categories where id = '60000000-0000-0000-0000-000000000001';
delete from public.shops where id = '50000000-0000-0000-0000-000000000001';
delete from public.merchants where id = '40000000-0000-0000-0000-000000000001';
delete from public.pickup_points where id = '30000000-0000-0000-0000-000000000002';
delete from public.market_service_areas where id = '30000000-0000-0000-0000-000000000001';
delete from public.user_capabilities where user_id in ('10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000005','10000000-0000-0000-0000-000000000006');
delete from public.creator_operator_assignments where user_id in ('10000000-0000-0000-0000-000000000005','10000000-0000-0000-0000-000000000006');
delete from public.user_roles where user_id in ('10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000005','10000000-0000-0000-0000-000000000006');
delete from public.user_access_controls where user_id in ('10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000005','10000000-0000-0000-0000-000000000006');
delete from public.audit_events where resource_type = 'debug_fixture' and resource_id = 'yemen-commerce-debug';
delete from public.markets where id = '20000000-0000-0000-0000-000000000001';

-- Auth deletion cascades the corresponding synthetic profiles.
delete from auth.users
where id in ('10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000005','10000000-0000-0000-0000-000000000006')
  and email like '%@example.invalid';

commit;
