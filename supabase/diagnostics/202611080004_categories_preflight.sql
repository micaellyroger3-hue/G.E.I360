-- G.E.I360 | Diagnóstico completo de Cadastros e pré-requisitos de Categorias
-- SOMENTE LEITURA: não cria, altera ou exclui tabelas, políticas ou registros.
-- Execute antes das migrações no projeto Supabase correto.

-- 1. Tabelas e estado de RLS
select
  v.table_name,
  to_regclass('public.' || v.table_name) is not null as existe,
  coalesce(c.relrowsecurity, false) as rls_ativa,
  coalesce(c.relforcerowsecurity, false) as rls_forcada
from (values
  ('companies'),
  ('company_members'),
  ('customers'),
  ('suppliers'),
  ('products'),
  ('product_categories')
) as v(table_name)
left join pg_class c
  on c.oid = to_regclass('public.' || v.table_name)
order by v.table_name;

-- 2. Colunas necessárias para os cadastros e para a migração de categorias
with expected(table_name, column_name, required_before_categories_migration) as (
  values
    ('customers','id',true),
    ('customers','company_id',true),
    ('customers','name',true),
    ('customers','document',true),
    ('customers','email',true),
    ('customers','phone',true),
    ('customers','address',true),
    ('customers','created_by',true),
    ('customers','created_at',true),
    ('customers','updated_at',true),

    ('suppliers','id',true),
    ('suppliers','company_id',true),
    ('suppliers','name',true),
    ('suppliers','document',true),
    ('suppliers','email',true),
    ('suppliers','phone',true),
    ('suppliers','notes',true),
    ('suppliers','created_by',true),
    ('suppliers','created_at',true),
    ('suppliers','updated_at',true),

    ('products','id',true),
    ('products','company_id',true),
    ('products','name',true),
    ('products','sku',true),
    ('products','barcode',true),
    ('products','category',true),
    ('products','unit',true),
    ('products','cost_price',true),
    ('products','sale_price',true),
    ('products','stock_quantity',true),
    ('products','min_stock',true),
    ('products','active',true),
    ('products','created_by',true),
    ('products','created_at',true),
    ('products','updated_at',true),

    ('product_categories','id',false),
    ('product_categories','company_id',false),
    ('product_categories','name',false),
    ('product_categories','description',false),
    ('product_categories','is_active',false),
    ('product_categories','created_by',false),
    ('product_categories','created_at',false),
    ('product_categories','updated_at',false)
)
select
  e.table_name,
  e.column_name,
  e.required_before_categories_migration,
  (c.column_name is not null) as existe,
  c.data_type,
  c.is_nullable
from expected e
left join information_schema.columns c
  on c.table_schema = 'public'
 and c.table_name = e.table_name
 and c.column_name = e.column_name
order by e.table_name, e.column_name;

-- 3. Políticas RLS existentes
select
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
from pg_policies
where schemaname = 'public'
  and tablename in (
    'companies',
    'company_members',
    'customers',
    'suppliers',
    'products',
    'product_categories'
  )
order by tablename, policyname;

-- 4. Funções de autorização exigidas pelo aplicativo e pela migração
select
  'is_company_member(uuid)' as assinatura,
  to_regprocedure('public.is_company_member(uuid)') is not null as existe
union all
select
  'has_company_role(uuid,text[])',
  to_regprocedure('public.has_company_role(uuid,text[])') is not null;

-- 5. Verificações de dados legados
-- O bloco apenas consulta e emite NOTICE; não altera nenhum registro.
do $
declare
  affected_count bigint;
begin
  if to_regclass('public.products') is not null
     and exists (
       select 1 from information_schema.columns
       where table_schema='public'
         and table_name='products'
         and column_name='created_by'
     )
     and exists (
       select 1 from information_schema.columns
       where table_schema='public'
         and table_name='products'
         and column_name='category'
     ) then
    execute
      'select count(*) from public.products
       where category is not null and btrim(category) <> ''''
         and created_by is null'
      into affected_count;
    raise notice 'Produtos com categoria preenchida e created_by nulo: %', affected_count;
  end if;

  if to_regclass('public.product_categories') is not null then
    execute
      'select count(*) from (
         select company_id, lower(btrim(name))
         from public.product_categories
         group by company_id, lower(btrim(name))
         having count(*) > 1
       ) duplicate_groups'
      into affected_count;
    raise notice 'Grupos de categorias duplicadas na mesma empresa: %', affected_count;
  end if;
end
$;

-- 6. Relacionamentos de empresa e categoria
select
  tc.table_name,
  kcu.column_name,
  ccu.table_name as tabela_referenciada,
  ccu.column_name as coluna_referenciada,
  tc.constraint_name
from information_schema.table_constraints tc
join information_schema.key_column_usage kcu
  on tc.constraint_name = kcu.constraint_name
 and tc.constraint_schema = kcu.constraint_schema
join information_schema.constraint_column_usage ccu
  on ccu.constraint_name = tc.constraint_name
 and ccu.constraint_schema = tc.constraint_schema
where tc.constraint_type = 'FOREIGN KEY'
  and tc.table_schema = 'public'
  and tc.table_name in (
    'customers',
    'suppliers',
    'products',
    'product_categories'
  )
order by tc.table_name, kcu.column_name;
