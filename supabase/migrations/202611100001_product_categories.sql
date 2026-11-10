-- G.E.I360 | Categorias por empresa e vínculo seguro com produtos
-- Migration aditiva. Mantém a coluna textual products.category para compatibilidade.
-- Excluir uma categoria usada por produtos é bloqueado; use Inativa no lugar.
begin;

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

create or replace function public.gei360_validate_product_category()
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
revoke all on function public.gei360_validate_product_category() from public,anon,authenticated;
drop trigger if exists gei360_products_category_guard on public.products;
create trigger gei360_products_category_guard
before insert or update on public.products
for each row execute function public.gei360_validate_product_category();

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
drop trigger if exists gei360_product_category_update_guard on public.product_categories;
create trigger gei360_product_category_update_guard
before update on public.product_categories
for each row execute function public.gei360_guard_product_category_update();

commit;
