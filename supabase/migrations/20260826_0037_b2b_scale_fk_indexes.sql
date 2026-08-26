-- Covering indexes for C increment foreign keys identified by Performance Advisor.
-- Keep these indexes until representative query plans and traffic justify review.

create index if not exists merchant_daily_rollups_computed_by_user_idx
  on public.merchant_daily_rollups(computed_by_user_id);
create index if not exists product_asset_variants_created_by_user_idx
  on public.product_asset_variants(created_by_user_id);
create index if not exists wholesale_quote_items_variant_idx
  on public.wholesale_quote_items(variant_id);
create index if not exists wholesale_quote_versions_accepted_by_user_idx
  on public.wholesale_quote_versions(accepted_by_user_id);
create index if not exists wholesale_quote_versions_created_by_user_idx
  on public.wholesale_quote_versions(created_by_user_id);
create index if not exists wholesale_quotes_merchant_idx
  on public.wholesale_quotes(merchant_id);
create index if not exists wholesale_quotes_request_idx
  on public.wholesale_quotes(wholesale_request_id);
