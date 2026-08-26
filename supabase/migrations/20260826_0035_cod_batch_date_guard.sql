-- Keep COD reconciliation batches aligned with the order business date.
create or replace function private.enforce_cod_batch_order_date()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_catalog
as $$
declare
  v_batch_date date;
  v_order_date date;
begin
  if new.reconciliation_batch_id is null then
    return new;
  end if;

  select business_date into v_batch_date
  from public.cod_reconciliation_batches
  where id = new.reconciliation_batch_id;
  if v_batch_date is null then
    raise exception using errcode = 'P0001', message = 'COD_BATCH_NOT_FOUND';
  end if;

  select created_at::date into v_order_date
  from public.merchant_orders
  where id = new.merchant_order_id;
  if v_order_date is null or v_order_date <> v_batch_date then
    raise exception using errcode = 'P0001', message = 'COD_ORDER_BATCH_DATE_MISMATCH';
  end if;

  return new;
end;
$$;
revoke all on function private.enforce_cod_batch_order_date() from public, anon, authenticated;

drop trigger if exists cod_collection_batch_date_guard on public.cod_collection_records;
create trigger cod_collection_batch_date_guard
before insert on public.cod_collection_records
for each row execute function private.enforce_cod_batch_order_date();
