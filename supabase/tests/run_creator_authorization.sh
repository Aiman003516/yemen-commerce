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
