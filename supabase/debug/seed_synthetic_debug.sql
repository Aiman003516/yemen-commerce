-- Yemen Commerce disposable debug seed
--
-- RUN ONLY in the explicitly authorized Yemen Commerce mock/debug project through the SQL Editor.
-- This script creates the deterministic synthetic business graph only. It never writes
-- auth.users and never stores or hashes passwords. Create the six auto-confirmed debug
-- accounts through supported Supabase Auth UI/API first, then run this script.
-- The fixed business IDs make browser and RPC test instructions reproducible.

begin;

create temporary table debug_seed_ids (
  key text primary key,
  id uuid not null
) on commit drop;

do $$
declare v_count integer;
begin
  select count(*) into v_count
  from public.profiles
  where email in (
    'creator.auth.debug@mock.yemencommerce.dev',
    'merchant.auth.debug@mock.yemencommerce.dev',
    'customer.auth.debug@mock.yemencommerce.dev',
    'customer2.auth.debug@mock.yemencommerce.dev',
    'reviewer.auth.debug@mock.yemencommerce.dev',
    'support.auth.debug@mock.yemencommerce.dev'
  );
  if v_count <> 6 then
    raise exception using errcode = 'P0001', message = 'SUPPORTED_DEBUG_ACCOUNTS_INCOMPLETE';
  end if;
end $$;

insert into debug_seed_ids(key, id) values
  ('creator', (select id from public.profiles where email = 'creator.auth.debug@mock.yemencommerce.dev' limit 1)),
  ('merchant_user', (select id from public.profiles where email = 'merchant.auth.debug@mock.yemencommerce.dev' limit 1)),
  ('customer', (select id from public.profiles where email = 'customer.auth.debug@mock.yemencommerce.dev' limit 1)),
  ('customer_two', (select id from public.profiles where email = 'customer2.auth.debug@mock.yemencommerce.dev' limit 1)),
  ('reviewer', (select id from public.profiles where email = 'reviewer.auth.debug@mock.yemencommerce.dev' limit 1)),
  ('support', (select id from public.profiles where email = 'support.auth.debug@mock.yemencommerce.dev' limit 1)),
  ('market', '20000000-0000-0000-0000-000000000001'),
  ('service_area', '30000000-0000-0000-0000-000000000001'),
  ('pickup_point', '30000000-0000-0000-0000-000000000002'),
  ('merchant', '40000000-0000-0000-0000-000000000001'),
  ('shop', '50000000-0000-0000-0000-000000000001'),
  ('category', '60000000-0000-0000-0000-000000000001'),
  ('product_one', '60000000-0000-0000-0000-000000000002'),
  ('product_two', '60000000-0000-0000-0000-000000000003'),
  ('payment_method', '70000000-0000-0000-0000-000000000001'),
  ('cart', '80000000-0000-0000-0000-000000000001'),
  ('cart_item', '80000000-0000-0000-0000-000000000002'),
  ('checkout', '90000000-0000-0000-0000-000000000001'),
  ('checkout_two', '90000000-0000-0000-0000-000000000002'),
  ('order_paid', 'a0000000-0000-0000-0000-000000000001'),
  ('order_unpaid', 'a0000000-0000-0000-0000-000000000002'),
  ('item_paid', 'a1000000-0000-0000-0000-000000000001'),
  ('item_unpaid', 'a1000000-0000-0000-0000-000000000002'),
  ('claim_paid', 'a2000000-0000-0000-0000-000000000001'),
  ('claim_unpaid', 'a2000000-0000-0000-0000-000000000002'),
  ('history_paid', 'a3000000-0000-0000-0000-000000000001'),
  ('history_unpaid', 'a3000000-0000-0000-0000-000000000002'),
  ('return_case', 'a4000000-0000-0000-0000-000000000001'),
  ('channel', 'a5000000-0000-0000-0000-000000000001'),
  ('listing', 'a6000000-0000-0000-0000-000000000001'),
  ('shipment', 'a7000000-0000-0000-0000-000000000001'),
  ('shipment_event_one', 'a8000000-0000-0000-0000-000000000001'),
  ('shipment_event_two', 'a8000000-0000-0000-0000-000000000002'),
  ('delivery_exception', 'a9000000-0000-0000-0000-000000000001'),
  ('return_logistics', 'aa000000-0000-0000-0000-000000000001'),
  ('return_event', 'ab000000-0000-0000-0000-000000000001'),
  ('customer_address', 'ac000000-0000-0000-0000-000000000001'),
  ('delivery_zone', 'ad000000-0000-0000-0000-000000000001'),
  ('identity_case', 'ae000000-0000-0000-0000-000000000001'),
  ('report', 'af000000-0000-0000-0000-000000000001'),
  ('ai_run', 'b0000000-0000-0000-0000-000000000001'),
  ('ai_tool_call', 'b1000000-0000-0000-0000-000000000001'),
  ('ai_approval', 'b2000000-0000-0000-0000-000000000001'),
  ('ai_policy', 'b3000000-0000-0000-0000-000000000001');

insert into public.markets(id, governorate, city, district, service_area, status, currency, is_pilot)
values ((select id from debug_seed_ids where key = 'market'), 'إب', 'إب', 'الظهار', 'debug-yemen', 'active', 'YER', true)
on conflict (id) do update set status = 'active', is_pilot = true;

insert into public.user_access_controls(user_id, account_status)
select id, 'active' from debug_seed_ids
where key in ('creator','merchant_user','customer','customer_two','reviewer','support')
on conflict (user_id) do update set account_status = 'active', updated_at = now();

insert into public.user_roles(user_id, role, market_id)
values
  ((select id from debug_seed_ids where key = 'creator'), 'creator', null),
  ((select id from debug_seed_ids where key = 'merchant_user'), 'merchant', (select id from debug_seed_ids where key = 'market')),
  ((select id from debug_seed_ids where key = 'reviewer'), 'review_agent', (select id from debug_seed_ids where key = 'market')),
  ((select id from debug_seed_ids where key = 'support'), 'support_agent', (select id from debug_seed_ids where key = 'market'))
on conflict do nothing;

insert into public.creator_operator_assignments(user_id, role, market_id, granted_by_user_id, reason)
values
  ((select id from debug_seed_ids where key = 'reviewer'), 'review_agent', (select id from debug_seed_ids where key = 'market'), (select id from debug_seed_ids where key = 'creator'), 'بيانات مراجعة تجريبية معزولة'),
  ((select id from debug_seed_ids where key = 'support'), 'support_agent', (select id from debug_seed_ids where key = 'market'), (select id from debug_seed_ids where key = 'creator'), 'بيانات دعم تجريبية معزولة')
on conflict do nothing;

insert into public.markets(id, governorate, city, district, service_area, status, currency, is_pilot)
values ((select id from debug_seed_ids where key = 'market'), 'إب', 'إب', 'الظهار', 'debug-yemen', 'active', 'YER', true)
on conflict (id) do update set status = 'active', is_pilot = true;

insert into public.market_service_areas(id, market_id, name_ar, name_en, area_code, status, delivery_enabled, pickup_enabled)
values ((select id from debug_seed_ids where key = 'service_area'), (select id from debug_seed_ids where key = 'market'), 'منطقة إب التجريبية', 'Ibb Debug Area', 'debug-ibb', 'active', true, true)
on conflict (id) do nothing;

insert into public.pickup_points(id, market_id, service_area_id, name_ar, name_en, address_details, contact_phone, operating_hours, status)
values ((select id from debug_seed_ids where key = 'pickup_point'), (select id from debug_seed_ids where key = 'market'), (select id from debug_seed_ids where key = 'service_area'), 'نقطة استلام إب التجريبية', 'Ibb Debug Pickup', 'بجوار السوق التجريبي', '+967700000010', '09:00-17:00', 'active')
on conflict (id) do nothing;

insert into public.merchants(id, owner_user_id, market_id, phone, phone_verification_status, phone_verified_at, owner_name, verification_status)
values ((select id from debug_seed_ids where key = 'merchant'), (select id from debug_seed_ids where key = 'merchant_user'), (select id from debug_seed_ids where key = 'market'), '+967700000002', 'verified', now(), 'تاجر إب التجريبي', 'verified')
on conflict (id) do update set verification_status = 'verified', phone_verification_status = 'verified';

insert into public.shops(id, merchant_id, market_id, name, slug, description, area_label, accent_color, contact_route, collection_instructions, status)
values ((select id from debug_seed_ids where key = 'shop'), (select id from debug_seed_ids where key = 'merchant'), (select id from debug_seed_ids where key = 'market'), 'متجر إب التجريبي', 'ibb-debug-shop', 'متجر تجريبي لاختبار الواجهة العربية ومسارات الطلب.', 'إب - الظهار', '#006A63', 'whatsapp_placeholder', 'أبرز رمز الطلب عند الاستلام.', 'approved')
on conflict (id) do update set status = 'approved';

insert into public.categories(id, market_id, name_ar, name_en, slug, is_active)
values ((select id from debug_seed_ids where key = 'category'), (select id from debug_seed_ids where key = 'market'), 'منتجات تجريبية', 'Debug Products', 'debug-products', true)
on conflict (id) do nothing;

insert into public.products(id, shop_id, category_id, name, description, price_minor, currency, stock_quantity, status)
values
  ((select id from debug_seed_ids where key = 'product_one'), (select id from debug_seed_ids where key = 'shop'), (select id from debug_seed_ids where key = 'category'), 'سلة قهوة إب التجريبية', 'منتج تجريبي لاختبار البحث والسلة والطلب.', 12500, 'YER', 40, 'active'),
  ((select id from debug_seed_ids where key = 'product_two'), (select id from debug_seed_ids where key = 'shop'), (select id from debug_seed_ids where key = 'category'), 'عسل يمني تجريبي', 'منتج تجريبي ثان لاختبار الكتالوج.', 18000, 'YER', 18, 'active')
on conflict (id) do update set stock_quantity = excluded.stock_quantity, status = 'active';

insert into public.shop_fulfilment_methods(shop_id, method, instructions, is_active)
values
  ((select id from debug_seed_ids where key = 'shop'), 'collection', 'الاستلام من نقطة إب التجريبية.', true),
  ((select id from debug_seed_ids where key = 'shop'), 'seller_arranged', 'يتواصل المتجر مع العميل لتنسيق التوصيل.', true)
on conflict (shop_id, method) do update set is_active = true;

insert into public.payment_methods(id, merchant_id, name, mode, account_holder_name, receiving_identifier, currency, exact_amount_required, customer_instructions, proof_requirement, provider_verification, is_active)
values ((select id from debug_seed_ids where key = 'payment_method'), (select id from debug_seed_ids where key = 'merchant'), 'تحويل يدوي تجريبي', 'manual', 'تاجر إب التجريبي', 'DEBUG-ACCOUNT-NOT-REAL', 'YER', true, 'هذه وسيلة دفع يدوية تجريبية. أرسل المرجع فقط للاختبار؛ لا توجد أموال حقيقية.', 'reference', 'manual_only', true)
on conflict (id) do update set is_active = true;

insert into public.merchant_delivery_zones(id, shop_id, service_area_id, name, fee_minor, currency, eta_min_minutes, eta_max_minutes, instructions, is_active)
values ((select id from debug_seed_ids where key = 'delivery_zone'), (select id from debug_seed_ids where key = 'shop'), (select id from debug_seed_ids where key = 'service_area'), 'منطقة إب التجريبية', 1500, 'YER', 30, 120, 'زمن تجريبي فقط ولا يمثل وعداً فعلياً.', true)
on conflict (id) do nothing;

insert into public.customer_addresses(id, customer_user_id, market_id, service_area_id, label, recipient_name, phone, address_line, landmark, city, district, is_default, is_active)
values ((select id from debug_seed_ids where key = 'customer_address'), (select id from debug_seed_ids where key = 'customer'), (select id from debug_seed_ids where key = 'market'), (select id from debug_seed_ids where key = 'service_area'), 'المنزل التجريبي', 'عميل إب التجريبي', '+967700000003', 'عنوان تجريبي داخل منطقة الخدمة', 'بجوار النقطة التجريبية', 'إب', 'الظهار', true, true)
on conflict (id) do nothing;

insert into public.carts(id, customer_user_id, market_id)
values ((select id from debug_seed_ids where key = 'cart'), (select id from debug_seed_ids where key = 'customer'), (select id from debug_seed_ids where key = 'market'))
on conflict (id) do nothing;
insert into public.cart_items(id, cart_id, product_id, quantity)
values ((select id from debug_seed_ids where key = 'cart_item'), (select id from debug_seed_ids where key = 'cart'), (select id from debug_seed_ids where key = 'product_one'), 2)
on conflict (id) do update set quantity = 2;

insert into public.checkout_sessions(id, customer_user_id, market_id, status)
values
  ((select id from debug_seed_ids where key = 'checkout'), (select id from debug_seed_ids where key = 'customer'), (select id from debug_seed_ids where key = 'market'), 'completed'),
  ((select id from debug_seed_ids where key = 'checkout_two'), (select id from debug_seed_ids where key = 'customer_two'), (select id from debug_seed_ids where key = 'market'), 'completed')
on conflict (id) do nothing;

insert into public.merchant_orders(
  id, checkout_session_id, merchant_id, shop_id, customer_user_id, market_id,
  order_reference, currency, subtotal_minor, fee_minor, tax_minor, total_minor,
  payment_method_name, payment_method_id, account_holder_name, receiving_identifier,
  payment_instructions, proof_requirement, payment_status, fulfilment_method,
  fulfilment_instructions, fulfilment_status, delivery_address_snapshot,
  pickup_point_id, delivery_zone_id, delivery_fee_minor
)
values
  ((select id from debug_seed_ids where key = 'order_paid'), (select id from debug_seed_ids where key = 'checkout'), (select id from debug_seed_ids where key = 'merchant'), (select id from debug_seed_ids where key = 'shop'), (select id from debug_seed_ids where key = 'customer'), (select id from debug_seed_ids where key = 'market'), 'DEBUG-PAID-0001', 'YER', 25000, 0, 0, 26500, 'تحويل يدوي تجريبي', (select id from debug_seed_ids where key = 'payment_method'), 'تاجر إب التجريبي', 'DEBUG-ACCOUNT-NOT-REAL', 'بيانات دفع يدوية تجريبية فقط.', 'reference', 'paid', 'seller_arranged', 'توصيل تجريبي داخل منطقة الخدمة.', 'arranged', jsonb_build_object('recipient_name', 'عميل إب التجريبي', 'city', 'إب', 'district', 'الظهار'), null, (select id from debug_seed_ids where key = 'delivery_zone'), 1500),
    ((select id from debug_seed_ids where key = 'order_unpaid'), (select id from debug_seed_ids where key = 'checkout_two'),
 (select id from debug_seed_ids where key = 'merchant'), (select id from debug_seed_ids where key = 'shop'), (select id from debug_seed_ids where key = 'customer_two'), (select id from debug_seed_ids where key = 'market'), 'DEBUG-UNPAID-0001', 'YER', 18000, 0, 0, 18000, 'تحويل يدوي تجريبي', (select id from debug_seed_ids where key = 'payment_method'), 'تاجر إب التجريبي', 'DEBUG-ACCOUNT-NOT-REAL', 'بيانات دفع يدوية تجريبية فقط.', 'reference', 'payment_under_review', 'seller_arranged', 'لا يبدأ التوصيل قبل تأكيد الدفع.', 'pending', '{}'::jsonb, null, null, 0)
on conflict (id) do update set payment_status = excluded.payment_status, fulfilment_status = excluded.fulfilment_status;

insert into public.merchant_order_items(id, merchant_order_id, product_id, product_name, unit_price_minor, quantity, line_total_minor)
values
  ((select id from debug_seed_ids where key = 'item_paid'), (select id from debug_seed_ids where key = 'order_paid'), (select id from debug_seed_ids where key = 'product_one'), 'سلة قهوة إب التجريبية', 12500, 2, 25000),
  ((select id from debug_seed_ids where key = 'item_unpaid'), (select id from debug_seed_ids where key = 'order_unpaid'), (select id from debug_seed_ids where key = 'product_two'), 'عسل يمني تجريبي', 18000, 1, 18000)
on conflict (id) do nothing;

insert into public.payment_claims(id, merchant_order_id, customer_user_id, transaction_reference, review_note, reviewed_by_user_id, reviewed_at)
values
  ((select id from debug_seed_ids where key = 'claim_paid'), (select id from debug_seed_ids where key = 'order_paid'), (select id from debug_seed_ids where key = 'customer'), 'DEBUG-REF-PAID', 'تمت مراجعة المطالبة التجريبية فقط.', (select id from debug_seed_ids where key = 'merchant_user'), now()),
  ((select id from debug_seed_ids where key = 'claim_unpaid'), (select id from debug_seed_ids where key = 'order_unpaid'), (select id from debug_seed_ids where key = 'customer_two'), 'DEBUG-REF-PENDING', 'المطالبة التجريبية بانتظار المراجعة.', null, null)
on conflict (id) do nothing;

insert into public.order_status_history(id, merchant_order_id, actor_user_id, event_type, previous_value, next_value, reason)
values
  ((select id from debug_seed_ids where key = 'history_paid'), (select id from debug_seed_ids where key = 'order_paid'), (select id from debug_seed_ids where key = 'merchant_user'), 'debug_seed', 'payment_under_review', 'paid', 'سجل تجريبي معزول'),
  ((select id from debug_seed_ids where key = 'history_unpaid'), (select id from debug_seed_ids where key = 'order_unpaid'), (select id from debug_seed_ids where key = 'customer_two'), 'debug_seed', 'awaiting_payment', 'payment_under_review', 'سجل تجريبي معزول')
on conflict (id) do nothing;

insert into public.order_cases(id, merchant_order_id, opened_by_user_id, case_type, status, reason, requested_quantity, reviewed_by_user_id, reviewed_at, resolution_note)
values ((select id from debug_seed_ids where key = 'return_case'), (select id from debug_seed_ids where key = 'order_paid'), (select id from debug_seed_ids where key = 'customer'), 'return', 'approved', 'المنتج التجريبي يحتاج إلى إرجاع للاختبار.', 1, (select id from debug_seed_ids where key = 'merchant_user'), now(), 'تمت الموافقة على حالة الإرجاع التجريبية.')
on conflict (id) do nothing;

insert into public.commerce_channels(id, shop_id, channel_key, display_name, channel_kind, status, public_slug, public_config)
values ((select id from debug_seed_ids where key = 'channel'), (select id from debug_seed_ids where key = 'shop'), 'debug_web', 'قناة الويب التجريبية', 'web', 'active', 'ibb-debug-channel', '{}'::jsonb)
on conflict (id) do update set status = 'active';
insert into public.channel_listings(id, channel_id, product_id, listing_status, channel_title, channel_description, price_override_minor, currency_override)
values ((select id from debug_seed_ids where key = 'listing'), (select id from debug_seed_ids where key = 'channel'), (select id from debug_seed_ids where key = 'product_one'), 'active', 'سلة قهوة إب', 'وصف قناة تجريبية.', null, null)
on conflict (id) do nothing;

insert into public.shipment_plans(id, merchant_order_id, carrier_key, service_level, status, dispatch_eligible, tracking_reference, customer_message, created_by_user_id)
values ((select id from debug_seed_ids where key = 'shipment'), (select id from debug_seed_ids where key = 'order_paid'), 'merchant_arranged', 'debug_standard', 'in_transit', true, 'DEBUG-TRACK-0001', 'تم تجهيز الشحنة التجريبية للتوصيل.', (select id from debug_seed_ids where key = 'merchant_user'))
on conflict (id) do update set status = 'in_transit', dispatch_eligible = true;
insert into public.shipment_events(id, shipment_plan_id, status, customer_message, recorded_by_user_id)
values
  ((select id from debug_seed_ids where key = 'shipment_event_one'), (select id from debug_seed_ids where key = 'shipment'), 'ready', 'الشحنة التجريبية جاهزة.', (select id from debug_seed_ids where key = 'merchant_user')),
  ((select id from debug_seed_ids where key = 'shipment_event_two'), (select id from debug_seed_ids where key = 'shipment'), 'in_transit', 'الشحنة التجريبية في الطريق.', (select id from debug_seed_ids where key = 'merchant_user'))
on conflict (id) do nothing;

insert into public.delivery_exceptions(id, shipment_plan_id, code, severity, status, customer_message, opened_by_user_id)
values ((select id from debug_seed_ids where key = 'delivery_exception'), (select id from debug_seed_ids where key = 'shipment'), 'debug_delay', 'medium', 'open', 'تأخير تجريبي للاختبار فقط.', (select id from debug_seed_ids where key = 'merchant_user'))
on conflict (id) do update set status = 'open';

insert into public.return_logistics(id, order_case_id, method, status, provider_key, external_reference, customer_message, created_by_user_id)
values ((select id from debug_seed_ids where key = 'return_logistics'), (select id from debug_seed_ids where key = 'return_case'), 'pickup', 'awaiting_handoff', null, 'DEBUG-RETURN-0001', 'تم تسجيل مسار إرجاع تجريبي بانتظار التسليم.', (select id from debug_seed_ids where key = 'merchant_user'))
on conflict (id) do update set status = 'awaiting_handoff';
insert into public.return_logistics_events(id, return_logistics_id, status, customer_message, recorded_by_user_id)
values ((select id from debug_seed_ids where key = 'return_event'), (select id from debug_seed_ids where key = 'return_logistics'), 'awaiting_handoff', 'سجل إرجاع تجريبي.', (select id from debug_seed_ids where key = 'merchant_user'))
on conflict (id) do nothing;

insert into public.identity_verification_cases(id, merchant_id, submitted_by_user_id, consent_at, status, decision_note)
values ((select id from debug_seed_ids where key = 'identity_case'), (select id from debug_seed_ids where key = 'merchant'), (select id from debug_seed_ids where key = 'merchant_user'), now(), 'under_review', 'مراجعة هوية تجريبية؛ لا توجد مستندات حقيقية.')
on conflict (id) do update set status = 'under_review';

insert into public.reports(id, reporter_user_id, merchant_order_id, shop_id, category, description, status)
values ((select id from debug_seed_ids where key = 'report'), (select id from debug_seed_ids where key = 'customer'), (select id from debug_seed_ids where key = 'order_paid'), (select id from debug_seed_ids where key = 'shop'), 'delivery', 'بلاغ تجريبي لاختبار شاشة الدعم.', 'open')
on conflict (id) do update set status = 'open';

insert into public.ai_runs(id, actor_user_id, app_surface, actor_role, scope_type, scope_id, intent_key, request_hash, requested_locale, policy_key, policy_version, status, max_tool_calls, tool_call_count, idempotency_key, metadata, created_at, started_at, completed_at)
values ((select id from debug_seed_ids where key = 'ai_run'), (select id from debug_seed_ids where key = 'creator'), 'developer', 'creator', 'global', null, 'governance.readiness', repeat('a', 64), 'ar', 'default', 1, 'succeeded', 1, 1, 'debug-ai-run-0001', '{"synthetic":true,"prompt_stored":false}'::jsonb, now(), now(), now())
on conflict (id) do nothing;
insert into public.ai_tool_calls(id, run_id, sequence_no, tool_name, tool_version, action_class, status, arguments_hash, arguments_redacted, approval_required, policy_decision, result_summary, idempotency_key)
values ((select id from debug_seed_ids where key = 'ai_tool_call'), (select id from debug_seed_ids where key = 'ai_run'), 1, 'read_governance_readiness', '1', 'read', 'succeeded', repeat('b', 64), '{"synthetic":true}'::jsonb, false, 'allow', '{"status":"ready_for_review"}'::jsonb, 'debug-ai-tool-0001')
on conflict (id) do nothing;
insert into public.ai_approvals(id, run_id, tool_call_id, approver_user_id, tool_name, arguments_hash, approval_token_hash, status, decision_reason, created_at, expires_at)
values ((select id from debug_seed_ids where key = 'ai_approval'), (select id from debug_seed_ids where key = 'ai_run'), (select id from debug_seed_ids where key = 'ai_tool_call'), (select id from debug_seed_ids where key = 'creator'), 'read_governance_readiness', repeat('b', 64), repeat('c', 64), 'approved', 'موافقة تجريبية معزولة.', now(), now() + interval '1 day')
on conflict (id) do nothing;
insert into public.ai_policies(id, policy_key, app_surface, principal_role, tool_name, version, status, rules, source, created_by_user_id, reason, effective_at)
values ((select id from debug_seed_ids where key = 'ai_policy'), 'debug_read_only', 'developer', 'creator', 'read_governance_readiness', 1, 'active', '{"read_only":true,"synthetic":true}'::jsonb, 'creator', (select id from debug_seed_ids where key = 'creator'), 'سياسة قراءة تجريبية معزولة.', now())
on conflict (id) do nothing;

insert into public.audit_events(actor_user_id, action, resource_type, resource_id, metadata)
values
  ((select id from debug_seed_ids where key = 'creator'), 'debug.seed_created', 'debug_fixture', 'yemen-commerce-debug', '{"synthetic":true,"email_domain":"mock.yemencommerce.dev"}'::jsonb),
  ((select id from debug_seed_ids where key = 'merchant_user'), 'debug.paid_order_fixture_created', 'merchant_order', (select id::text from debug_seed_ids where key = 'order_paid'), '{"payment_status":"paid","no_real_funds":true}'::jsonb)
on conflict do nothing;

commit;

-- After this script succeeds, verify only non-sensitive fixture identifiers:
-- select id, order_reference, payment_status, fulfilment_status
-- from public.merchant_orders
-- where order_reference like 'DEBUG-%'
-- order by order_reference
-- limit 10;
