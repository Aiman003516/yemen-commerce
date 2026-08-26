#!/usr/bin/env bash
set -euo pipefail

: "${SUPABASE_URL:?Set SUPABASE_URL}"
: "${SUPABASE_KEY:?Set SUPABASE_KEY to the publishable/anon key}"

base_url="${SUPABASE_URL%/}"
passed=0
skipped=0

pass() { printf 'PASS %s\n' "$1"; passed=$((passed + 1)); }
skip() { printf 'SKIP %s\n' "$1"; skipped=$((skipped + 1)); }

request_status() {
  local path="$1" token="${2:-$SUPABASE_KEY}" body="${3-}"
  if [[ -z "$body" ]]; then body='{}'; fi
  curl -sS -o /tmp/yemen_commerce_auth_test_response.json -w '%{http_code}' \
    -X POST "$base_url/rest/v1/rpc/$path" \
    -H "apikey: $SUPABASE_KEY" \
    -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' \
    --data "$body"
}

assert_anon_denied() {
  local function_name="$1" body="${2-}"
  if [[ -z "$body" ]]; then body='{}'; fi
  local status
  status="$(request_status "$function_name" "$SUPABASE_KEY" "$body")"
  if [[ "$status" == "401" ]]; then
    pass "anonymous denied: $function_name"
  else
    printf 'FAIL anonymous allowed/unexpected status: %s -> %s\n' "$function_name" "$status" >&2
    exit 1
  fi
}

assert_anon_denied creator_current_access
assert_anon_denied creator_dashboard_summary
assert_anon_denied creator_people_search
assert_anon_denied creator_set_user_role '{"p_user_id":"00000000-0000-0000-0000-000000000000","p_role":"review_agent","p_market_id":null,"p_expires_at":null,"p_reason":"test"}'
assert_anon_denied creator_revoke_user_role '{"p_user_id":"00000000-0000-0000-0000-000000000000","p_role":"review_agent","p_market_id":null,"p_reason":"test"}'
assert_anon_denied creator_set_account_status '{"p_user_id":"00000000-0000-0000-0000-000000000000","p_status":"suspended","p_until":null,"p_reason":"test"}'
assert_anon_denied creator_set_capability '{"p_user_id":"00000000-0000-0000-0000-000000000000","p_capability":"view_audit","p_market_id":null,"p_expires_at":null,"p_reason":"test"}'
assert_anon_denied creator_list_merchants
assert_anon_denied creator_set_merchant_verification '{"p_merchant_id":"00000000-0000-0000-0000-000000000000","p_status":"verified","p_reason":"test"}'
assert_anon_denied creator_list_shops
assert_anon_denied creator_set_shop_status '{"p_shop_id":"00000000-0000-0000-0000-000000000000","p_status":"approved","p_reason":"test"}'
assert_anon_denied creator_list_markets
assert_anon_denied creator_set_market_status '{"p_market_id":"00000000-0000-0000-0000-000000000000","p_status":"active","p_reason":"test"}'
assert_anon_denied creator_list_policies '{"p_market_id":"00000000-0000-0000-0000-000000000000"}'
assert_anon_denied creator_upsert_policy '{"p_market_id":"00000000-0000-0000-0000-000000000000","p_key":"test","p_value":{},"p_effective_from":null,"p_reason":"test"}'
assert_anon_denied creator_list_capabilities '{"p_market_id":"00000000-0000-0000-0000-000000000000"}'
assert_anon_denied creator_set_market_capability '{"p_market_id":"00000000-0000-0000-0000-000000000000","p_capability_id":"00000000-0000-0000-0000-000000000000","p_enabled":true,"p_reason":"test"}'
assert_anon_denied save_merchant_payment_method '{"p_id":null,"p_name":"Jaib","p_account_holder_name":"Test Merchant","p_receiving_identifier":"0000000000","p_instructions":"Use the Jaib QR or POS reference and submit the transaction reference.","p_proof_requirement":"reference","p_provider_code":"jaib","p_provider_metadata":{"payment_channel":"qr_or_pos","integration_mode":"manual","verification_state":"manual_only"}}'

assert_anon_denied save_customer_address '{"p_id":null,"p_market_id":"00000000-0000-0000-0000-000000000000","p_service_area_id":null,"p_label":"Home","p_recipient_name":"Test Customer","p_phone":"700000000","p_address_line":"Test address near the market","p_landmark":"Main landmark","p_city":"Ibb","p_district":null,"p_is_default":true}'
assert_anon_denied save_product_variant '{"p_id":null,"p_product_id":"00000000-0000-0000-0000-000000000000","p_name":"Default","p_sku":"TEST-DEFAULT","p_price_minor":100,"p_stock_quantity":1,"p_status":"draft"}'
assert_anon_denied open_order_case '{"p_merchant_order_id":"00000000-0000-0000-0000-000000000000","p_case_type":"dispute","p_reason":"Test dispute reason"}'
assert_anon_denied review_order_case '{"p_case_id":"00000000-0000-0000-0000-000000000000","p_decision":"rejected","p_resolution_note":"Test review","p_merchant_note":"Test note"}'
assert_anon_denied assign_order_courier '{"p_merchant_order_id":"00000000-0000-0000-0000-000000000000","p_courier_user_id":"00000000-0000-0000-0000-000000000000","p_delivery_note":"Test delivery"}'
assert_anon_denied record_courier_handoff '{"p_assignment_id":"00000000-0000-0000-0000-000000000000","p_status":"delivered","p_delivery_note":"Test handoff"}'
assert_anon_denied submit_product_review '{"p_product_id":"00000000-0000-0000-0000-000000000000","p_merchant_order_id":"00000000-0000-0000-0000-000000000000","p_rating":5,"p_comment":"Test review"}'
assert_anon_denied save_merchant_promotion '{"p_id":null,"p_shop_id":"00000000-0000-0000-0000-000000000000","p_code":"TEST10","p_kind":"percent","p_value_minor":10,"p_starts_at":null,"p_ends_at":null,"p_max_redemptions":10,"p_status":"draft"}'
assert_anon_denied mark_notification_read '{"p_notification_id":"00000000-0000-0000-0000-000000000000"}'
assert_anon_denied checkout_create_orders '{"p_market_id":"00000000-0000-0000-0000-000000000000","p_fulfilment_by_shop":[],"p_payment_by_merchant":[],"p_delivery_by_shop":[]}'
assert_anon_denied record_cod_collection '{"p_merchant_order_id":"00000000-0000-0000-0000-000000000000","p_collected_minor":0,"p_note":"test"}'
assert_anon_denied release_order_stock '{"p_merchant_order_id":"00000000-0000-0000-0000-000000000000","p_reason":"test"}'
assert_anon_denied finalize_order_stock '{"p_merchant_order_id":"00000000-0000-0000-0000-000000000000"}'
assert_anon_denied open_support_ticket '{"p_category":"order","p_subject":"Test support","p_description":"Test support description","p_priority":"normal","p_merchant_order_id":null}'
assert_anon_denied review_support_ticket '{"p_ticket_id":"00000000-0000-0000-0000-000000000000","p_status":"resolved","p_resolution_note":"Test resolution","p_assigned_to_user_id":null}'
assert_anon_denied review_risk_signal '{"p_signal_id":"00000000-0000-0000-0000-000000000000","p_decision":"dismissed","p_resolution_note":"Test resolution"}'
assert_anon_denied save_merchant_integration '{"p_shop_id":"00000000-0000-0000-0000-000000000000","p_provider_code":"whatsapp_business","p_status":"mock","p_configuration":{},"p_credential_reference":null,"p_webhook_endpoint_reference":null}'
assert_anon_denied creator_set_integration_status '{"p_integration_id":"00000000-0000-0000-0000-000000000000","p_status":"blocked","p_reason":"Test reason"}'
assert_anon_denied creator_set_feature_rollout '{"p_market_id":"00000000-0000-0000-0000-000000000000","p_feature_key":"test_feature","p_enabled":false,"p_configuration":{},"p_reason":"Test reason"}'
assert_anon_denied creator_save_service_area '{"p_id":null,"p_market_id":"00000000-0000-0000-0000-000000000000","p_name_ar":"منطقة اختبار","p_name_en":"Test Area","p_area_code":"TEST","p_status":"draft","p_delivery_enabled":true,"p_pickup_enabled":true,"p_reason":"Test reason"}'
assert_anon_denied creator_save_pickup_point '{"p_id":null,"p_market_id":"00000000-0000-0000-0000-000000000000","p_service_area_id":null,"p_name_ar":"نقطة اختبار","p_name_en":"Test Point","p_address_details":"Test pickup address","p_contact_phone":"700000000","p_operating_hours":"09:00-17:00","p_status":"draft","p_reason":"Test reason"}'
assert_anon_denied moderate_product_review '{"p_review_id":"00000000-0000-0000-0000-000000000000","p_status":"published","p_reason":"Test reason"}'
assert_anon_denied save_business_profile '{"p_business_name":"Test Business","p_contact_phone":"700000000","p_tax_identifier":null}'
assert_anon_denied open_wholesale_request '{"p_shop_id":"00000000-0000-0000-0000-000000000000","p_note":"Test wholesale request","p_estimated_monthly_minor":0}'
assert_anon_denied review_wholesale_request '{"p_request_id":"00000000-0000-0000-0000-000000000000","p_status":"rejected","p_review_note":"Test decision"}'
assert_anon_denied earn_loyalty_points '{"p_merchant_order_id":"00000000-0000-0000-0000-000000000000","p_points":10,"p_reason":"Test points"}'
assert_anon_denied open_pos_session '{"p_shop_id":"00000000-0000-0000-0000-000000000000","p_opening_note":"Test opening"}'
assert_anon_denied record_pos_sale '{"p_pos_session_id":"00000000-0000-0000-0000-000000000000","p_total_minor":100,"p_payment_mode":"mock","p_line_items":[],"p_note":"Test sale"}'
assert_anon_denied checkout_create_orders_idempotent '{"p_market_id":"00000000-0000-0000-0000-000000000000","p_fulfilment_by_shop":[],"p_payment_by_merchant":[],"p_delivery_by_shop":[],"p_command_key":"anonymous-test-command-key"}'
assert_anon_denied apply_order_promotion '{"p_merchant_order_id":"00000000-0000-0000-0000-000000000000","p_code":"TEST10"}'
assert_anon_denied apply_order_promotion '{"p_merchant_order_id":"00000000-0000-0000-0000-000000000000","p_code":"TEST10","p_command_key":"anonymous-promotion-command-key"}'
assert_anon_denied record_courier_dispatch_event '{"p_assignment_id":"00000000-0000-0000-0000-000000000000","p_event_type":"note","p_note":"Test dispatch note"}'
assert_anon_denied save_wholesale_price_list '{"p_id":null,"p_shop_id":"00000000-0000-0000-0000-000000000000","p_name_ar":"قائمة اختبار","p_currency":"YER","p_status":"draft","p_reason":"Test reason"}'
assert_anon_denied save_wholesale_price_list_item '{"p_id":null,"p_price_list_id":"00000000-0000-0000-0000-000000000000","p_product_id":"00000000-0000-0000-0000-000000000000","p_variant_id":null,"p_unit_price_minor":100,"p_min_quantity":1,"p_status":"active","p_reason":"Test reason"}'
assert_anon_denied list_merchant_wholesale_requests '{"p_shop_id":"00000000-0000-0000-0000-000000000000"}'
assert_anon_denied review_wholesale_request_with_price_list '{"p_request_id":"00000000-0000-0000-0000-000000000000","p_status":"approved","p_review_note":"Test approval","p_price_list_id":null}'
assert_anon_denied close_pos_session '{"p_pos_session_id":"00000000-0000-0000-0000-000000000000","p_counted_total_minor":0,"p_closing_note":"Test close"}'
assert_anon_denied merchant_b2b_analytics '{"p_shop_id":"00000000-0000-0000-0000-000000000000"}'
assert_anon_denied export_merchant_b2b '{"p_shop_id":"00000000-0000-0000-0000-000000000000","p_limit":1,"p_offset":0}'
assert_anon_denied merchant_pos_analytics '{"p_shop_id":"00000000-0000-0000-0000-000000000000","p_from":"2026-01-01T00:00:00Z","p_to":"2026-01-02T00:00:00Z"}'
assert_anon_denied merchant_order_workbench '{"p_shop_id":"00000000-0000-0000-0000-000000000000","p_fulfilment_status":null,"p_payment_status":null,"p_cod_status":null,"p_query":null,"p_limit":1,"p_offset":0}'
assert_anon_denied open_cod_reconciliation_batch '{"p_shop_id":"00000000-0000-0000-0000-000000000000","p_business_date":"2026-08-26","p_note":"test"}'
assert_anon_denied merchant_cod_reconciliation '{"p_shop_id":"00000000-0000-0000-0000-000000000000","p_business_date":"2026-08-26","p_limit":1,"p_offset":0}'
assert_anon_denied close_cod_reconciliation_batch '{"p_batch_id":"00000000-0000-0000-0000-000000000000","p_note":"test"}'
assert_anon_denied record_cod_collection '{"p_merchant_order_id":"00000000-0000-0000-0000-000000000000","p_collected_minor":0,"p_note":"test","p_reconciliation_batch_id":"00000000-0000-0000-0000-000000000000"}'
assert_anon_denied export_merchant_pos '{"p_shop_id":"00000000-0000-0000-0000-000000000000","p_from":"2026-01-01T00:00:00Z","p_to":"2026-01-02T00:00:00Z","p_limit":1,"p_offset":0}'
assert_anon_denied save_inventory_location '{"p_shop_id":"00000000-0000-0000-0000-000000000000","p_name":"Test Warehouse","p_area_label":"Ibb","p_status":"active","p_is_default":true}'
assert_anon_denied record_inventory_adjustment '{"p_shop_id":"00000000-0000-0000-0000-000000000000","p_product_id":"00000000-0000-0000-0000-000000000000","p_location_id":"00000000-0000-0000-0000-000000000000","p_quantity_delta":1,"p_reason":"Test adjustment","p_idempotency_key":"anonymous-inventory-adjust"}'
assert_anon_denied complete_inventory_transfer '{"p_shop_id":"00000000-0000-0000-0000-000000000000","p_from_location_id":"00000000-0000-0000-0000-000000000000","p_to_location_id":"00000000-0000-0000-0000-000000000001","p_items":[],"p_reason":"Test transfer","p_idempotency_key":"anonymous-inventory-transfer"}'
assert_anon_denied apply_inventory_count '{"p_shop_id":"00000000-0000-0000-0000-000000000000","p_location_id":"00000000-0000-0000-0000-000000000000","p_items":[],"p_reason":"Test count","p_idempotency_key":"anonymous-inventory-count"}'
assert_anon_denied bulk_save_products '{"p_shop_id":"00000000-0000-0000-0000-000000000000","p_rows":[],"p_idempotency_key":"anonymous-catalog-import","p_source_format":"csv"}'
assert_anon_denied save_product_with_barcode '{"p_id":null,"p_shop_id":"00000000-0000-0000-0000-000000000000","p_category_id":null,"p_name":"Test Product","p_description":"Test description","p_price_minor":100,"p_stock_quantity":1,"p_status":"draft","p_barcode":"123456789"}'
assert_anon_denied list_merchant_price_lists '{"p_shop_id":"00000000-0000-0000-0000-000000000000"}'
assert_anon_denied list_merchant_wholesale_quotes '{"p_shop_id":"00000000-0000-0000-0000-000000000000"}'
assert_anon_denied list_customer_wholesale_quotes '{}'
assert_anon_denied create_wholesale_quote_version '{"p_quote_id":null,"p_wholesale_request_id":null,"p_shop_id":"00000000-0000-0000-0000-000000000000","p_buyer_user_id":"00000000-0000-0000-0000-000000000000","p_currency":"YER","p_valid_until":null,"p_note":null,"p_items":[],"p_reason":"test"}'
assert_anon_denied accept_wholesale_quote_version '{"p_quote_version_id":"00000000-0000-0000-0000-000000000000"}'
assert_anon_denied apply_accepted_wholesale_quote '{"p_merchant_order_id":"00000000-0000-0000-0000-000000000000","p_quote_version_id":"00000000-0000-0000-0000-000000000000"}'
assert_anon_denied merchant_daily_rollups '{"p_shop_id":"00000000-0000-0000-0000-000000000000","p_from":"2026-08-01","p_to":"2026-08-26","p_limit":1,"p_offset":0}'
assert_anon_denied refresh_merchant_daily_rollup '{"p_shop_id":"00000000-0000-0000-0000-000000000000","p_business_date":"2026-08-26"}'
assert_anon_denied register_product_asset_variant '{"p_product_id":"00000000-0000-0000-0000-000000000000","p_source_storage_key":"anonymous/source","p_format":"jpeg","p_width":640,"p_height":480,"p_byte_size":100}'
assert_anon_denied complete_product_asset_variant '{"p_asset_variant_id":"00000000-0000-0000-0000-000000000000","p_optimized_storage_key":"anonymous/optimized.jpg"}'
assert_anon_denied provider_adapter_operations '{}'
assert_anon_denied ai_start_run '{"p_app_surface":"customer","p_scope_type":"customer","p_scope_id":"00000000-0000-0000-0000-000000000000","p_intent_key":"general","p_request_hash":"anonymous-request-hash-123456","p_requested_locale":"ar","p_idempotency_key":"anonymous-ai-run","p_metadata":{}}'
assert_anon_denied ai_propose_tool_call '{"p_run_id":"00000000-0000-0000-0000-000000000000","p_sequence_no":1,"p_tool_name":"catalog.search","p_action_class":"read","p_arguments_hash":"anonymous-arguments-hash-123456","p_arguments_redacted":{},"p_required_capability":null,"p_approval_required":false,"p_policy_decision":"allow","p_idempotency_key":"anonymous-ai-tool"}'
assert_anon_denied ai_request_approval '{"p_tool_call_id":"00000000-0000-0000-0000-000000000000","p_expires_in_seconds":900}'
assert_anon_denied ai_decide_approval '{"p_approval_id":"00000000-0000-0000-0000-000000000000","p_decision":"rejected","p_reason":"anonymous rejection"}'
assert_anon_denied ai_transition_tool_call '{"p_tool_call_id":"00000000-0000-0000-0000-000000000000","p_status":"failed","p_result_summary":{},"p_error_code":"anonymous"}'
assert_anon_denied ai_finish_run '{"p_run_id":"00000000-0000-0000-0000-000000000000","p_status":"failed","p_output_hash":null}'
assert_anon_denied ai_publish_policy '{"p_policy_key":"anonymous","p_app_surface":"customer","p_principal_role":"customer","p_tool_name":"*","p_version":null,"p_status":"draft","p_rules":{},"p_reason":"anonymous policy"}'
assert_anon_denied ai_list_effective_policies '{"p_app_surface":"customer"}'
assert_anon_denied ai_get_effective_policy '{"p_app_surface":"customer","p_tool_name":"*"}'
assert_anon_denied merchant_ai_catalog '{"p_shop_id":"00000000-0000-0000-0000-000000000000","p_query":null,"p_limit":1,"p_offset":0}'

assert_anon_denied ai_get_run '{"p_run_id":"00000000-0000-0000-0000-000000000000"}'
assert_anon_denied ai_list_run_tool_calls '{"p_run_id":"00000000-0000-0000-0000-000000000000"}'
assert_anon_denied ai_list_my_approvals '{"p_status":"pending"}'

for table in user_access_controls user_capabilities creator_operator_assignments; do
  status="$(curl -sS -o /tmp/yemen_commerce_auth_test_response.json -w '%{http_code}' "$base_url/rest/v1/$table?select=*&limit=1" -H "apikey: $SUPABASE_KEY" -H "Authorization: Bearer $SUPABASE_KEY")"
  if [[ "$status" == "401" ]]; then
    pass "anonymous table denied: $table"
  else
    printf 'FAIL anonymous table access: %s -> %s\n' "$table" "$status" >&2
    exit 1
  fi
done

run_authenticated_case() {
  local label="$1" token_var="$2" token=""
  if [[ -n "${!token_var+x}" ]]; then token="${!token_var}"; fi
  if [[ -z "$token" ]]; then
    skip "authenticated case unavailable: $label (set $token_var)"
    return
  fi
  local status
  status="$(request_status creator_current_access "$token")"
  if [[ "$status" == "200" ]]; then
    pass "authenticated access introspection: $label"
  else
    printf 'FAIL authenticated access introspection: %s -> %s\n' "$label" "$status" >&2
    exit 1
  fi
  status="$(request_status creator_dashboard_summary "$token")"
  case "$label" in
    creator)
      [[ "$status" == "200" ]] && pass "creator dashboard allowed" || { printf 'FAIL creator dashboard: %s\n' "$status" >&2; exit 1; }
      ;;
    customer|merchant|review_agent|support_agent)
      [[ "$status" == "401" || "$status" == "403" ]] && pass "$label dashboard denied" || { printf 'FAIL %s dashboard unexpectedly returned %s\n' "$label" "$status" >&2; exit 1; }
      ;;
  esac
}

run_authenticated_case customer SUPABASE_TEST_CUSTOMER_ACCESS_TOKEN
run_authenticated_case merchant SUPABASE_TEST_MERCHANT_ACCESS_TOKEN
run_authenticated_case review_agent SUPABASE_TEST_REVIEW_AGENT_ACCESS_TOKEN
run_authenticated_case support_agent SUPABASE_TEST_SUPPORT_AGENT_ACCESS_TOKEN
run_authenticated_case creator SUPABASE_TEST_CREATOR_ACCESS_TOKEN

printf 'RESULT passed=%s skipped=%s\n' "$passed" "$skipped"
