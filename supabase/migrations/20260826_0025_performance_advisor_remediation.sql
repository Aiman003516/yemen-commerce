-- Performance Advisor remediation for legacy FK coverage and policy
-- consolidation. This does not change business visibility semantics.

create index if not exists advisor_fk_cart_items_product_id_idx on public.cart_items(product_id); -- cart_items_product_id_fkey
create index if not exists advisor_fk_carts_market_id_idx on public.carts(market_id); -- carts_market_id_fkey
create index if not exists advisor_fk_checkout_sessions_customer_user_id_idx on public.checkout_sessions(customer_user_id); -- checkout_sessions_customer_user_id_fkey
create index if not exists advisor_fk_checkout_sessions_market_id_idx on public.checkout_sessions(market_id); -- checkout_sessions_market_id_fkey
create index if not exists advisor_fk_cod_collection_records_recorded_by_user_id_idx on public.cod_collection_records(recorded_by_user_id); -- cod_collection_records_recorded_by_user_id_fkey
create index if not exists advisor_fk_courier_dispatch_events_actor_user_id_idx on public.courier_dispatch_events(actor_user_id); -- courier_dispatch_events_actor_user_id_fkey
create index if not exists advisor_fk_courier_dispatch_events_courier_user_id_idx on public.courier_dispatch_events(courier_user_id); -- courier_dispatch_events_courier_user_id_fkey
create index if not exists advisor_fk_courier_dispatch_events_merchant_order_id_idx on public.courier_dispatch_events(merchant_order_id); -- courier_dispatch_events_merchant_order_id_fkey
create index if not exists advisor_fk_creator_operator_assignments_granted_by_user_id_idx on public.creator_operator_assignments(granted_by_user_id); -- creator_operator_assignments_granted_by_user_id_fkey
create index if not exists advisor_fk_creator_operator_assignments_revoked_by_user_id_idx on public.creator_operator_assignments(revoked_by_user_id); -- creator_operator_assignments_revoked_by_user_id_fkey
create index if not exists advisor_fk_customer_addresses_market_id_idx on public.customer_addresses(market_id); -- customer_addresses_market_id_fkey
create index if not exists advisor_fk_customer_addresses_service_area_id_idx on public.customer_addresses(service_area_id); -- customer_addresses_service_area_id_fkey
create index if not exists advisor_fk_customer_loyalty_accounts_market_id_idx on public.customer_loyalty_accounts(market_id); -- customer_loyalty_accounts_market_id_fkey
create index if not exists advisor_fk_identity_verification_cases_reviewed_by_user_id_idx on public.identity_verification_cases(reviewed_by_user_id); -- identity_verification_cases_reviewed_by_user_id_fkey
create index if not exists advisor_fk_identity_verification_cases_submitted_by_user_id_idx on public.identity_verification_cases(submitted_by_user_id); -- identity_verification_cases_submitted_by_user_id_fkey
create index if not exists advisor_fk_inventory_reservations_product_id_idx on public.inventory_reservations(product_id); -- inventory_reservations_product_id_fkey
create index if not exists advisor_fk_loyalty_ledger_created_by_user_id_idx on public.loyalty_ledger(created_by_user_id); -- loyalty_ledger_created_by_user_id_fkey
create index if not exists advisor_fk_loyalty_ledger_customer_user_id_idx on public.loyalty_ledger(customer_user_id); -- loyalty_ledger_customer_user_id_fkey
create index if not exists advisor_fk_loyalty_ledger_merchant_order_id_idx on public.loyalty_ledger(merchant_order_id); -- loyalty_ledger_merchant_order_id_fkey
create index if not exists advisor_fk_market_capabilities_capability_id_idx on public.market_capabilities(capability_id); -- market_capabilities_capability_id_fkey
create index if not exists advisor_fk_market_feature_rollouts_updated_by_user_id_idx on public.market_feature_rollouts(updated_by_user_id); -- market_feature_rollouts_updated_by_user_id_fkey
create index if not exists advisor_fk_merchant_delivery_zones_service_area_id_idx on public.merchant_delivery_zones(service_area_id); -- merchant_delivery_zones_service_area_id_fkey
create index if not exists advisor_fk_merchant_integrations_provider_code_idx on public.merchant_integrations(provider_code); -- merchant_integrations_provider_code_fkey
create index if not exists advisor_fk_merchant_order_items_product_id_idx on public.merchant_order_items(product_id); -- merchant_order_items_product_id_fkey
create index if not exists advisor_fk_merchant_orders_delivery_service_area_id_idx on public.merchant_orders(delivery_service_area_id); -- merchant_orders_delivery_service_area_id_fkey
create index if not exists advisor_fk_merchant_orders_delivery_zone_id_idx on public.merchant_orders(delivery_zone_id); -- merchant_orders_delivery_zone_id_fkey
create index if not exists advisor_fk_merchant_orders_market_id_idx on public.merchant_orders(market_id); -- merchant_orders_market_id_fkey
create index if not exists advisor_fk_merchant_orders_payment_method_id_idx on public.merchant_orders(payment_method_id); -- merchant_orders_payment_method_id_fkey
create index if not exists advisor_fk_merchant_orders_pickup_point_id_idx on public.merchant_orders(pickup_point_id); -- merchant_orders_pickup_point_id_fkey
create index if not exists advisor_fk_merchant_orders_promotion_id_idx on public.merchant_orders(promotion_id); -- merchant_orders_promotion_id_fkey
create index if not exists advisor_fk_merchant_orders_shop_id_idx on public.merchant_orders(shop_id); -- merchant_orders_shop_id_fkey
create index if not exists advisor_fk_merchant_promotions_merchant_id_idx on public.merchant_promotions(merchant_id); -- merchant_promotions_merchant_id_fkey
create index if not exists advisor_fk_merchant_quality_snapshots_computed_by_user_id_idx on public.merchant_quality_snapshots(computed_by_user_id); -- merchant_quality_snapshots_computed_by_user_id_fkey
create index if not exists advisor_fk_order_cases_reviewed_by_user_id_idx on public.order_cases(reviewed_by_user_id); -- order_cases_reviewed_by_user_id_fkey
create index if not exists advisor_fk_order_courier_assignments_assigned_by_user_id_idx on public.order_courier_assignments(assigned_by_user_id); -- order_courier_assignments_assigned_by_user_id_fkey
create index if not exists advisor_fk_order_status_history_actor_user_id_idx on public.order_status_history(actor_user_id); -- order_status_history_actor_user_id_fkey
create index if not exists advisor_fk_payment_claims_customer_user_id_idx on public.payment_claims(customer_user_id); -- payment_claims_customer_user_id_fkey
create index if not exists advisor_fk_payment_claims_reviewed_by_user_id_idx on public.payment_claims(reviewed_by_user_id); -- payment_claims_reviewed_by_user_id_fkey
create index if not exists advisor_fk_payment_proofs_payment_claim_id_idx on public.payment_proofs(payment_claim_id); -- payment_proofs_payment_claim_id_fkey
create index if not exists advisor_fk_pickup_points_service_area_id_idx on public.pickup_points(service_area_id); -- pickup_points_service_area_id_fkey
create index if not exists advisor_fk_pos_sales_recorded_by_user_id_idx on public.pos_sales(recorded_by_user_id); -- pos_sales_recorded_by_user_id_fkey
create index if not exists advisor_fk_pos_sessions_opened_by_user_id_idx on public.pos_sessions(opened_by_user_id); -- pos_sessions_opened_by_user_id_fkey
create index if not exists advisor_fk_product_reviews_customer_user_id_idx on public.product_reviews(customer_user_id); -- product_reviews_customer_user_id_fkey
create index if not exists advisor_fk_product_reviews_merchant_order_id_idx on public.product_reviews(merchant_order_id); -- product_reviews_merchant_order_id_fkey
create index if not exists advisor_fk_product_reviews_moderated_by_user_id_idx on public.product_reviews(moderated_by_user_id); -- product_reviews_moderated_by_user_id_fkey
create index if not exists advisor_fk_reports_merchant_order_id_idx on public.reports(merchant_order_id); -- reports_merchant_order_id_fkey
create index if not exists advisor_fk_reports_reporter_user_id_idx on public.reports(reporter_user_id); -- reports_reporter_user_id_fkey
create index if not exists advisor_fk_reports_shop_id_idx on public.reports(shop_id); -- reports_shop_id_fkey
create index if not exists advisor_fk_risk_signals_created_by_user_id_idx on public.risk_signals(created_by_user_id); -- risk_signals_created_by_user_id_fkey
create index if not exists advisor_fk_risk_signals_customer_user_id_idx on public.risk_signals(customer_user_id); -- risk_signals_customer_user_id_fkey
create index if not exists advisor_fk_risk_signals_merchant_order_id_idx on public.risk_signals(merchant_order_id); -- risk_signals_merchant_order_id_fkey
create index if not exists advisor_fk_risk_signals_resolved_by_user_id_idx on public.risk_signals(resolved_by_user_id); -- risk_signals_resolved_by_user_id_fkey
create index if not exists advisor_fk_support_tickets_assigned_to_user_id_idx on public.support_tickets(assigned_to_user_id); -- support_tickets_assigned_to_user_id_fkey
create index if not exists advisor_fk_support_tickets_merchant_order_id_idx on public.support_tickets(merchant_order_id); -- support_tickets_merchant_order_id_fkey
create index if not exists advisor_fk_support_tickets_opened_by_user_id_idx on public.support_tickets(opened_by_user_id); -- support_tickets_opened_by_user_id_fkey
create index if not exists advisor_fk_user_access_controls_suspended_by_user_id_idx on public.user_access_controls(suspended_by_user_id); -- user_access_controls_suspended_by_user_id_fkey
create index if not exists advisor_fk_user_capabilities_granted_by_user_id_idx on public.user_capabilities(granted_by_user_id); -- user_capabilities_granted_by_user_id_fkey
create index if not exists advisor_fk_user_roles_market_id_idx on public.user_roles(market_id); -- user_roles_market_id_fkey
create index if not exists advisor_fk_wholesale_price_list_items_variant_id_idx on public.wholesale_price_list_items(variant_id); -- wholesale_price_list_items_variant_id_fkey
create index if not exists advisor_fk_wholesale_price_lists_merchant_id_idx on public.wholesale_price_lists(merchant_id); -- wholesale_price_lists_merchant_id_fkey
create index if not exists advisor_fk_wholesale_requests_approved_price_list_id_idx on public.wholesale_requests(approved_price_list_id); -- wholesale_requests_price_list_fk
create index if not exists advisor_fk_wholesale_requests_business_profile_id_idx on public.wholesale_requests(business_profile_id); -- wholesale_requests_business_profile_id_fkey
create index if not exists advisor_fk_wholesale_requests_reviewed_by_user_id_idx on public.wholesale_requests(reviewed_by_user_id); -- wholesale_requests_reviewed_by_user_id_fkey


-- Consolidate role-specific read policies. This preserves the previous union
-- semantics while avoiding multiple permissive policies for one role/action.

drop policy if exists market_feature_rollouts_internal_read on public.market_feature_rollouts;
drop policy if exists market_feature_rollouts_public_read on public.market_feature_rollouts;
create policy market_feature_rollouts_anon_read on public.market_feature_rollouts
  for select to anon using (
    enabled and exists (
      select 1 from public.markets m
      where m.id = market_feature_rollouts.market_id and m.status = 'active'
    )
  );
create policy market_feature_rollouts_authenticated_read on public.market_feature_rollouts
  for select to authenticated using (
    (enabled and exists (
      select 1 from public.markets m
      where m.id = market_feature_rollouts.market_id and m.status = 'active'
    ))
    or private.is_admin()
    or private.current_user_is_creator()
    or private.current_user_has_capability('manage_capabilities', market_id)
  );

drop policy if exists merchant_delivery_zones_owner_read on public.merchant_delivery_zones;
drop policy if exists merchant_delivery_zones_public_read on public.merchant_delivery_zones;
create policy merchant_delivery_zones_anon_read on public.merchant_delivery_zones
  for select to anon using (
    is_active and exists (
      select 1
      from public.shops s join public.markets m on m.id = s.market_id
      where s.id = merchant_delivery_zones.shop_id
        and s.status = 'approved' and m.status = 'active'
    )
  );
create policy merchant_delivery_zones_authenticated_read on public.merchant_delivery_zones
  for select to authenticated using (
    (is_active and exists (
      select 1
      from public.shops s join public.markets m on m.id = s.market_id
      where s.id = merchant_delivery_zones.shop_id
        and s.status = 'approved' and m.status = 'active'
    ))
    or exists (
      select 1
      from public.shops s join public.merchants merchant on merchant.id = s.merchant_id
      where s.id = merchant_delivery_zones.shop_id
        and (merchant.owner_user_id = (select auth.uid()) or private.is_admin())
    )
  );

drop policy if exists merchant_promotions_owner_read on public.merchant_promotions;
drop policy if exists merchant_promotions_public_read on public.merchant_promotions;
create policy merchant_promotions_anon_read on public.merchant_promotions
  for select to anon using (
    status = 'active'
    and (starts_at is null or starts_at <= now())
    and (ends_at is null or ends_at > now())
    and (max_redemptions is null or redemption_count < max_redemptions)
    and exists (
      select 1
      from public.shops s join public.markets m on m.id = s.market_id
      where s.id = merchant_promotions.shop_id
        and s.status = 'approved' and m.status = 'active'
    )
  );
create policy merchant_promotions_authenticated_read on public.merchant_promotions
  for select to authenticated using (
    (status = 'active'
    and (starts_at is null or starts_at <= now())
    and (ends_at is null or ends_at > now())
    and (max_redemptions is null or redemption_count < max_redemptions)
    and exists (
      select 1
      from public.shops s join public.markets m on m.id = s.market_id
      where s.id = merchant_promotions.shop_id
        and s.status = 'approved' and m.status = 'active'
    ))
    or merchant_id in (select private.current_merchant_ids())
    or private.is_admin()
  );

drop policy if exists product_reviews_customer_read on public.product_reviews;
drop policy if exists product_reviews_merchant_read on public.product_reviews;
drop policy if exists product_reviews_public_read on public.product_reviews;
create policy product_reviews_anon_read on public.product_reviews
  for select to anon using (
    status = 'published' and exists (
      select 1
      from public.products p
      join public.shops s on s.id = p.shop_id
      join public.markets m on m.id = s.market_id
      where p.id = product_reviews.product_id
        and p.status = 'active' and s.status = 'approved' and m.status = 'active'
    )
  );
create policy product_reviews_authenticated_read on public.product_reviews
  for select to authenticated using (
    (status = 'published' and exists (
      select 1
      from public.products p
      join public.shops s on s.id = p.shop_id
      join public.markets m on m.id = s.market_id
      where p.id = product_reviews.product_id
        and p.status = 'active' and s.status = 'approved' and m.status = 'active'
    ))
    or customer_user_id = (select auth.uid())
    or exists (
      select 1
      from public.products p join public.shops s on s.id = p.shop_id
      where p.id = product_reviews.product_id
        and (s.merchant_id in (select private.current_merchant_ids()) or private.is_admin())
    )
    or private.is_admin()
  );

drop policy if exists product_variants_owner_read on public.product_variants;
drop policy if exists product_variants_public_read on public.product_variants;
create policy product_variants_anon_read on public.product_variants
  for select to anon using (
    status = 'active' and exists (
      select 1
      from public.products p
      join public.shops s on s.id = p.shop_id
      join public.markets m on m.id = s.market_id
      where p.id = product_variants.product_id
        and p.status = 'active' and s.status = 'approved' and m.status = 'active'
    )
  );
create policy product_variants_authenticated_read on public.product_variants
  for select to authenticated using (
    (status = 'active' and exists (
      select 1
      from public.products p
      join public.shops s on s.id = p.shop_id
      join public.markets m on m.id = s.market_id
      where p.id = product_variants.product_id
        and p.status = 'active' and s.status = 'approved' and m.status = 'active'
    ))
    or exists (
      select 1
      from public.products p
      join public.shops s on s.id = p.shop_id
      join public.merchants merchant on merchant.id = s.merchant_id
      where p.id = product_variants.product_id
        and (merchant.owner_user_id = (select auth.uid()) or private.is_admin())
    )
  );

drop policy if exists products_owner_read on public.products;
drop policy if exists products_public_read on public.products;
create policy products_anon_read on public.products
  for select to anon using (
    status = 'active' and exists (
      select 1 from public.shops s
      where s.id = products.shop_id and s.status = 'approved'
    )
  );
create policy products_authenticated_read on public.products
  for select to authenticated using (
    (status = 'active' and exists (
      select 1 from public.shops s
      where s.id = products.shop_id and s.status = 'approved'
    ))
    or exists (
      select 1 from public.shops s
      where s.id = products.shop_id
        and (s.merchant_id in (select private.current_merchant_ids())
             or s.status = 'approved' or private.is_admin())
    )
  );

drop policy if exists shops_owner_read on public.shops;
drop policy if exists shops_public_read on public.shops;
create policy shops_anon_read on public.shops
  for select to anon using (
    status = 'approved' and exists (
      select 1 from public.markets m
      where m.id = shops.market_id and m.status = 'active'
    )
  );
create policy shops_authenticated_read on public.shops
  for select to authenticated using (
    (status = 'approved' and exists (
      select 1 from public.markets m
      where m.id = shops.market_id and m.status = 'active'
    ))
    or merchant_id in (select private.current_merchant_ids())
    or status = 'approved'
    or private.is_admin()
  );

drop policy if exists storefront_owner_read on public.storefront_settings;
drop policy if exists storefront_public_read on public.storefront_settings;
create policy storefront_anon_read on public.storefront_settings
  for select to anon using (
    is_published and exists (
      select 1
      from public.shops s join public.markets m on m.id = s.market_id
      where s.id = storefront_settings.shop_id
        and s.status = 'approved' and m.status = 'active'
    )
  );
create policy storefront_authenticated_read on public.storefront_settings
  for select to authenticated using (
    (is_published and exists (
      select 1
      from public.shops s join public.markets m on m.id = s.market_id
      where s.id = storefront_settings.shop_id
        and s.status = 'approved' and m.status = 'active'
    ))
    or exists (
      select 1
      from public.shops s join public.merchants merchant on merchant.id = s.merchant_id
      where s.id = storefront_settings.shop_id
        and (merchant.owner_user_id = (select auth.uid()) or private.is_admin())
    )
  );
