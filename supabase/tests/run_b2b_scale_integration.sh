#!/usr/bin/env bash
set -euo pipefail

: "${SUPABASE_URL:?Set SUPABASE_URL}"
: "${SUPABASE_KEY:?Set SUPABASE_KEY to the publishable key}"

required=(
  SUPABASE_TEST_ISOLATED
  SUPABASE_TEST_MERCHANT_ACCESS_TOKEN
  SUPABASE_TEST_CUSTOMER_ACCESS_TOKEN
  SUPABASE_TEST_B2B_SHOP_ID
  SUPABASE_TEST_B2B_REQUEST_ID
  SUPABASE_TEST_B2B_BUYER_USER_ID
  SUPABASE_TEST_B2B_ORDER_ID
  SUPABASE_TEST_B2B_PRODUCT_ID
  SUPABASE_TEST_B2B_QUOTE_QUANTITY
  SUPABASE_TEST_B2B_QUOTE_UNIT_PRICE_MINOR
)
for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    printf 'SKIP B2B/scale integration: set %s from an isolated test project\n' "$name"
    exit 0
  fi
done

if [[ "$SUPABASE_TEST_ISOLATED" != "1" ]]; then
  printf 'SKIP B2B/scale integration: set SUPABASE_TEST_ISOLATED=1 only for a disposable isolated project\n'
  exit 0
fi

for name in SUPABASE_TEST_B2B_QUOTE_QUANTITY SUPABASE_TEST_B2B_QUOTE_UNIT_PRICE_MINOR; do
  if ! [[ "${!name}" =~ ^[1-9][0-9]*$ ]]; then
    printf 'FAIL %s must be a positive integer\n' "$name" >&2
    exit 1
  fi
done

base_url="${SUPABASE_URL%/}"
merchant_token="$SUPABASE_TEST_MERCHANT_ACCESS_TOKEN"
customer_token="$SUPABASE_TEST_CUSTOMER_ACCESS_TOKEN"
shop_id="$SUPABASE_TEST_B2B_SHOP_ID"
request_id="$SUPABASE_TEST_B2B_REQUEST_ID"
buyer_user_id="$SUPABASE_TEST_B2B_BUYER_USER_ID"
order_id="$SUPABASE_TEST_B2B_ORDER_ID"
product_id="$SUPABASE_TEST_B2B_PRODUCT_ID"
quantity="$SUPABASE_TEST_B2B_QUOTE_QUANTITY"
unit_price="$SUPABASE_TEST_B2B_QUOTE_UNIT_PRICE_MINOR"
valid_until="$(date -u -d '+14 days' +%Y-%m-%dT%H:%M:%SZ)"

rpc() {
  local function_name="$1" token="$2" body="$3" raw status response
  raw="$(curl -sS "$base_url/rest/v1/rpc/$function_name" \
    -X POST \
    -H "apikey: $SUPABASE_KEY" \
    -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' \
    --data "$body" \
    -w '\n%{http_code}')"
  status="${raw##*$'\n'}"
  response="${raw%$'\n'*}"
  RPC_STATUS="$status"
  RPC_RESPONSE="$response"
}

assert_success() {
  if (( RPC_STATUS < 200 || RPC_STATUS >= 300 )); then
    printf 'FAIL %s returned HTTP %s\n%s\n' "$1" "$RPC_STATUS" "$RPC_RESPONSE" >&2
    exit 1
  fi
}

assert_failure_contains() {
  if (( RPC_STATUS < 400 || RPC_STATUS >= 600 )); then
    printf 'FAIL %s unexpectedly returned HTTP %s\n' "$1" "$RPC_STATUS" >&2
    exit 1
  fi
  if ! jq -e --arg signal "$2" 'tostring | contains($signal)' >/dev/null 2>&1 <<<"$RPC_RESPONSE"; then
    printf 'FAIL %s did not return expected safe signal %s\n' "$1" "$2" >&2
    exit 1
  fi
}

merchant_request_body="$(jq -cn --arg shop_id "$shop_id" '{p_shop_id:$shop_id}')"
rpc list_merchant_wholesale_requests "$merchant_token" "$merchant_request_body"
assert_success list_merchant_wholesale_requests
if ! jq -e --arg request_id "$request_id" 'any(.[]; .id == $request_id and .buyer_user_id != null)' >/dev/null <<<"$RPC_RESPONSE"; then
  printf 'FAIL merchant request projection did not return the isolated request context\n' >&2
  exit 1
fi
printf 'PASS merchant request projection returns buyer scope context\n'

price_lists_body="$merchant_request_body"
rpc list_merchant_price_lists "$merchant_token" "$price_lists_body"
assert_success list_merchant_price_lists
if [[ -n "${SUPABASE_TEST_B2B_PRICE_LIST_ID:-}" ]] && ! jq -e --arg id "$SUPABASE_TEST_B2B_PRICE_LIST_ID" 'any(.[]; .price_list_id == $id)' >/dev/null <<<"$RPC_RESPONSE"; then
  printf 'FAIL configured isolated price list was not returned\n' >&2
  exit 1
fi
printf 'PASS merchant price-list projection is scoped\n'

items="$(jq -cn --arg product_id "$product_id" --argjson quantity "$quantity" --argjson unit_price "$unit_price" '[{product_id:$product_id,variant_id:null,unit_price_minor:$unit_price,quantity:$quantity}]')"
quote_body="$(jq -cn \
  --arg request_id "$request_id" \
  --arg shop_id "$shop_id" \
  --arg buyer_user_id "$buyer_user_id" \
  --arg valid_until "$valid_until" \
  --argjson items "$items" \
  '{p_quote_id:null,p_wholesale_request_id:$request_id,p_shop_id:$shop_id,p_buyer_user_id:$buyer_user_id,p_currency:"YER",p_valid_until:$valid_until,p_note:"isolated B2B version",p_items:$items,p_reason:"isolated negotiated price"}')"
rpc create_wholesale_quote_version "$merchant_token" "$quote_body"
assert_success create_wholesale_quote_version
quote_id="$(jq -er '.quote_id' <<<"$RPC_RESPONSE")"
quote_version_id="$(jq -er '.quote_version_id' <<<"$RPC_RESPONSE")"
printf 'PASS merchant can create an immutable quote version in isolation\n'

merchant_quotes_body="$merchant_request_body"
rpc list_merchant_wholesale_quotes "$merchant_token" "$merchant_quotes_body"
assert_success list_merchant_wholesale_quotes
if ! jq -e --arg quote_id "$quote_id" --arg version_id "$quote_version_id" 'any(.[]; .quote_id == $quote_id and .latest_version.quote_version_id == $version_id)' >/dev/null <<<"$RPC_RESPONSE"; then
  printf 'FAIL merchant quote projection did not return the created version\n' >&2
  exit 1
fi
printf 'PASS merchant quote projection returns the latest immutable version\n'

rpc list_customer_wholesale_quotes "$customer_token" '{}'
assert_success list_customer_wholesale_quotes
if ! jq -e --arg quote_id "$quote_id" 'any(.[]; .quote_id == $quote_id)' >/dev/null <<<"$RPC_RESPONSE"; then
  printf 'FAIL customer quote inbox did not return the isolated quote\n' >&2
  exit 1
fi
printf 'PASS customer quote inbox is owner-scoped\n'

accept_body="$(jq -cn --arg version_id "$quote_version_id" '{p_quote_version_id:$version_id}')"
rpc accept_wholesale_quote_version "$customer_token" "$accept_body"
assert_success accept_wholesale_quote_version
printf 'PASS customer can accept the isolated quote version\n'

apply_body="$(jq -cn --arg order_id "$order_id" --arg version_id "$quote_version_id" '{p_merchant_order_id:$order_id,p_quote_version_id:$version_id}')"
rpc apply_accepted_wholesale_quote "$customer_token" "$apply_body"
assert_success apply_accepted_wholesale_quote
printf 'PASS accepted quote applies only through the negotiated checkout RPC\n'

rpc apply_accepted_wholesale_quote "$customer_token" "$apply_body"
assert_failure_contains apply_accepted_wholesale_quote_again 'QUOTE_ORDER_ALREADY_PRICED'
printf 'PASS re-applying a negotiated price is denied safely\n'

rollup_body="$(jq -cn --arg shop_id "$shop_id" --arg business_date "$(date -u +%F)" '{p_shop_id:$shop_id,p_business_date:$business_date}')"
rpc refresh_merchant_daily_rollup "$merchant_token" "$rollup_body"
assert_success refresh_merchant_daily_rollup
if ! jq -e --arg shop_id "$shop_id" '.shop_id == $shop_id' >/dev/null <<<"$RPC_RESPONSE"; then
  printf 'FAIL refreshed daily rollup returned the wrong shop scope\n' >&2
  exit 1
fi
printf 'PASS daily analytics rollup refresh is merchant-scoped\n'

rpc provider_adapter_operations "$merchant_token" '{}'
assert_success provider_adapter_operations
if jq -e 'any(.[]; .enabled == true)' >/dev/null <<<"$RPC_RESPONSE"; then
  printf 'FAIL a provider adapter operation is enabled before explicit approval\n' >&2
  exit 1
fi
printf 'PASS provider adapter operations remain disabled by default\n'
