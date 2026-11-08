-- Integra vendas e compras ao financeiro sem alterar as RPCs existentes.
-- Cada operação cria seu lançamento financeiro na mesma transação do registro principal.
alter table public.financial_entries
  add column if not exists source_type text,
  add column if not exists source_id uuid;

alter table public.financial_entries
  drop constraint if exists financial_entries_source_type_check;
alter table public.financial_entries
  add constraint financial_entries_source_type_check
  check (source_type is null or source_type in ('sale','purchase'));

create unique index if not exists financial_entries_source_unique
  on public.financial_entries(company_id, source_type, source_id)
  where source_type is not null and source_id is not null;

create or replace function public.create_sale_financial_entry()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_customer_name text;
begin
  if new.status = 'confirmed' and new.total > 0 then
    select name into v_customer_name
    from public.customers
    where id = new.customer_id and company_id = new.company_id;

    insert into public.financial_entries(
      company_id, entry_type, description, category, amount,
      due_date, status, notes, created_by, source_type, source_id
    )
    values (
      new.company_id,
      'income',
      'Venda #' || new.sale_number || case when v_customer_name is not null then ' - ' || v_customer_name else '' end,
      'Venda',
      new.total,
      current_date,
      'pending',
      'Lançamento gerado automaticamente pela venda.',
      new.created_by,
      'sale',
      new.id
    )
    on conflict (company_id, source_type, source_id)
      where source_type is not null and source_id is not null
      do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists sales_create_financial_entry on public.sales;
create trigger sales_create_financial_entry
after insert on public.sales
for each row execute function public.create_sale_financial_entry();

create or replace function public.create_purchase_financial_entry()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_supplier_name text;
begin
  if new.status = 'received' and new.total > 0 then
    select name into v_supplier_name
    from public.suppliers
    where id = new.supplier_id and company_id = new.company_id;

    insert into public.financial_entries(
      company_id, entry_type, description, category, amount,
      due_date, status, notes, created_by, source_type, source_id
    )
    values (
      new.company_id,
      'expense',
      'Compra #' || new.order_number || case when v_supplier_name is not null then ' - ' || v_supplier_name else '' end,
      'Compra',
      new.total,
      current_date,
      'pending',
      'Lançamento gerado automaticamente pelo recebimento da compra.',
      new.created_by,
      'purchase',
      new.id
    )
    on conflict (company_id, source_type, source_id)
      where source_type is not null and source_id is not null
      do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists purchase_create_financial_entry on public.purchase_orders;
create trigger purchase_create_financial_entry
after insert on public.purchase_orders
for each row execute function public.create_purchase_financial_entry();

revoke all on function public.create_sale_financial_entry() from public;
revoke all on function public.create_purchase_financial_entry() from public;
