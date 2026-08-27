-- Public catalog queries need active channel metadata visible under anon RLS.
-- This exposes only channel identity needed for published listings; credentials,
-- private configurations, and merchant controls remain unavailable.
drop policy if exists commerce_channels_public_read on public.commerce_channels;
create policy commerce_channels_public_read on public.commerce_channels
for select to anon using (
  status = 'active'
  and exists (
    select 1 from public.shops s
    join public.markets market on market.id = s.market_id
    where s.id = commerce_channels.shop_id
      and s.status = 'approved'
      and market.status = 'active'
  )
);
