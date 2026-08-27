#!/usr/bin/env bash
set -euo pipefail

: "${SUPABASE_URL:?Set SUPABASE_URL}"
: "${SUPABASE_KEY:?Set SUPABASE_KEY to the publishable key}"

required=(
  SUPABASE_TEST_MERCHANT_ACCESS_TOKEN
  SUPABASE_TEST_SHOP_ID
  SUPABASE_TEST_FROM_LOCATION_ID
  SUPABASE_TEST_TO_LOCATION_ID
  SUPABASE_TEST_PRODUCT_ID
  SUPABASE_TEST_SECOND_PRODUCT_ID
)
for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    printf 'SKIP authenticated inventory integration: set %s from an isolated test project\n' "$name"
    exit 0
  fi
done

if [[ "${SUPABASE_TEST_ISOLATED:-0}" != "1" ]]; then
  printf 'SKIP authenticated inventory integration: set SUPABASE_TEST_ISOLATED=1 only for a disposable isolated project\n'
  exit 0
fi

base_url="${SUPABASE_URL%/}"
token="$SUPABASE_TEST_MERCHANT_ACCESS_TOKEN"
shop_id="$SUPABASE_TEST_SHOP_ID"
from_location_id="$SUPABASE_TEST_FROM_LOCATION_ID"
to_location_id="$SUPABASE_TEST_TO_LOCATION_ID"
product_id="$SUPABASE_TEST_PRODUCT_ID"
second_product_id="$SUPABASE_TEST_SECOND_PRODUCT_ID"
transfer_key="inventory-e2e-transfer-$(date +%s%N)"
count_key="inventory-e2e-count-$(date +%s%N)"

rpc() {
  local function_name="$1" body="$2"
  curl -fsS "$base_url/rest/v1/rpc/$function_name" \
    -X POST \
    -H "apikey: $SUPABASE_KEY" \
    -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' \
    --data "$body"
}

transfer_body="$(jq -cn \
  --arg shop_id "$shop_id" \
  --arg from_location_id "$from_location_id" \
  --arg to_location_id "$to_location_id" \
  --arg product_id "$product_id" \
  --arg second_product_id "$second_product_id" \
  --arg key "$transfer_key" \
  '{p_shop_id:$shop_id,p_from_location_id:$from_location_id,p_to_location_id:$to_location_id,p_items:[{product_id:$product_id,quantity:1},{product_id:$second_product_id,quantity:2}],p_reason:"isolated e2e multi-line transfer",p_idempotency_key:$key}')"

transfer_first="$(rpc complete_inventory_transfer "$transfer_body")"
transfer_second="$(rpc complete_inventory_transfer "$transfer_body")"
first_transfer_id="$(jq -er '.transfer_id' <<<"$transfer_first")"
second_transfer_id="$(jq -er '.transfer_id' <<<"$transfer_second")"
if [[ "$first_transfer_id" != "$second_transfer_id" ]] || [[ "$(jq -r '.status' <<<"$transfer_first")" != "completed" ]] || [[ "$(jq -r '.status' <<<"$transfer_second")" != "completed" ]] || [[ "$(jq -r '.idempotent' <<<"$transfer_second")" != "true" ]]; then
  printf 'FAIL transfer idempotency contract changed\n' >&2
  exit 1
fi
printf 'PASS authenticated multi-line transfer RPC and idempotency\n'

count_body="$(jq -cn \
  --arg shop_id "$shop_id" \
  --arg location_id "$from_location_id" \
  --arg product_id "$product_id" \
  --arg key "$count_key" \
  '{p_shop_id:$shop_id,p_location_id:$location_id,p_items:[{product_id:$product_id,counted_quantity:1}],p_reason:"isolated e2e inventory count",p_idempotency_key:$key}')"

count_first="$(rpc apply_inventory_count "$count_body")"
count_second="$(rpc apply_inventory_count "$count_body")"
first_count_id="$(jq -er '.count_id' <<<"$count_first")"
second_count_id="$(jq -er '.count_id' <<<"$count_second")"
if [[ "$first_count_id" != "$second_count_id" ]] || [[ "$(jq -r '.status' <<<"$count_first")" != "completed" ]] || [[ "$(jq -r '.status' <<<"$count_second")" != "completed" ]] || [[ "$(jq -r '.idempotent' <<<"$count_second")" != "true" ]]; then
  printf 'FAIL inventory count idempotency contract changed\n' >&2
  exit 1
fi
printf 'PASS authenticated inventory count RPC and idempotency\n'
