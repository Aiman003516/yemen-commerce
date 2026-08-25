-- Keep privileged implementations out of the exposed public schema.
-- Public wrappers are SECURITY INVOKER; they delegate to tightly scoped, fixed-search_path implementations.

alter function public.checkout_create_orders(uuid, jsonb, jsonb) set schema private;
alter function public.submit_payment_claim(uuid, text, text, text, text) set schema private;
alter function public.review_payment_claim(uuid, text, text) set schema private;
alter function public.transition_fulfilment(uuid, text, text) set schema private;

grant usage on schema private to authenticated;
grant execute on function private.checkout_create_orders(uuid, jsonb, jsonb) to authenticated, service_role;
grant execute on function private.submit_payment_claim(uuid, text, text, text, text) to authenticated, service_role;
grant execute on function private.review_payment_claim(uuid, text, text) to authenticated, service_role;
grant execute on function private.transition_fulfilment(uuid, text, text) to authenticated, service_role;

create or replace function public.checkout_create_orders(p_market_id uuid, p_fulfilment_by_shop jsonb, p_payment_by_merchant jsonb)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$
  select private.checkout_create_orders(p_market_id, p_fulfilment_by_shop, p_payment_by_merchant);
$$;
create or replace function public.submit_payment_claim(p_merchant_order_id uuid, p_transaction_reference text, p_proof_storage_key text default null, p_proof_mime_type text default null, p_proof_original_name text default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$
  select private.submit_payment_claim(p_merchant_order_id, p_transaction_reference, p_proof_storage_key, p_proof_mime_type, p_proof_original_name);
$$;
create or replace function public.review_payment_claim(p_merchant_order_id uuid, p_decision text, p_reason text default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$
  select private.review_payment_claim(p_merchant_order_id, p_decision, p_reason);
$$;
create or replace function public.transition_fulfilment(p_merchant_order_id uuid, p_next_status text, p_reason text default null)
returns jsonb language sql security invoker set search_path = public, pg_catalog as $$
  select private.transition_fulfilment(p_merchant_order_id, p_next_status, p_reason);
$$;

revoke all on function public.checkout_create_orders(uuid, jsonb, jsonb) from public, anon;
revoke all on function public.submit_payment_claim(uuid, text, text, text, text) from public, anon;
revoke all on function public.review_payment_claim(uuid, text, text) from public, anon;
revoke all on function public.transition_fulfilment(uuid, text, text) from public, anon;
grant execute on function public.checkout_create_orders(uuid, jsonb, jsonb) to authenticated;
grant execute on function public.submit_payment_claim(uuid, text, text, text, text) to authenticated;
grant execute on function public.review_payment_claim(uuid, text, text) to authenticated;
grant execute on function public.transition_fulfilment(uuid, text, text) to authenticated;
