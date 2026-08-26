#!/usr/bin/env bash
set -euo pipefail

: "${SUPABASE_URL:?Set SUPABASE_URL}"
: "${SUPABASE_KEY:?Set SUPABASE_KEY to the publishable key}"

required=(
  SUPABASE_TEST_ISOLATED
  SUPABASE_TEST_MERCHANT_ACCESS_TOKEN
  SUPABASE_TEST_SHOP_ID
  SUPABASE_TEST_COD_ORDER_ID
  SUPABASE_TEST_COD_BUSINESS_DATE
  SUPABASE_TEST_COD_EXPECTED_MINOR
)
for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    printf 'SKIP authenticated order-workbench/COD integration: set %s from an isolated test project\n' "$name"
    exit 0
  fi
done

if [[ "$SUPABASE_TEST_ISOLATED" != "1" ]]; then
  printf 'SKIP authenticated order-workbench/COD integration: set SUPABASE_TEST_ISOLATED=1 only for a disposable isolated project\n'
  exit 0
fi

if ! [[ "$SUPABASE_TEST_COD_EXPECTED_MINOR" =~ ^[0-9]+$ ]]; then
  printf 'FAIL SUPABASE_TEST_COD_EXPECTED_MINOR must be a non-negative integer\n' >&2
  exit 1
fi

base_url="${SUPABASE_URL%/}"
token="$SUPABASE_TEST_MERCHANT_ACCESS_TOKEN"
shop_id="$SUPABASE_TEST_SHOP_ID"
cod_order_id="$SUPABASE_TEST_COD_ORDER_ID"
business_date="$SUPABASE_TEST_COD_BUSINESS_DATE"
expected_minor="$SUPABASE_TEST_COD_EXPECTED_MINOR"
mismatch_date="$(date -u -d "$business_date - 1 day" +%F 2>/dev/null || true)"
if [[ -z "$mismatch_date" || "$mismatch_date" == "$business_date" ]]; then
  printf 'FAIL SUPABASE_TEST_COD_BUSINESS_DATE must be an ISO date accepted by GNU date\n' >&2
  exit 1
fi

rpc() {
  local function_name="$1" body="$2" raw status response
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
    printf 'FAIL %s returned HTTP %s\n' "$1" "$RPC_STATUS" >&2
    exit 1
  fi
}

assert_failure_contains() {
  if (( RPC_STATUS < 400 || RPC_STATUS >= 600 )); then
    printf 'FAIL %s unexpectedly returned HTTP %s\n' "$1" "$RPC_STATUS" >&2
    exit 1
  fi
  if ! jq -e --arg signal "$2" 'tostring | contains($signal)' >/dev/null 2>&1 <<<"$RPC_RESPONSE"; then
    printf 'FAIL %s did not return the expected safe database signal\n' "$1" >&2
    exit 1
  fi
}

workbench_body="$(jq -cn \
  --arg shop_id "$shop_id" \
  '{p_shop_id:$shop_id,p_fulfilment_status:null,p_payment_status:null,p_cod_status:null,p_query:null,p_limit:50,p_offset:0}')"
rpc merchant_order_workbench "$workbench_body"
assert_success merchant_order_workbench
if ! jq -e --arg order_id "$cod_order_id" 'any(.[]; .id == $order_id)' >/dev/null <<<"$RPC_RESPONSE"; then
  printf 'FAIL workbench did not return the owned COD fixture order\n' >&2
  exit 1
fi
printf 'PASS merchant workbench returns the owned fixture projection\n'

cod_body="$(jq -cn \
  --arg shop_id "$shop_id" \
  --arg business_date "$business_date" \
  '{p_shop_id:$shop_id,p_business_date:$business_date,p_limit:50,p_offset:0}')"
rpc merchant_cod_reconciliation "$cod_body"
assert_success merchant_cod_reconciliation
if ! jq -e --arg order_id "$cod_order_id" 'any(.rows[]; .merchant_order_id == $order_id)' >/dev/null <<<"$RPC_RESPONSE"; then
  printf 'FAIL COD reconciliation did not return the owned cash-order fixture\n' >&2
  exit 1
fi
printf 'PASS COD reconciliation returns the owned cash-order projection\n'

open_body="$(jq -cn \
  --arg shop_id "$shop_id" \
  --arg business_date "$business_date" \
  '{p_shop_id:$shop_id,p_business_date:$business_date,p_note:"isolated workbench COD batch"}')"
rpc open_cod_reconciliation_batch "$open_body"
assert_success open_cod_reconciliation_batch
batch_id="$(jq -er '.batch_id' <<<"$RPC_RESPONSE")"

rpc open_cod_reconciliation_batch "$open_body"
assert_success open_cod_reconciliation_batch
second_batch_id="$(jq -er '.batch_id' <<<"$RPC_RESPONSE")"
if [[ "$batch_id" != "$second_batch_id" ]] || [[ "$(jq -r '.idempotent' <<<"$RPC_RESPONSE")" != "true" ]]; then
  printf 'FAIL opening the same COD batch was not idempotent\n' >&2
  exit 1
fi
printf 'PASS COD batch open is idempotent\n'

mismatch_open_body="$(jq -cn \
  --arg shop_id "$shop_id" \
  --arg business_date "$mismatch_date" \
  '{p_shop_id:$shop_id,p_business_date:$business_date,p_note:"isolated mismatch guard"}')"
rpc open_cod_reconciliation_batch "$mismatch_open_body"
assert_success open_cod_reconciliation_batch
mismatch_batch_id="$(jq -er '.batch_id' <<<"$RPC_RESPONSE")"

mismatch_record_body="$(jq -cn \
  --arg order_id "$cod_order_id" \
  --arg batch_id "$mismatch_batch_id" \
  --argjson amount "$expected_minor" \
  '{p_merchant_order_id:$order_id,p_collected_minor:$amount,p_note:"isolated date mismatch" ,p_reconciliation_batch_id:$batch_id}')"
rpc record_cod_collection "$mismatch_record_body"
assert_failure_contains record_cod_collection_date_guard 'COD_ORDER_BATCH_DATE_MISMATCH'
printf 'PASS COD batch date mismatch is rejected\n'

record_body="$(jq -cn \
  --arg order_id "$cod_order_id" \
  --arg batch_id "$batch_id" \
  --argjson amount "$expected_minor" \
  '{p_merchant_order_id:$order_id,p_collected_minor:$amount,p_note:"isolated exact COD collection" ,p_reconciliation_batch_id:$batch_id}')"
rpc record_cod_collection "$record_body"
assert_success record_cod_collection
if [[ "$(jq -r '.cod_status' <<<"$RPC_RESPONSE")" != "collected" || "$(jq -r '.payment_status' <<<"$RPC_RESPONSE")" != "paid" ]]; then
  printf 'FAIL exact COD collection did not produce collected/paid status\n' >&2
  exit 1
fi
printf 'PASS exact COD collection updates payment and collection status\n'

rpc merchant_cod_reconciliation "$cod_body"
assert_success merchant_cod_reconciliation
if ! jq -e --arg order_id "$cod_order_id" --argjson amount "$expected_minor" \
  'any(.rows[]; .merchant_order_id == $order_id and .status == "collected" and .collected_minor == $amount)' >/dev/null <<<"$RPC_RESPONSE"; then
  printf 'FAIL COD reconciliation summary did not expose the latest collection record\n' >&2
  exit 1
fi
printf 'PASS COD reconciliation exposes the latest collection record\n'

close_body="$(jq -cn --arg batch_id "$batch_id" '{p_batch_id:$batch_id,p_note:"isolated close"}')"
rpc close_cod_reconciliation_batch "$close_body"
assert_success close_cod_reconciliation_batch
if [[ "$(jq -r '.status' <<<"$RPC_RESPONSE")" != "${SUPABASE_TEST_EXPECTED_BATCH_STATUS:-reconciled}" ]]; then
  printf 'FAIL COD batch close returned an unexpected status\n' >&2
  exit 1
fi
printf 'PASS COD batch close returns the expected reconciliation status\n'

rpc close_cod_reconciliation_batch "$close_body"
assert_failure_contains close_cod_reconciliation_batch_closed 'COD_BATCH_ALREADY_CLOSED'
printf 'PASS closed COD batch rejects re-close\n'
