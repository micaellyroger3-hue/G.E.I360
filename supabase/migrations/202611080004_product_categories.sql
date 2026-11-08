-- G.E.I360 | Categorias de produtos por empresa
-- Migração aditiva: cria apenas a tabela e as políticas do módulo Categorias.
-- Não altera nem apaga dados de clientes, fornecedores, produtos ou outras áreas.

begin;

do $$
begin
  if to_regclass('public.companies') is null then
    raise exception 'G.E.I360: tabela public.companies não encontrada. Migração cancelada.';
  end if;
  if to_regclass('public.products') is null then
    raise exception 'G.E.I360: tabela public.products não encontrada. Aplique primeiro a migração ERP. Migração cancelada.';
  end if;
  if to_regprocedure('public.is_company_member(uuid)') is null then
    raise exception 'G.E.I360: função public.is_company_member(uuid) não encontrada. Migração cancelada.';
  end if;
  if to_regprocedure('public.has_company_role(uuid,text[])') is null then
    raise exception 'G.E.I360: função public.has_company_role(uuid,text[]) não encontrada. Migração cancelada.';
  end if;
end
$$;

create table if not exists public.product_categories (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name text not null check (length(btrim(name)) > 0),
  description text,
  is_active boolean not null default true,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $gei$
declare
  missing_count integer;
begin
  select count(*) into missing_count
  from (values
    ('product_categories','id'),
    ('product_categories','company_id'),
    ('product_categories','name'),
    ('product_categories','description'),
    ('product_categories','is_active'),
    ('product_categories','created_by'),
    ('product_categories','created_at'),
    ('product_categories','updated_at'),
    ('products','company_id'),
    ('products','category'),
    ('products','created_by')
  ) as expected(table_name,column_name)
  where not exists (
    select 1 from information_schema.columns c
    where c.table_schema='public'
      and c.table_name=expected.table_name
      and c.column_name=expected.column_name
  );

  if missing_count > 0 then
    raise exception 'G.E.I360: faltam % coluna(s) esperadas para Categorias. Migração cancelada.', missing_count;
  end if;
end
$gei$;

create unique index if not exists product_categories_company_name_uidx
  on public.product_categories(company_id, lower(btrim(name)));
create index if not exists product_categories_company_created_idx
  on public.product_categories(company_id, created_at desc);

alter table public.product_categories enable row level security;

drop policy if exists product_categories_member_read on public.product_categories;
create policy product_categories_member_read
on public.product_categories
for select to authenticated
using (public.is_company_member(company_id));

drop policy if exists product_categories_manager_insert on public.product_categories;
create policy product_categories_manager_insert
on public.product_categories
for insert to authenticated
with check (
  created_by = (select auth.uid())
  and public.has_company_role(company_id, array['owner','admin','manager']::text[])
);

drop policy if exists product_categories_manager_update on public.product_categories;
create policy product_categories_manager_update
on public.product_categories
for update to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager']::text[]))
with check (public.has_company_role(company_id, array['owner','admin','manager']::text[]));

drop policy if exists product_categories_admin_delete on public.product_categories;
create policy product_categories_admin_delete
on public.product_categories
for delete to authenticated
using (public.has_company_role(company_id, array['owner','admin']::text[]));

-- Regras RESTRICTIVE também limitam políticas permissivas antigas, caso a tabela já existisse.
drop policy if exists product_categories_member_guard on public.product_categories;
create policy product_categories_member_guard
on public.product_categories as restrictive
for all to authenticated
using (public.is_company_member(company_id))
with check (public.is_company_member(company_id));

drop policy if exists product_categories_manager_insert_guard on public.product_categories;
create policy product_categories_manager_insert_guard
on public.product_categories as restrictive
for insert to authenticated
with check (
  created_by = (select auth.uid())
  and public.has_company_role(company_id, array['owner','admin','manager']::text[])
);

drop policy if exists product_categories_manager_update_guard on public.product_categories;
create policy product_categories_manager_update_guard
on public.product_categories as restrictive
for update to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager']::text[]))
with check (public.has_company_role(company_id, array['owner','admin','manager']::text[]));

drop policy if exists product_categories_admin_delete_guard on public.product_categories;
create policy product_categories_admin_delete_guard
on public.product_categories as restrictive
for delete to authenticated
using (public.has_company_role(company_id, array['owner','admin']::text[]));

revoke all on table public.product_categories from anon, public;
grant select, insert, update, delete on table public.product_categories to authenticated;

-- Liga cada produto a uma categoria da mesma empresa, preservando a coluna textual antiga.
alter table public.products add column if not exists category_id uuid;
do $gei$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.products'::regclass
      and conname = 'products_category_id_fkey'
  ) then
    alter table public.products
      add constraint products_category_id_fkey
      foreign key (category_id) references public.product_categories(id)
      on delete set null;
  end if;
end
$gei$;
create index if not exists products_company_category_idx
  on public.products(company_id, category_id);

-- Migra categorias textuais antigas para a tabela nova sem apagar os valores existentes.
insert into public.product_categories(company_id, name, created_by)
select distinct on (p.company_id, lower(btrim(p.category)))
  p.company_id, btrim(p.category), p.created_by
from public.products p
where p.category is not null
  and btrim(p.category) <> ''
  and not exists (
    select 1
    from public.product_categories pc
    where pc.company_id = p.company_id
      and lower(btrim(pc.name)) = lower(btrim(p.category))
  )
order by p.company_id, lower(btrim(p.category)), p.created_at, p.id;

update public.products p
set category_id = pc.id,
    category = pc.name
from public.product_categories pc
where pc.company_id = p.company_id
  and lower(btrim(pc.name)) = lower(btrim(p.category))
  and p.category_id is null;

create or replace function public.gei360_validate_product_category_company()
returns trigger
language plpgsql
set search_path = ''
as $gei$
declare
  v_category_name text;
  v_category_active boolean;
begin
  if new.category_id is null then
    new.category := null;
    return new;
  end if;

  select pc.name, pc.is_active
    into v_category_name, v_category_active
  from public.product_categories pc
  where pc.id = new.category_id and pc.company_id = new.company_id;

  if not found then
    raise exception 'A categoria selecionada não pertence à empresa ativa.';
  end if;

  if not v_category_active
     and (tg_op = 'INSERT' or new.category_id is distinct from old.category_id) then
    raise exception 'Esta categoria está inativa e não pode ser atribuída a um novo produto.';
  end if;

  new.category := v_category_name;
  return new;
end;
$gei$;
revoke all on function public.gei360_validate_product_category_company() from public;
drop trigger if exists gei360_products_category_company_guard on public.products;
create trigger gei360_products_category_company_guard
before insert or update of company_id, category_id on public.products
for each row execute function public.gei360_validate_product_category_company();

create or replace function public.gei360_sync_product_category_name()
returns trigger
language plpgsql
set search_path = ''
as $gei$
begin
  if new.name is distinct from old.name then
    update public.products
    set category = new.name
    where company_id = new.company_id and category_id = new.id;
  end if;
  return new;
end;
$gei$;
revoke all on function public.gei360_sync_product_category_name() from public;
drop trigger if exists gei360_product_category_name_sync on public.product_categories;
create trigger gei360_product_category_name_sync
after update of name on public.product_categories
for each row execute function public.gei360_sync_product_category_name();

create or replace function public.gei360_guard_product_category_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.company_id is distinct from old.company_id then
    raise exception 'A categoria não pode ser transferida para outra empresa.';
  end if;
  if new.created_by is distinct from old.created_by then
    raise exception 'O criador original da categoria não pode ser alterado.';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function public.gei360_guard_product_category_update() from public;

drop trigger if exists gei360_product_category_guard_update on public.product_categories;
create trigger gei360_product_category_guard_update
before update on public.product_categories
for each row execute function public.gei360_guard_product_category_update();

commit;
