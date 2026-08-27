-- Yemen Commerce synthetic debug fixture binding.
-- Run after creating the six auto-confirmed accounts through Supabase Auth UI/API.
-- This file intentionally does not insert into auth.users and never stores passwords.
-- It is safe only for the explicitly authorized mock/debug project.

begin;

do $$
declare
  v_count integer;
begin
  select count(*) into v_count
  from public.profiles
  where email in (
    'creator.auth.debug@mock.yemencommerce.dev',
    'merchant.auth.debug@mock.yemencommerce.dev',
    'customer.auth.debug@mock.yemencommerce.dev',
    'customer2.auth.debug@mock.yemencommerce.dev',
    'reviewer.auth.debug@mock.yemencommerce.dev',
    'support.auth.debug@mock.yemencommerce.dev'
  );
  if v_count <> 6 then
    raise exception using errcode = 'P0001', message = 'SUPPORTED_DEBUG_ACCOUNTS_INCOMPLETE';
  end if;
end $$;

update public.profiles p
set display_name = v.display_name,
    phone = v.phone,
    updated_at = now()
from (values
  ('creator.auth.debug@mock.yemencommerce.dev', 'مالك النظام التجريبي', '+967700000001'),
  ('merchant.auth.debug@mock.yemencommerce.dev', 'تاجر إب التجريبي', '+967700000002'),
  ('customer.auth.debug@mock.yemencommerce.dev', 'عميل إب التجريبي', '+967700000003'),
  ('customer2.auth.debug@mock.yemencommerce.dev', 'عميل ثان تجريبي', '+967700000004'),
  ('reviewer.auth.debug@mock.yemencommerce.dev', 'مراجع تجريبي', '+967700000005'),
  ('support.auth.debug@mock.yemencommerce.dev', 'دعم تجريبي', '+967700000006')
) as v(email, display_name, phone)
where p.email = v.email;

insert into public.user_access_controls(user_id, account_status)
select p.id, 'active'
from public.profiles p
where p.email like '%.auth.debug@mock.yemencommerce.dev'
on conflict (user_id) do update set account_status = 'active', updated_at = now();

insert into public.user_roles(user_id, role, market_id)
select p.id, v.role, v.market_id::uuid
from (values
  ('creator.auth.debug@mock.yemencommerce.dev', 'creator', null),
  ('merchant.auth.debug@mock.yemencommerce.dev', 'merchant', '20000000-0000-0000-0000-000000000001'),
  ('reviewer.auth.debug@mock.yemencommerce.dev', 'review_agent', '20000000-0000-0000-0000-000000000001'),
  ('support.auth.debug@mock.yemencommerce.dev', 'support_agent', '20000000-0000-0000-0000-000000000001')
) as v(email, role, market_id)
join public.profiles p on p.email = v.email
on conflict do nothing;

insert into public.creator_operator_assignments(user_id, role, market_id, granted_by_user_id, reason)
select operator.id, v.role, '20000000-0000-0000-0000-000000000001'::uuid, creator.id, v.reason
from (values
  ('reviewer.auth.debug@mock.yemencommerce.dev', 'review_agent', 'بيانات مراجعة تجريبية معزولة'),
  ('support.auth.debug@mock.yemencommerce.dev', 'support_agent', 'بيانات دعم تجريبية معزولة')
) as v(email, role, reason)
join public.profiles operator on operator.email = v.email
join public.profiles creator on creator.email = 'creator.auth.debug@mock.yemencommerce.dev'
on conflict do nothing;

-- Rebind the fixed business fixture graph to supported Auth identities.
update public.merchants m
set owner_user_id = merchant.id,
    phone = merchant.phone,
    owner_name = merchant.display_name
from public.profiles merchant
where m.id = '40000000-0000-0000-0000-000000000001'
  and merchant.email = 'merchant.auth.debug@mock.yemencommerce.dev';

update public.customer_addresses a
set customer_user_id = customer.id
from public.profiles customer
where a.id = 'ac000000-0000-0000-0000-000000000001'
  and customer.email = 'customer.auth.debug@mock.yemencommerce.dev';

update public.carts c
set customer_user_id = customer.id
from public.profiles customer
where c.id = '80000000-0000-0000-0000-000000000001'
  and customer.email = 'customer.auth.debug@mock.yemencommerce.dev';

update public.checkout_sessions s
set customer_user_id = customer.id
from public.profiles customer
where s.id = '90000000-0000-0000-0000-000000000001'
  and customer.email = 'customer.auth.debug@mock.yemencommerce.dev';
update public.checkout_sessions s
set customer_user_id = customer.id
from public.profiles customer
where s.id = '90000000-0000-0000-0000-000000000002'
  and customer.email = 'customer2.auth.debug@mock.yemencommerce.dev';

update public.merchant_orders o
set customer_user_id = customer.id,
    merchant_id = '40000000-0000-0000-0000-000000000001'::uuid
from public.profiles customer
where o.id = 'a0000000-0000-0000-0000-000000000001'
  and customer.email = 'customer.auth.debug@mock.yemencommerce.dev';
update public.merchant_orders o
set customer_user_id = customer.id,
    merchant_id = '40000000-0000-0000-0000-000000000001'::uuid
from public.profiles customer
where o.id = 'a0000000-0000-0000-0000-000000000002'
  and customer.email = 'customer2.auth.debug@mock.yemencommerce.dev';

update public.payment_claims c
set customer_user_id = customer.id,
    reviewed_by_user_id = case when c.merchant_order_id = 'a0000000-0000-0000-0000-000000000001' then merchant.id else c.reviewed_by_user_id end
from public.profiles customer
left join public.profiles merchant on merchant.email = 'merchant.auth.debug@mock.yemencommerce.dev'
where c.id in ('a2000000-0000-0000-0000-000000000001', 'a2000000-0000-0000-0000-000000000002')
  and customer.email = case when c.merchant_order_id = 'a0000000-0000-0000-0000-000000000001' then 'customer.auth.debug@mock.yemencommerce.dev' else 'customer2.auth.debug@mock.yemencommerce.dev' end;

update public.order_cases c
set opened_by_user_id = customer.id,
    reviewed_by_user_id = merchant.id
from public.profiles customer
join public.profiles merchant on merchant.email = 'merchant.auth.debug@mock.yemencommerce.dev'
where c.id = 'a4000000-0000-0000-0000-000000000001'
  and customer.email = 'customer.auth.debug@mock.yemencommerce.dev';

update public.reports r
set reporter_user_id = customer.id
from public.profiles customer
where r.id = 'af000000-0000-0000-0000-000000000001'
  and customer.email = 'customer.auth.debug@mock.yemencommerce.dev';

-- shipment/return events, AI runs/policies/approvals, order history, and audit events
-- are immutable by design; their original synthetic actors are intentionally retained.

commit;
