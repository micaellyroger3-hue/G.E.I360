-- G.E.I360 | Categorias de produtos por empresa
-- Migração aditiva: cria apenas a tabela e as políticas do módulo Categorias.
-- Não altera nem apaga dados de clientes, fornecedores, produtos ou outras áreas.

begin;

do $$
begin
  if to_regclass('public.companies') is null then
    raise exception 'G.E.I360: tabela public.companies não encontrada. Migração cancelada.';
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

grant select, insert, update, delete on public.product_categories to authenticated;

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
