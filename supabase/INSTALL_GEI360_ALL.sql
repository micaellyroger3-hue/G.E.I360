-- G.E.I360 | INSTALADOR SQL CONSOLIDADO
-- Execute FINALIZATION_PRECHECK.sql primeiro e revise o resultado.
-- Faça backup antes da execução. Rode este arquivo no SQL Editor do projeto correto.
-- Este instalador reúne as migrations na ordem oficial e as executa em UMA transação.
-- Se qualquer etapa falhar, a transação inteira será revertida.
-- É idempotente nos objetos protegidos por IF NOT EXISTS / DROP-AND-CREATE das migrations.
-- Não executa testes de isolamento multiempresa; isso exige duas contas autenticadas.

begin;


-- ============================================================================
-- SOURCE supabase/migrations/202611070001_employees.sql
-- ============================================================================
-- G.E.I360: cadastro de funcionários por empresa
-- Execute no Supabase SQL Editor uma única vez.
create table if not exists public.employees (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  full_name text not null,
  email text,
  phone text,
  job_title text,
  department text,
  status text not null default 'active' check (status in ('active','inactive')),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists employees_company_id_idx on public.employees(company_id);
alter table public.employees enable row level security;

drop policy if exists employees_members_select on public.employees;
create policy employees_members_select
on public.employees for select to authenticated
using (public.is_company_member(company_id));

drop policy if exists employees_managers_insert on public.employees;
create policy employees_managers_insert
on public.employees for insert to authenticated
with check (
  created_by = (select auth.uid())
  and public.has_company_role(company_id, array['owner','admin','manager']::text[])
);

drop policy if exists employees_managers_update on public.employees;
create policy employees_managers_update
on public.employees for update to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager']::text[]))
with check (public.has_company_role(company_id, array['owner','admin','manager']::text[]));

drop policy if exists employees_admins_delete on public.employees;
create policy employees_admins_delete
on public.employees for delete to authenticated
using (public.has_company_role(company_id, array['owner','admin']::text[]));

grant select, insert, update, delete on public.employees to authenticated;


-- ============================================================================
-- SOURCE supabase/migrations/202611080001_erp_modules.sql
-- ============================================================================
-- G.E.I360 ERP Core: fornecedores, clientes, produtos, estoque, vendas, financeiro e documentos.
-- Execute no Supabase SQL Editor depois da migration employees.
create extension if not exists pgcrypto;

create table if not exists public.suppliers (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name text not null,
  document text,
  email text,
  phone text,
  notes text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name text not null,
  document text,
  email text,
  phone text,
  address text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name text not null,
  sku text,
  barcode text,
  category text,
  unit text not null default 'un',
  cost_price numeric(14,2) not null default 0 check(cost_price >= 0),
  sale_price numeric(14,2) not null default 0 check(sale_price >= 0),
  stock_quantity numeric(14,3) not null default 0,
  min_stock numeric(14,3) not null default 0,
  active boolean not null default true,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, sku)
);
create table if not exists public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  movement_type text not null check(movement_type in ('in','out','adjustment')),
  quantity numeric(14,3) not null check(quantity > 0),
  unit_cost numeric(14,2) not null default 0 check(unit_cost >= 0),
  note text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);
create table if not exists public.sales (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  customer_id uuid references public.customers(id) on delete set null,
  sale_number bigint generated by default as identity,
  sale_date date not null default current_date,
  status text not null default 'draft' check(status in ('draft','confirmed','cancelled')),
  subtotal numeric(14,2) not null default 0,
  discount numeric(14,2) not null default 0 check(discount >= 0),
  total numeric(14,2) not null default 0,
  notes text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);
create table if not exists public.sale_items (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  sale_id uuid not null references public.sales(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  description text not null,
  quantity numeric(14,3) not null check(quantity > 0),
  unit_price numeric(14,2) not null check(unit_price >= 0),
  line_total numeric(14,2) generated always as (round(quantity * unit_price,2)) stored,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);
create table if not exists public.financial_entries (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  entry_type text not null check(entry_type in ('income','expense')),
  description text not null,
  category text,
  amount numeric(14,2) not null check(amount > 0),
  due_date date not null default current_date,
  paid_at timestamptz,
  status text not null default 'pending' check(status in ('pending','paid','cancelled')),
  payment_method text,
  notes text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.business_documents (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  document_type text not null default 'other' check(document_type in ('invoice_received','receipt','contract','quote','other')),
  title text not null,
  document_number text,
  issue_date date,
  amount numeric(14,2),
  storage_path text,
  notes text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create index if not exists suppliers_company_idx on public.suppliers(company_id);
create index if not exists customers_company_idx on public.customers(company_id);
create index if not exists products_company_idx on public.products(company_id);
create index if not exists products_barcode_idx on public.products(company_id,barcode);
create index if not exists stock_movements_company_idx on public.stock_movements(company_id,created_at desc);
create index if not exists sales_company_idx on public.sales(company_id,sale_date desc);
create index if not exists financial_entries_company_idx on public.financial_entries(company_id,due_date desc);
create index if not exists business_documents_company_idx on public.business_documents(company_id,created_at desc);

create or replace function public.apply_stock_movement()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if new.movement_type = 'in' then
    update public.products set stock_quantity = stock_quantity + new.quantity where id = new.product_id and company_id = new.company_id;
    if not found then raise exception 'Produto não encontrado nesta empresa'; end if;
  elsif new.movement_type = 'out' then
    update public.products set stock_quantity = stock_quantity - new.quantity where id = new.product_id and company_id = new.company_id and stock_quantity >= new.quantity;
    if not found then raise exception 'Estoque insuficiente ou produto não encontrado'; end if;
  else
    update public.products set stock_quantity = new.quantity where id = new.product_id and company_id = new.company_id;
    if not found then raise exception 'Produto não encontrado nesta empresa'; end if;
  end if;
  return new;
end;
$$;
drop trigger if exists stock_movement_apply on public.stock_movements;
create trigger stock_movement_apply before insert on public.stock_movements for each row execute function public.apply_stock_movement();

do $$
declare t text;
begin
  foreach t in array array['suppliers','customers','products','financial_entries','business_documents'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('drop policy if exists %I on public.%I',t||'_member_read',t);
    execute format('create policy %I on public.%I for select to authenticated using (public.is_company_member(company_id))',t||'_member_read',t);
    execute format('drop policy if exists %I on public.%I',t||'_manager_insert',t);
    execute format('create policy %I on public.%I for insert to authenticated with check (created_by = (select auth.uid()) and public.has_company_role(company_id, array[''owner'',''admin'',''manager'']::text[]))',t||'_manager_insert',t);
    execute format('drop policy if exists %I on public.%I',t||'_manager_update',t);
    execute format('create policy %I on public.%I for update to authenticated using (public.has_company_role(company_id, array[''owner'',''admin'',''manager'']::text[])) with check (public.has_company_role(company_id, array[''owner'',''admin'',''manager'']::text[]))',t||'_manager_update',t);
    execute format('drop policy if exists %I on public.%I',t||'_admin_delete',t);
    execute format('create policy %I on public.%I for delete to authenticated using (public.has_company_role(company_id, array[''owner'',''admin'']::text[]))',t||'_admin_delete',t);
    execute format('grant select, insert, update, delete on public.%I to authenticated',t);
  end loop;
end $$;

-- Histórico operacional: leitura para membros; gravação somente pelas funções transacionais.
-- Evita inserções/edições manuais que possam desalinhar estoque, vendas e itens.
do $$
declare t text;
begin
  foreach t in array array['stock_movements','sales','sale_items'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('drop policy if exists %I on public.%I',t||'_member_read',t);
    execute format('create policy %I on public.%I for select to authenticated using (public.is_company_member(company_id))',t||'_member_read',t);
    execute format('grant select on public.%I to authenticated',t);
    execute format('revoke insert, update, delete on public.%I from authenticated',t);
  end loop;
end $$;

-- Movimentação manual de estoque validada e atômica.
create or replace function public.record_stock_movement(
  p_company_id uuid,
  p_product_id uuid,
  p_movement_type text,
  p_quantity numeric,
  p_unit_cost numeric default 0,
  p_note text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $
declare
  v_user uuid := auth.uid();
  v_product public.products%rowtype;
  v_movement public.stock_movements%rowtype;
begin
  if v_user is null then raise exception 'Faça login novamente.'; end if;
  if not public.has_company_role(p_company_id,array['owner','admin','manager']::text[]) then
    raise exception 'Você não tem permissão para movimentar o estoque.';
  end if;
  if p_movement_type not in ('in','out','adjustment') then raise exception 'Tipo de movimentação inválido.'; end if;
  if p_quantity is null or p_quantity < 0 or (p_movement_type <> 'adjustment' and p_quantity = 0) then
    raise exception 'Quantidade inválida.';
  end if;
  if p_unit_cost is null or p_unit_cost < 0 then raise exception 'Custo unitário inválido.'; end if;
  select * into v_product from public.products
   where id=p_product_id and company_id=p_company_id for update;
  if not found then raise exception 'Produto não encontrado nesta empresa.'; end if;
  if p_movement_type='out' and v_product.stock_quantity < p_quantity then
    raise exception 'Estoque insuficiente. Saldo atual: %',v_product.stock_quantity;
  end if;
  insert into public.stock_movements(company_id,product_id,movement_type,quantity,unit_cost,note,created_by)
  values(p_company_id,p_product_id,p_movement_type,p_quantity,p_unit_cost,p_note,v_user)
  returning * into v_movement;
  return jsonb_build_object('id',v_movement.id,'stock_quantity',
    (select stock_quantity from public.products where id=p_product_id and company_id=p_company_id));
end;
$;
revoke all on function public.record_stock_movement(uuid,uuid,text,numeric,numeric,text) from public;
grant execute on function public.record_stock_movement(uuid,uuid,text,numeric,numeric,text) to authenticated;

-- Venda atômica: grava cabeçalho, item e baixa estoque em uma única transação.
create or replace function public.create_sale(
  p_company_id uuid,
  p_customer_id uuid,
  p_product_id uuid,
  p_quantity numeric,
  p_discount numeric default 0,
  p_notes text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_product public.products%rowtype;
  v_sale public.sales%rowtype;
  v_subtotal numeric(14,2);
  v_total numeric(14,2);
begin
  if v_user is null then raise exception 'Faça login novamente.'; end if;
  if not public.has_company_role(p_company_id, array['owner','admin','manager']::text[]) then
    raise exception 'Você não tem permissão para registrar vendas.';
  end if;
  if p_quantity is null or p_quantity <= 0 then raise exception 'Quantidade inválida.'; end if;
  if p_discount is null or p_discount < 0 then raise exception 'Desconto inválido.'; end if;

  select * into v_product
  from public.products
  where id = p_product_id and company_id = p_company_id and active = true
  for update;
  if not found then raise exception 'Produto não encontrado ou inativo nesta empresa.'; end if;

  if p_customer_id is not null and not exists (
    select 1 from public.customers where id = p_customer_id and company_id = p_company_id
  ) then raise exception 'Cliente não pertence a esta empresa.'; end if;

  if v_product.stock_quantity < p_quantity then
    raise exception 'Estoque insuficiente. Saldo atual: %', v_product.stock_quantity;
  end if;

  v_subtotal := round(p_quantity * v_product.sale_price, 2);
  v_total := v_subtotal - p_discount;
  if v_total < 0 then raise exception 'O desconto não pode superar o subtotal.'; end if;

  insert into public.sales(company_id, customer_id, status, subtotal, discount, total, notes, created_by)
  values (p_company_id, p_customer_id, 'confirmed', v_subtotal, p_discount, v_total, p_notes, v_user)
  returning * into v_sale;

  insert into public.sale_items(company_id, sale_id, product_id, description, quantity, unit_price, created_by)
  values (p_company_id, v_sale.id, v_product.id, v_product.name, p_quantity, v_product.sale_price, v_user);

  insert into public.stock_movements(company_id, product_id, movement_type, quantity, note, created_by)
  values (p_company_id, v_product.id, 'out', p_quantity, 'Venda #' || v_sale.sale_number, v_user);

  return jsonb_build_object('id', v_sale.id, 'sale_number', v_sale.sale_number, 'subtotal', v_subtotal, 'discount', p_discount, 'total', v_total);
end;
$$;

revoke all on function public.create_sale(uuid, uuid, uuid, numeric, numeric, text) from public;
grant execute on function public.create_sale(uuid, uuid, uuid, numeric, numeric, text) to authenticated;

-- Ajustes de inventário podem zerar o saldo; entradas e saídas continuam exigindo quantidade positiva.
alter table public.stock_movements drop constraint if exists stock_movements_quantity_check;
alter table public.stock_movements add constraint stock_movements_quantity_check
  check ((movement_type = 'adjustment' and quantity >= 0) or (movement_type in ('in','out') and quantity > 0));


-- Compras e recebimento de mercadorias.
create table if not exists public.purchase_orders (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  supplier_id uuid references public.suppliers(id) on delete set null,
  order_number bigint generated by default as identity,
  status text not null default 'draft' check(status in ('draft','received','cancelled')),
  total numeric(14,2) not null default 0 check(total >= 0),
  notes text,
  received_at timestamptz,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);
create table if not exists public.purchase_order_items (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  purchase_order_id uuid not null references public.purchase_orders(id) on delete cascade,
  product_id uuid not null references public.products(id),
  quantity numeric(14,3) not null check(quantity > 0),
  unit_cost numeric(14,2) not null check(unit_cost >= 0),
  line_total numeric(14,2) generated always as (round(quantity * unit_cost,2)) stored,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);
alter table public.purchase_orders enable row level security;
alter table public.purchase_order_items enable row level security;
-- Histórico de compras: leitura para membros; gravação somente pelas funções transacionais.
-- Impede alterar ou apagar recebimentos sem reverter estoque e financeiro.
drop policy if exists purchase_orders_member_select on public.purchase_orders;
drop policy if exists purchase_orders_manager_insert on public.purchase_orders;
drop policy if exists purchase_orders_manager_update on public.purchase_orders;
drop policy if exists purchase_orders_admin_delete on public.purchase_orders;
drop policy if exists purchase_items_member_select on public.purchase_order_items;
drop policy if exists purchase_items_manager_insert on public.purchase_order_items;
drop policy if exists purchase_items_manager_update on public.purchase_order_items;
drop policy if exists purchase_items_admin_delete on public.purchase_order_items;
create policy purchase_orders_member_select on public.purchase_orders for select to authenticated using (public.is_company_member(company_id));
create policy purchase_items_member_select on public.purchase_order_items for select to authenticated using (public.is_company_member(company_id));
grant select on public.purchase_orders,public.purchase_order_items to authenticated;
revoke insert,update,delete on public.purchase_orders,public.purchase_order_items from authenticated;

create or replace function public.receive_purchase(
  p_company_id uuid,
  p_supplier_id uuid,
  p_product_id uuid,
  p_quantity numeric,
  p_unit_cost numeric,
  p_notes text default null
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_product public.products%rowtype;
  v_order public.purchase_orders%rowtype;
begin
  if v_user is null then raise exception 'Faça login novamente.'; end if;
  if not public.has_company_role(p_company_id,array['owner','admin','manager']::text[]) then raise exception 'Sem permissão para registrar compras.'; end if;
  if p_quantity is null or p_quantity <= 0 or p_unit_cost is null or p_unit_cost < 0 then raise exception 'Quantidade ou custo inválido.'; end if;
  select * into v_product from public.products where id=p_product_id and company_id=p_company_id and active=true for update;
  if not found then raise exception 'Produto não encontrado ou inativo nesta empresa.'; end if;
  if p_supplier_id is not null and not exists(select 1 from public.suppliers where id=p_supplier_id and company_id=p_company_id) then raise exception 'Fornecedor não pertence a esta empresa.'; end if;
  insert into public.purchase_orders(company_id,supplier_id,status,total,notes,received_at,created_by)
  values(p_company_id,p_supplier_id,'received',round(p_quantity*p_unit_cost,2),p_notes,now(),v_user) returning * into v_order;
  insert into public.purchase_order_items(company_id,purchase_order_id,product_id,quantity,unit_cost,created_by)
  values(p_company_id,v_order.id,p_product_id,p_quantity,p_unit_cost,v_user);
  insert into public.stock_movements(company_id,product_id,movement_type,quantity,unit_cost,note,created_by)
  values(p_company_id,p_product_id,'in',p_quantity,p_unit_cost,'Recebimento da compra #'||v_order.order_number,v_user);
  return jsonb_build_object('id',v_order.id,'order_number',v_order.order_number,'total',v_order.total);
end;
$$;
revoke all on function public.receive_purchase(uuid,uuid,uuid,numeric,numeric,text) from public;
grant execute on function public.receive_purchase(uuid,uuid,uuid,numeric,numeric,text) to authenticated;


-- Armazenamento privado de anexos empresariais.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('company-documents', 'company-documents', false, 10485760, array['application/pdf','image/jpeg','image/png','image/webp'])
on conflict (id) do update set
  public = false,
  file_size_limit = 10485760,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists company_documents_member_read on storage.objects;
create policy company_documents_member_read
on storage.objects for select to authenticated
using (
  bucket_id = 'company-documents'
  and exists (
    select 1 from public.company_members cm
    where cm.company_id::text = (storage.foldername(name))[1]
      and cm.user_id = (select auth.uid())
      and cm.status = 'active'
  )
);

drop policy if exists company_documents_manager_upload on storage.objects;
create policy company_documents_manager_upload
on storage.objects for insert to authenticated
with check (
  bucket_id = 'company-documents'
  and exists (
    select 1 from public.company_members cm
    where cm.company_id::text = (storage.foldername(name))[1]
      and cm.user_id = (select auth.uid())
      and cm.status = 'active'
      and cm.role in ('owner','admin','manager')
  )
);

drop policy if exists company_documents_manager_update on storage.objects;
create policy company_documents_manager_update
on storage.objects for update to authenticated
using (
  bucket_id = 'company-documents'
  and exists (
    select 1 from public.company_members cm
    where cm.company_id::text = (storage.foldername(name))[1]
      and cm.user_id = (select auth.uid())
      and cm.status = 'active'
      and cm.role in ('owner','admin','manager')
  )
)
with check (
  bucket_id = 'company-documents'
  and exists (
    select 1 from public.company_members cm
    where cm.company_id::text = (storage.foldername(name))[1]
      and cm.user_id = (select auth.uid())
      and cm.status = 'active'
      and cm.role in ('owner','admin','manager')
  )
);

drop policy if exists company_documents_admin_delete on storage.objects;
create policy company_documents_admin_delete
on storage.objects for delete to authenticated
using (
  bucket_id = 'company-documents'
  and exists (
    select 1 from public.company_members cm
    where cm.company_id::text = (storage.foldername(name))[1]
      and cm.user_id = (select auth.uid())
      and cm.status = 'active'
      and cm.role in ('owner','admin')
  )
);


-- Venda com múltiplos produtos em uma única transação.
create or replace function public.create_sale_cart(
  p_company_id uuid,
  p_customer_id uuid,
  p_items jsonb,
  p_discount numeric default 0,
  p_notes text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_sale public.sales%rowtype;
  v_item jsonb;
  v_product public.products%rowtype;
  v_product_id uuid;
  v_quantity numeric(14,3);
  v_subtotal numeric(14,2) := 0;
  v_total numeric(14,2);
  v_seen uuid[] := array[]::uuid[];
  v_items_count integer := 0;
begin
  if v_user is null then raise exception 'Faça login novamente.'; end if;
  if not public.has_company_role(p_company_id, array['owner','admin','manager']::text[]) then
    raise exception 'Você não tem permissão para registrar vendas.';
  end if;
  if jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Adicione pelo menos um produto ao carrinho.';
  end if;
  if p_discount is null or p_discount < 0 then raise exception 'Desconto inválido.'; end if;
  if p_customer_id is not null and not exists (
    select 1 from public.customers where id = p_customer_id and company_id = p_company_id
  ) then raise exception 'Cliente não pertence a esta empresa.'; end if;

  -- Bloqueia os produtos em ordem determinística para reduzir risco de deadlock.
  for v_item in
    select value from jsonb_array_elements(p_items) order by (value->>'product_id')
  loop
    begin
      v_product_id := (v_item->>'product_id')::uuid;
      v_quantity := (v_item->>'quantity')::numeric;
    exception when others then
      raise exception 'Produto ou quantidade inválida no carrinho.';
    end;
    if v_product_id = any(v_seen) then raise exception 'Há produto repetido no carrinho.'; end if;
    v_seen := array_append(v_seen, v_product_id);
    if v_quantity is null or v_quantity <= 0 then raise exception 'Quantidade inválida no carrinho.'; end if;
    select * into v_product from public.products
      where id = v_product_id and company_id = p_company_id and active = true
      for update;
    if not found then raise exception 'Produto não encontrado ou inativo nesta empresa.'; end if;
    if v_product.stock_quantity < v_quantity then
      raise exception 'Estoque insuficiente para %. Saldo atual: %', v_product.name, v_product.stock_quantity;
    end if;
    v_subtotal := v_subtotal + round(v_quantity * v_product.sale_price, 2);
    v_items_count := v_items_count + 1;
  end loop;

  v_total := v_subtotal - p_discount;
  if v_total < 0 then raise exception 'O desconto não pode superar o subtotal.'; end if;

  insert into public.sales(company_id, customer_id, status, subtotal, discount, total, notes, created_by)
  values (p_company_id, p_customer_id, 'confirmed', v_subtotal, p_discount, v_total, p_notes, v_user)
  returning * into v_sale;

  for v_item in select value from jsonb_array_elements(p_items) order by (value->>'product_id')
  loop
    v_product_id := (v_item->>'product_id')::uuid;
    v_quantity := (v_item->>'quantity')::numeric;
    select * into v_product from public.products
      where id = v_product_id and company_id = p_company_id;
    insert into public.sale_items(company_id, sale_id, product_id, description, quantity, unit_price, created_by)
    values (p_company_id, v_sale.id, v_product.id, v_product.name, v_quantity, v_product.sale_price, v_user);
    insert into public.stock_movements(company_id, product_id, movement_type, quantity, note, created_by)
    values (p_company_id, v_product.id, 'out', v_quantity, 'Venda #' || v_sale.sale_number, v_user);
  end loop;

  return jsonb_build_object('id', v_sale.id, 'sale_number', v_sale.sale_number,
    'items_count', v_items_count, 'subtotal', v_subtotal, 'discount', p_discount, 'total', v_total);
end;
$$;

revoke all on function public.create_sale_cart(uuid, uuid, jsonb, numeric, text) from public;
grant execute on function public.create_sale_cart(uuid, uuid, jsonb, numeric, text) to authenticated;


-- Recebimento de vários produtos em uma única transação.
create or replace function public.receive_purchase_cart(
  p_company_id uuid,
  p_supplier_id uuid,
  p_items jsonb,
  p_notes text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_order public.purchase_orders%rowtype;
  v_item jsonb;
  v_product public.products%rowtype;
  v_product_id uuid;
  v_quantity numeric(14,3);
  v_unit_cost numeric(14,2);
  v_total numeric(14,2) := 0;
  v_seen uuid[] := array[]::uuid[];
  v_items_count integer := 0;
begin
  if v_user is null then raise exception 'Faça login novamente.'; end if;
  if not public.has_company_role(p_company_id,array['owner','admin','manager']::text[]) then
    raise exception 'Sem permissão para registrar compras.';
  end if;
  if jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items)=0 then
    raise exception 'Adicione pelo menos um produto ao recebimento.';
  end if;
  if p_supplier_id is not null and not exists(select 1 from public.suppliers where id=p_supplier_id and company_id=p_company_id) then
    raise exception 'Fornecedor não pertence a esta empresa.';
  end if;

  for v_item in select value from jsonb_array_elements(p_items) order by (value->>'product_id')
  loop
    begin
      v_product_id := (v_item->>'product_id')::uuid;
      v_quantity := (v_item->>'quantity')::numeric;
      v_unit_cost := (v_item->>'unit_cost')::numeric;
    exception when others then
      raise exception 'Produto, quantidade ou custo inválido no recebimento.';
    end;
    if v_product_id = any(v_seen) then raise exception 'Há produto repetido no recebimento.'; end if;
    v_seen := array_append(v_seen,v_product_id);
    if v_quantity is null or v_quantity<=0 or v_unit_cost is null or v_unit_cost<0 then
      raise exception 'Quantidade ou custo inválido.';
    end if;
    select * into v_product from public.products
      where id=v_product_id and company_id=p_company_id and active=true for update;
    if not found then raise exception 'Produto não encontrado ou inativo nesta empresa.'; end if;
    v_total := v_total + round(v_quantity*v_unit_cost,2);
    v_items_count := v_items_count+1;
  end loop;

  insert into public.purchase_orders(company_id,supplier_id,status,total,notes,received_at,created_by)
  values(p_company_id,p_supplier_id,'received',v_total,p_notes,now(),v_user)
  returning * into v_order;

  for v_item in select value from jsonb_array_elements(p_items) order by (value->>'product_id')
  loop
    v_product_id := (v_item->>'product_id')::uuid;
    v_quantity := (v_item->>'quantity')::numeric;
    v_unit_cost := (v_item->>'unit_cost')::numeric;
    select * into v_product from public.products where id=v_product_id and company_id=p_company_id;
    insert into public.purchase_order_items(company_id,purchase_order_id,product_id,quantity,unit_cost,created_by)
    values(p_company_id,v_order.id,v_product_id,v_quantity,v_unit_cost,v_user);
    insert into public.stock_movements(company_id,product_id,movement_type,quantity,unit_cost,note,created_by)
    values(p_company_id,v_product_id,'in',v_quantity,v_unit_cost,'Recebimento da compra #'||v_order.order_number,v_user);
  end loop;

  return jsonb_build_object('id',v_order.id,'order_number',v_order.order_number,'items_count',v_items_count,'total',v_total);
end;
$$;
revoke all on function public.receive_purchase_cart(uuid,uuid,jsonb,text) from public;
grant execute on function public.receive_purchase_cart(uuid,uuid,jsonb,text) to authenticated;


-- ============================================================================
-- SOURCE supabase/migrations/202611080002_finance_links.sql
-- ============================================================================
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


-- ============================================================================
-- SOURCE supabase/migrations/202611080003_protect_linked_finance.sql
-- ============================================================================
-- Protege no banco os lancamentos financeiros originados por vendas e compras.
-- Permite alterar somente a situacao e a data de pagamento; bloqueia exclusao.
create or replace function public.protect_linked_financial_entry()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.source_type is not null and old.source_id is not null then
    if tg_op = 'DELETE' then
      raise exception 'Este lancamento esta vinculado a uma venda ou compra e nao pode ser excluido.';
    end if;

    if new.status not in ('pending', 'paid') then
      raise exception 'Lancamentos vinculados so podem ficar pendentes ou pagos.';
    end if;

    if new.id is distinct from old.id
      or new.company_id is distinct from old.company_id
      or new.entry_type is distinct from old.entry_type
      or new.description is distinct from old.description
      or new.category is distinct from old.category
      or new.amount is distinct from old.amount
      or new.due_date is distinct from old.due_date
      or new.payment_method is distinct from old.payment_method
      or new.notes is distinct from old.notes
      or new.created_by is distinct from old.created_by
      or new.source_type is distinct from old.source_type
      or new.source_id is distinct from old.source_id then
      raise exception 'Os dados deste lancamento sao controlados pela venda ou compra de origem.';
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

revoke all on function public.protect_linked_financial_entry() from public;

drop trigger if exists protect_linked_financial_entry on public.financial_entries;
create trigger protect_linked_financial_entry
before update or delete on public.financial_entries
for each row execute function public.protect_linked_financial_entry();


-- ============================================================================
-- SOURCE supabase/migrations/202611090001_integrity_hardening.sql
-- ============================================================================
-- G.E.I360 — hardening de integridade operacional
-- Permite zerar o estoque em ajustes e impede alterações diretas em campos controlados.

-- Entrada/saída exigem quantidade positiva; ajuste pode definir saldo zero.
alter table public.stock_movements
  drop constraint if exists stock_movements_quantity_check;

alter table public.stock_movements
  drop constraint if exists stock_movements_quantity_valid_check;

alter table public.stock_movements
  add constraint stock_movements_quantity_valid_check
  check (
    (movement_type = 'adjustment' and quantity >= 0)
    or (movement_type in ('in','out') and quantity > 0)
  );

-- O saldo nasce em zero e só pode mudar por meio de movimentações validadas e seus triggers.
revoke insert, update on table public.products from authenticated;
grant insert (
  company_id, name, sku, barcode, category, unit,
  cost_price, sale_price, min_stock, active, created_by
) on table public.products to authenticated;
grant update (
  name, sku, barcode, category, unit,
  cost_price, sale_price, min_stock, active
) on table public.products to authenticated;

-- Vínculos de origem do financeiro são preenchidos exclusivamente pelos triggers.
revoke insert, update on table public.financial_entries from authenticated;
grant insert (
  company_id, entry_type, description, category, amount,
  due_date, status, payment_method, notes, created_by
) on table public.financial_entries to authenticated;
grant update (
  entry_type, description, category, amount, due_date,
  status, payment_method, notes, paid_at
) on table public.financial_entries to authenticated;

-- Funções internas de trigger não precisam ser invocáveis via API.
revoke all on function public.apply_stock_movement() from public, anon, authenticated;
revoke all on function public.create_sale_financial_entry() from public, anon, authenticated;
revoke all on function public.create_purchase_financial_entry() from public, anon, authenticated;
revoke all on function public.protect_linked_financial_entry() from public, anon, authenticated;


-- ============================================================================
-- SOURCE supabase/migrations/202611100001_product_categories.sql
-- ============================================================================
-- G.E.I360 | Categorias por empresa e vínculo seguro com produtos
-- Migration aditiva. Mantém a coluna textual products.category para compatibilidade.
-- Excluir uma categoria usada por produtos é bloqueado; use Inativa no lugar.

do $preflight$
declare missing_count integer;
begin
  if to_regclass('public.companies') is null or to_regclass('public.products') is null then
    raise exception 'G.E.I360: companies ou products não existem. Migração cancelada.';
  end if;
  if to_regprocedure('public.is_company_member(uuid)') is null
     or to_regprocedure('public.has_company_role(uuid,text[])') is null then
    raise exception 'G.E.I360: funções de autorização não encontradas. Migração cancelada.';
  end if;
  select count(*) into missing_count
  from (values ('products','id'),('products','company_id'),('products','category'),('products','created_by')) r(table_name,column_name)
  where not exists (
    select 1 from information_schema.columns c
    where c.table_schema='public' and c.table_name=r.table_name and c.column_name=r.column_name
  );
  if missing_count>0 then
    raise exception 'G.E.I360: faltam % colunas necessárias em products. Migração cancelada.',missing_count;
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='products'
      and column_name='category_id' and data_type<>'uuid'
  ) then
    raise exception 'G.E.I360: products.category_id existe, mas não é UUID. Migração cancelada.';
  end if;
  if exists (
    select 1 from public.products
    where category is not null and btrim(category)<>'' and created_by is null
  ) then
    raise exception 'G.E.I360: há produtos com categoria antiga e created_by nulo. Revise antes de migrar.';
  end if;
end
$preflight$;

create table if not exists public.product_categories (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name text not null,
  description text,
  is_active boolean not null default true,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $schema_check$
declare missing_count integer; duplicate_count integer; invalid_count bigint;
begin
  select count(*) into missing_count
  from (values
    ('product_categories','id'),('product_categories','company_id'),
    ('product_categories','name'),('product_categories','description'),
    ('product_categories','is_active'),('product_categories','created_by'),
    ('product_categories','created_at'),('product_categories','updated_at')
  ) r(table_name,column_name)
  where not exists (
    select 1 from information_schema.columns c
    where c.table_schema='public' and c.table_name=r.table_name and c.column_name=r.column_name
  );
  if missing_count>0 then
    raise exception 'G.E.I360: product_categories tem schema incompatível (% colunas ausentes).',missing_count;
  end if;
  if exists (
    select 1 from public.product_categories
    where company_id is null or name is null or length(btrim(name))=0
       or is_active is null or created_by is null
  ) then
    raise exception 'G.E.I360: product_categories contém registros incompletos. Revise antes da migração.';
  end if;
  select count(*) into duplicate_count
  from (
    select company_id,lower(btrim(name))
    from public.product_categories
    group by company_id,lower(btrim(name))
    having count(*)>1
  ) d;
  if duplicate_count>0 then
    raise exception 'G.E.I360: há % grupos de categorias duplicadas na mesma empresa.',duplicate_count;
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='products' and column_name='category_id'
  ) then
    execute
      'select count(*) from public.products p
       left join public.product_categories pc
         on pc.id=p.category_id and pc.company_id=p.company_id
       where p.category_id is not null and pc.id is null'
      into invalid_count;
    if invalid_count>0 then
      raise exception 'G.E.I360: há % produtos com category_id sem categoria da mesma empresa.',invalid_count;
    end if;
  end if;
end
$schema_check$;

create unique index if not exists product_categories_company_id_id_uidx
  on public.product_categories(company_id,id);
create unique index if not exists product_categories_company_name_uidx
  on public.product_categories(company_id,lower(btrim(name)));
create index if not exists product_categories_company_created_idx
  on public.product_categories(company_id,created_at desc);

do $constraint$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.product_categories'::regclass
      and conname='product_categories_name_not_blank'
  ) then
    alter table public.product_categories
      add constraint product_categories_name_not_blank
      check (length(btrim(name))>0);
  end if;
end
$constraint$;

alter table public.products add column if not exists category_id uuid;

do $foreign_key$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.products'::regclass
      and conname='products_company_category_fk'
  ) then
    alter table public.products
      add constraint products_company_category_fk
      foreign key (company_id,category_id)
      references public.product_categories(company_id,id)
      on delete restrict;
  end if;
end
$foreign_key$;

create index if not exists products_company_category_idx
  on public.products(company_id,category_id);

-- Converte categorias textuais antigas sem apagar o texto original.
insert into public.product_categories(company_id,name,created_by)
select distinct on (p.company_id,lower(btrim(p.category)))
  p.company_id,btrim(p.category),p.created_by
from public.products p
where p.category is not null and btrim(p.category)<>''
  and p.created_by is not null
  and not exists (
    select 1 from public.product_categories pc
    where pc.company_id=p.company_id
      and lower(btrim(pc.name))=lower(btrim(p.category))
  )
order by p.company_id,lower(btrim(p.category)),p.created_at,p.id;

update public.products p
set category_id=pc.id
from public.product_categories pc
where pc.company_id=p.company_id
  and lower(btrim(pc.name))=lower(btrim(p.category))
  and p.category_id is null;

alter table public.product_categories enable row level security;

-- Políticas permissivas de base e guardas restritivas contra permissões antigas mais abertas.
drop policy if exists gei360_categories_member_read on public.product_categories;
create policy gei360_categories_member_read
on public.product_categories for select to authenticated
using (public.is_company_member(company_id));

drop policy if exists gei360_categories_manager_insert on public.product_categories;
create policy gei360_categories_manager_insert
on public.product_categories for insert to authenticated
with check (created_by=(select auth.uid())
  and public.has_company_role(company_id,array['owner','admin','manager']::text[]));

drop policy if exists gei360_categories_manager_update on public.product_categories;
create policy gei360_categories_manager_update
on public.product_categories for update to authenticated
using (public.has_company_role(company_id,array['owner','admin','manager']::text[]))
with check (public.has_company_role(company_id,array['owner','admin','manager']::text[]));

drop policy if exists gei360_categories_admin_delete on public.product_categories;
create policy gei360_categories_admin_delete
on public.product_categories for delete to authenticated
using (public.has_company_role(company_id,array['owner','admin']::text[]));

drop policy if exists gei360_categories_member_guard on public.product_categories;
create policy gei360_categories_member_guard
on public.product_categories as restrictive for all to authenticated
using (public.is_company_member(company_id))
with check (public.is_company_member(company_id));

drop policy if exists gei360_categories_manager_insert_guard on public.product_categories;
create policy gei360_categories_manager_insert_guard
on public.product_categories as restrictive for insert to authenticated
with check (created_by=(select auth.uid())
  and public.has_company_role(company_id,array['owner','admin','manager']::text[]));

drop policy if exists gei360_categories_manager_update_guard on public.product_categories;
create policy gei360_categories_manager_update_guard
on public.product_categories as restrictive for update to authenticated
using (public.has_company_role(company_id,array['owner','admin','manager']::text[]))
with check (public.has_company_role(company_id,array['owner','admin','manager']::text[]));

drop policy if exists gei360_categories_admin_delete_guard on public.product_categories;
create policy gei360_categories_admin_delete_guard
on public.product_categories as restrictive for delete to authenticated
using (public.has_company_role(company_id,array['owner','admin']::text[]));

revoke all on table public.product_categories from anon,public;
grant select,insert,update,delete on table public.product_categories to authenticated;

-- O hardening anterior restringe products por coluna; libera apenas o novo vínculo.
grant insert (category_id) on table public.products to authenticated;
grant update (category_id) on table public.products to authenticated;

create or replace function public.gei360_validate_product_category_company()
returns trigger language plpgsql set search_path=''
as $function$
declare v_name text; v_active boolean;
begin
  -- Compatibilidade: versões antigas ainda podem enviar apenas products.category.
  if new.category_id is null then return new; end if;

  select pc.name,pc.is_active into v_name,v_active
  from public.product_categories pc
  where pc.id=new.category_id and pc.company_id=new.company_id;

  if not found then
    raise exception 'A categoria selecionada não pertence à empresa ativa.';
  end if;

  if not v_active then
    if tg_op='INSERT' then
      raise exception 'Esta categoria está inativa e não pode ser atribuída a um novo produto.';
    elsif new.category_id is distinct from old.category_id then
      raise exception 'Esta categoria está inativa e não pode ser atribuída a um novo produto.';
    end if;
  end if;

  new.category:=v_name;
  return new;
end;
$function$;
revoke all on function public.gei360_validate_product_category_company() from public,anon,authenticated;
drop trigger if exists gei360_products_category_company_guard on public.products;
create trigger gei360_products_category_company_guard
before insert or update on public.products
for each row execute function public.gei360_validate_product_category_company();

-- Renomear categoria sincroniza o rótulo legado dos produtos da mesma empresa.
create or replace function public.gei360_sync_product_category_name()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
  if new.name is distinct from old.name then
    update public.products set category=new.name
    where company_id=new.company_id and category_id=new.id;
  end if;
  return new;
end;
$function$;
revoke all on function public.gei360_sync_product_category_name() from public,anon,authenticated;
drop trigger if exists gei360_product_category_name_sync on public.product_categories;
create trigger gei360_product_category_name_sync
after update of name on public.product_categories
for each row execute function public.gei360_sync_product_category_name();

create or replace function public.gei360_guard_product_category_update()
returns trigger language plpgsql set search_path=''
as $function$
begin
  if new.company_id is distinct from old.company_id then
    raise exception 'Uma categoria não pode ser transferida para outra empresa.';
  end if;
  if new.created_by is distinct from old.created_by then
    raise exception 'O autor original da categoria não pode ser alterado.';
  end if;
  new.updated_at:=now();
  return new;
end;
$function$;
revoke all on function public.gei360_guard_product_category_update() from public,anon,authenticated;
drop trigger if exists gei360_product_category_guard_update on public.product_categories;
create trigger gei360_product_category_guard_update
before update on public.product_categories
for each row execute function public.gei360_guard_product_category_update();


-- ============================================================================
-- SOURCE supabase/migrations/202611100002_company_business_profiles.sql
-- ============================================================================
-- G.E.I360 | Perfil inteligente por ramo e canais comerciais
-- Não armazena tokens de terceiros. Integrações reais exigem backend seguro.

do $preflight$
begin
  if to_regclass('public.companies') is null then
    raise exception 'G.E.I360: tabela companies não encontrada.';
  end if;
  if to_regprocedure('public.is_company_member(uuid)') is null
     or to_regprocedure('public.has_company_role(uuid,text[])') is null then
    raise exception 'G.E.I360: funções de autorização da empresa não encontradas.';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='companies'
      and column_name='id' and data_type='uuid'
  ) then
    raise exception 'G.E.I360: companies.id não é UUID; migração cancelada.';
  end if;
end
$preflight$;

create table if not exists public.company_business_profiles (
  company_id uuid primary key references public.companies(id) on delete cascade,
  business_type text not null default 'other',
  sales_channels text[] not null default '{}'::text[],
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint company_business_profiles_type_check check (
    business_type in ('restaurant','grocery','retail','services','distributor','ecommerce','construction','other')
  ),
  constraint company_business_profiles_channels_check check (
    sales_channels <@ array['ifood','whatsapp','instagram','physical_store','own_delivery','ecommerce','marketplace']::text[]
  )
);

alter table public.company_business_profiles enable row level security;

drop policy if exists gei360_business_profile_member_read on public.company_business_profiles;
create policy gei360_business_profile_member_read
on public.company_business_profiles for select to authenticated
using (public.is_company_member(company_id));

drop policy if exists gei360_business_profile_admin_insert on public.company_business_profiles;
create policy gei360_business_profile_admin_insert
on public.company_business_profiles for insert to authenticated
with check (
  created_by=(select auth.uid())
  and public.has_company_role(company_id,array['owner','admin']::text[])
);

drop policy if exists gei360_business_profile_admin_update on public.company_business_profiles;
create policy gei360_business_profile_admin_update
on public.company_business_profiles for update to authenticated
using (public.has_company_role(company_id,array['owner','admin']::text[]))
with check (public.has_company_role(company_id,array['owner','admin']::text[]));

revoke all on public.company_business_profiles from public, anon, authenticated;
grant select on public.company_business_profiles to authenticated;
grant insert (company_id,business_type,sales_channels,created_by) on public.company_business_profiles to authenticated;
grant update (business_type,sales_channels) on public.company_business_profiles to authenticated;

create or replace function public.gei360_set_business_profile_updated_at()
returns trigger
language plpgsql
set search_path = public
as $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;

revoke all on function public.gei360_set_business_profile_updated_at() from public, anon, authenticated;
drop trigger if exists gei360_business_profile_updated_at on public.company_business_profiles;
create trigger gei360_business_profile_updated_at
before update on public.company_business_profiles
for each row execute function public.gei360_set_business_profile_updated_at();


-- ============================================================================
-- SOURCE supabase/migrations/202611100003_product_barcode_integrity.sql
-- ============================================================================
-- G.E.I360 | Integridade de códigos de barras por empresa
-- Protege o catálogo contra códigos duplicados sem alterar os códigos existentes.

do $preflight$
declare duplicate_groups bigint;
begin
  if to_regclass('public.products') is null then
    raise exception 'G.E.I360: tabela products não encontrada.';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='products' and column_name='company_id'
  ) or not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='products' and column_name='barcode'
  ) then
    raise exception 'G.E.I360: products.company_id ou products.barcode não existe.';
  end if;

  select count(*) into duplicate_groups
  from (
    select company_id,btrim(barcode)
    from public.products
    where barcode is not null and btrim(barcode)<>''
    group by company_id,btrim(barcode)
    having count(*)>1
  ) d;

  if duplicate_groups>0 then
    raise exception 'G.E.I360: existem % grupos de códigos de barras duplicados na mesma empresa. Use o diagnóstico antes de executar.',duplicate_groups;
  end if;
end
$preflight$;

create unique index if not exists products_company_barcode_uidx
  on public.products(company_id,btrim(barcode))
  where barcode is not null and btrim(barcode)<>'';

create or replace function public.gei360_normalize_product_barcode()
returns trigger
language plpgsql
set search_path=''
as $function$
begin
  if new.barcode is not null then
    new.barcode:=nullif(btrim(new.barcode),'');
  end if;
  return new;
end;
$function$;

revoke all on function public.gei360_normalize_product_barcode() from public,anon,authenticated;
drop trigger if exists gei360_products_barcode_normalize on public.products;
create trigger gei360_products_barcode_normalize
before insert or update of barcode on public.products
for each row execute function public.gei360_normalize_product_barcode();


-- ============================================================================
-- SOURCE supabase/migrations/202611110001_employee_integrity.sql
-- ============================================================================
-- G.E.I360 | Integridade e isolamento do cadastro de funcionários
-- Migration aditiva: não altera registros existentes e não cria usuários de login.

do $preflight$
begin
  if to_regclass('public.employees') is null then
    raise exception 'G.E.I360: tabela employees não encontrada. Migração cancelada.';
  end if;
  if to_regprocedure('public.is_company_member(uuid)') is null
     or to_regprocedure('public.has_company_role(uuid,text[])') is null then
    raise exception 'G.E.I360: funções de autorização da empresa não encontradas.';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='employees' and column_name='company_id'
  ) or not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='employees' and column_name='created_by'
  ) then
    raise exception 'G.E.I360: employees não possui company_id e created_by. Migração cancelada.';
  end if;
end
$preflight$;

-- Impede transferir um funcionário para outra empresa ou trocar o autor original.
-- Atualiza updated_at automaticamente em edições futuras.
create or replace function public.gei360_guard_employee_integrity()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if new.company_id is distinct from old.company_id then
    raise exception 'O funcionário não pode ser transferido para outra empresa.';
  end if;
  if new.created_by is distinct from old.created_by then
    raise exception 'O autor original do cadastro não pode ser alterado.';
  end if;
  new.updated_at := now();
  return new;
end;
$function$;

revoke all on function public.gei360_guard_employee_integrity() from public, anon, authenticated;
drop trigger if exists gei360_employee_integrity_guard on public.employees;
create trigger gei360_employee_integrity_guard
before update on public.employees
for each row execute function public.gei360_guard_employee_integrity();

-- Políticas restritivas: políticas permissivas antigas não podem ampliar acesso.
drop policy if exists gei360_employees_member_guard on public.employees;
create policy gei360_employees_member_guard
on public.employees as restrictive for all to authenticated
using (public.is_company_member(company_id))
with check (public.is_company_member(company_id));

drop policy if exists gei360_employees_insert_guard on public.employees;
create policy gei360_employees_insert_guard
on public.employees as restrictive for insert to authenticated
with check (
  created_by = (select auth.uid())
  and public.has_company_role(company_id,array['owner','admin','manager']::text[])
);

drop policy if exists gei360_employees_update_guard on public.employees;
create policy gei360_employees_update_guard
on public.employees as restrictive for update to authenticated
using (public.has_company_role(company_id,array['owner','admin','manager']::text[]))
with check (
  public.is_company_member(company_id)
  and public.has_company_role(company_id,array['owner','admin','manager']::text[])
);

drop policy if exists gei360_employees_delete_guard on public.employees;
create policy gei360_employees_delete_guard
on public.employees as restrictive for delete to authenticated
using (public.has_company_role(company_id,array['owner','admin']::text[]));


-- ============================================================================
-- SOURCE supabase/migrations/202611120001_api_privilege_hardening.sql
-- ============================================================================
-- G.E.I360 | Hardening consolidado de privilégios da API
-- Revisado a partir do relatório de ACL de 2026-11-11.
-- Remove acesso anon/PUBLIC às tabelas empresariais e privilégios estruturais
-- desnecessários de authenticated. Preserva SELECT/DML já concedidos a
-- authenticated; RLS e políticas continuam sendo a camada de autorização por empresa.
-- NÃO remove dados, tabelas, policies ou memberships.

do $table_privileges$
declare
  t text;
  column_list text;
  tables_to_secure text[] := array[
    'companies','company_members','company_modules','profiles','empresas',
    'employees','customers','suppliers','products','product_categories',
    'stock_movements','sales','sale_items','purchase_orders',
    'purchase_order_items','financial_entries','business_documents',
    'gei_module_catalog','gei_records','company_business_profiles'
  ];
begin
  foreach t in array tables_to_secure loop
    if to_regclass('public.'||t) is not null then
      execute format('revoke all privileges on table public.%I from anon, public',t);
      -- Também remove eventuais concessões por coluna (SELECT/INSERT/UPDATE/REFERENCES),
      -- que não devem sobreviver ao bloqueio de privilégios no nível da tabela.
      select string_agg(quote_ident(column_name), ', ' order by ordinal_position)
        into column_list
      from information_schema.columns
      where table_schema='public' and table_name=t;
      if column_list is not null then
        execute format(
          'revoke all (%1$s) on table public.%2$I from anon, public',
          column_list,t
        );
      end if;
      -- Usuários autenticados não precisam de poderes para esvaziar tabelas,
      -- criar triggers, criar referências ou executar manutenção estrutural.
      execute format(
        'revoke truncate, references, trigger, maintain on table public.%I from authenticated',
        t
      );
    end if;
  end loop;
end
$table_privileges$;

-- Helpers usados por policies: somente usuários autenticados podem invocá-los.
do $helpers$
begin
  if to_regprocedure('public.is_company_member(uuid)') is not null then
    revoke all on function public.is_company_member(uuid) from public, anon;
    grant execute on function public.is_company_member(uuid) to authenticated;
  end if;
  if to_regprocedure('public.has_company_role(uuid,text[])') is not null then
    revoke all on function public.has_company_role(uuid,text[]) from public, anon;
    grant execute on function public.has_company_role(uuid,text[]) to authenticated;
  end if;
end
$helpers$;

-- RPCs operacionais: sem execução anônima; authenticated conserva o acesso
-- necessário ao frontend. A própria função valida auth.uid(), empresa e cargo.
do $rpcs$
begin
  if to_regprocedure('public.record_stock_movement(uuid,uuid,text,numeric,numeric,text)') is not null then
    revoke all on function public.record_stock_movement(uuid,uuid,text,numeric,numeric,text) from public, anon;
    grant execute on function public.record_stock_movement(uuid,uuid,text,numeric,numeric,text) to authenticated;
  end if;
  if to_regprocedure('public.create_sale(uuid,uuid,uuid,numeric,numeric,text)') is not null then
    revoke all on function public.create_sale(uuid,uuid,uuid,numeric,numeric,text) from public, anon;
    grant execute on function public.create_sale(uuid,uuid,uuid,numeric,numeric,text) to authenticated;
  end if;
  if to_regprocedure('public.create_sale_cart(uuid,uuid,jsonb,numeric,text)') is not null then
    revoke all on function public.create_sale_cart(uuid,uuid,jsonb,numeric,text) from public, anon;
    grant execute on function public.create_sale_cart(uuid,uuid,jsonb,numeric,text) to authenticated;
  end if;
  if to_regprocedure('public.receive_purchase(uuid,uuid,uuid,numeric,numeric,text)') is not null then
    revoke all on function public.receive_purchase(uuid,uuid,uuid,numeric,numeric,text) from public, anon;
    grant execute on function public.receive_purchase(uuid,uuid,uuid,numeric,numeric,text) to authenticated;
  end if;
  if to_regprocedure('public.receive_purchase_cart(uuid,uuid,jsonb,text)') is not null then
    revoke all on function public.receive_purchase_cart(uuid,uuid,jsonb,text) from public, anon;
    grant execute on function public.receive_purchase_cart(uuid,uuid,jsonb,text) to authenticated;
  end if;
end
$rpcs$;

-- Funções executadas apenas por triggers. Não são endpoints RPC do aplicativo.
do $trigger_functions$
declare
  signature text;
  signatures text[] := array[
    'public.apply_stock_movement()',
    'public.create_sale_financial_entry()',
    'public.create_purchase_financial_entry()',
    'public.protect_linked_financial_entry()',
    'public.gei360_validate_product_category_company()',
    'public.gei360_sync_product_category_name()',
    'public.gei360_guard_product_category_update()',
    'public.gei360_guard_employee_integrity()',
    'public.gei360_normalize_product_barcode()',
    'public.gei360_set_business_profile_updated_at()',
    'public.handle_new_company_owner()',
    'public.handle_new_user()'
  ];
begin
  foreach signature in array signatures loop
    if to_regprocedure(signature) is not null then
      execute format('revoke all on function %s from public, anon, authenticated',signature);
    end if;
  end loop;
end
$trigger_functions$;

-- Pós-verificação somente leitura: deve retornar zero linhas.
select grantee,table_name,privilege_type
from information_schema.table_privileges
where table_schema='public'
  and grantee='anon'
  and table_name in (
    'companies','company_members','company_modules','profiles','empresas',
    'employees','customers','suppliers','products','product_categories',
    'stock_movements','sales','sale_items','purchase_orders',
    'purchase_order_items','financial_entries','business_documents',
    'gei_module_catalog','gei_records','company_business_profiles'
  )
order by table_name,privilege_type;

-- authenticated não deve possuir TRUNCATE, REFERENCES, TRIGGER ou MAINTAIN
-- nas tabelas empresariais. O acesso a linhas continua dependendo de RLS.
select grantee,table_name,privilege_type
from information_schema.table_privileges
where table_schema='public'
  and grantee='authenticated'
  and privilege_type in ('TRUNCATE','REFERENCES','TRIGGER','MAINTAIN')
  and table_name in (
    'companies','company_members','company_modules','profiles','empresas',
    'employees','customers','suppliers','products','product_categories',
    'stock_movements','sales','sale_items','purchase_orders',
    'purchase_order_items','financial_entries','business_documents',
    'gei_module_catalog','gei_records','company_business_profiles'
  )
order by table_name,privilege_type;

commit;

-- Verificação final resumida (somente leitura).
select grantee,table_name,privilege_type
from information_schema.table_privileges
where table_schema='public'
  and grantee='anon'
  and table_name in (
    'companies','company_members','company_modules','profiles','empresas',
    'employees','customers','suppliers','products','product_categories',
    'stock_movements','sales','sale_items','purchase_orders',
    'purchase_order_items','financial_entries','business_documents',
    'gei_module_catalog','gei_records','company_business_profiles'
  )
order by table_name,privilege_type;

select grantee,table_name,privilege_type
from information_schema.table_privileges
where table_schema='public'
  and grantee='authenticated'
  and privilege_type in ('TRUNCATE','REFERENCES','TRIGGER','MAINTAIN')
  and table_name in (
    'companies','company_members','company_modules','profiles','empresas',
    'employees','customers','suppliers','products','product_categories',
    'stock_movements','sales','sale_items','purchase_orders',
    'purchase_order_items','financial_entries','business_documents',
    'gei_module_catalog','gei_records','company_business_profiles'
  )
order by table_name,privilege_type;
