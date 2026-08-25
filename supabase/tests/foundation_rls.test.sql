-- Foundation RLS checks for Supabase's pgTAP test runner.
-- This suite intentionally uses structural checks only; authenticated allow/deny
-- scenarios should be expanded with synthetic users before pilot release.

begin;
select plan(12);

select ok(
  exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'profiles' and c.relrowsecurity),
  'profiles has RLS enabled'
);
select ok(
  exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'merchant_orders' and c.relrowsecurity),
  'merchant_orders has RLS enabled'
);
select ok(
  exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'identity_evidence' and c.relrowsecurity),
  'identity_evidence has RLS enabled'
);
select ok(
  exists (select 1 from storage.buckets where id = 'identity-evidence' and public = false),
  'identity evidence bucket is private'
);
select ok(
  exists (select 1 from storage.buckets where id = 'payment-proofs' and public = false),
  'payment proofs bucket is private'
);
select ok(
  exists (select 1 from storage.buckets where id = 'product-assets' and public = false),
  'product assets bucket is not implicitly public'
);
select ok(
  exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'checkout_create_orders' and not p.prosecdef),
  'checkout RPC wrapper is SECURITY INVOKER'
);
select ok(
  exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'private' and p.proname = 'checkout_create_orders' and p.prosecdef),
  'checkout implementation is private SECURITY DEFINER'
);
select ok(
  not has_function_privilege('anon', 'public.checkout_create_orders(uuid,jsonb,jsonb)', 'EXECUTE'),
  'anonymous users cannot execute checkout'
);
select ok(
  not has_function_privilege('anon', 'public.submit_payment_claim(uuid,text,text,text,text)', 'EXECUTE'),
  'anonymous users cannot submit payment claims'
);
select ok(
  not has_function_privilege('anon', 'public.rls_auto_enable()', 'EXECUTE'),
  'anonymous users cannot execute the legacy RLS helper'
);
select ok(
  not has_function_privilege('authenticated', 'public.rls_auto_enable()', 'EXECUTE'),
  'authenticated users cannot execute the legacy RLS helper'
);

select * from finish();
rollback;
