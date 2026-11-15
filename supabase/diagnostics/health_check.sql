-- G.E.I360 — diagnóstico somente leitura do Supabase
-- Execute no SQL Editor depois de aplicar as migrations necessárias para o ambiente.
-- Este arquivo NÃO cria, altera ou apaga dados.

with expected(table_name) as (
  values
    ('companies'),('company_members'),('profiles'),('employees'),('product_categories'),
    ('suppliers'),('customers'),('products'),('stock_movements'),
    ('sales'),('sale_items'),('purchase_orders'),('purchase_order_items'),
    ('financial_entries'),('business_documents'),('company_modules'),
    ('gei_module_catalog'),('gei_records')
)
select e.table_name, (c.oid is not null) as exists,
       coalesce(c.relrowsecurity,false) as rls_enabled,
       coalesce(c.relforcerowsecurity,false) as rls_forced
from expected e
left join pg_class c on c.oid = to_regclass('public.' || e.table_name)
order by e.table_name;

select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename in (
    'companies','company_members','profiles','employees','suppliers',
    'customers','product_categories','products','stock_movements','sales','sale_items',
    'purchase_orders','purchase_order_items','financial_entries',
    'business_documents','company_modules','gei_records'
  )
order by tablename, policyname;

with expected(function_name) as (
  values
    ('apply_stock_movement'),('record_stock_movement'),('create_sale'),
    ('receive_purchase'),('create_sale_cart'),('receive_purchase_cart'),
    ('create_sale_financial_entry'),('create_purchase_financial_entry'),
    ('protect_linked_financial_entry'),('gei360_validate_product_category_company'),
    ('gei360_sync_product_category_name'),('gei360_guard_product_category_update')
)
select e.function_name,
       exists (
         select 1 from pg_proc p
         join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'public' and p.proname = e.function_name
       ) as exists
from expected e
order by e.function_name;

select event_object_table as table_name, trigger_name, action_timing,
       event_manipulation, action_statement
from information_schema.triggers
where trigger_schema = 'public'
  and trigger_name in (
    'stock_movement_apply',
    'purchase_create_financial_entry',
    'sales_create_financial_entry',
    'protect_linked_financial_entry',
    'gei360_products_category_company_guard',
    'gei360_product_category_name_sync',
    'gei360_product_category_guard_update'
  )
order by event_object_table, trigger_name;

select id, name, public, file_size_limit, allowed_mime_types
from storage.buckets
where id = 'company-documents';

select 'companies' as table_name, count(*) as total from public.companies
union all select 'company_members', count(*) from public.company_members
union all select 'employees', count(*) from public.employees
union all select 'product_categories', count(*) from public.product_categories
union all select 'products', count(*) from public.products
union all select 'stock_movements', count(*) from public.stock_movements
union all select 'sales', count(*) from public.sales
union all select 'purchase_orders', count(*) from public.purchase_orders
union all select 'financial_entries', count(*) from public.financial_entries
union all select 'business_documents', count(*) from public.business_documents
order by table_name;

-- Interpretação:
-- * Toda tabela esperada deve existir e as tabelas com dados de empresa devem ter RLS.
-- * As funções entregues devem apresentar exists = true.
-- * O bucket company-documents deve aparecer com public = false.
-- * Contagem zero não é falha por si só; pode não haver registros de teste.
-- * SQL Editor usa privilégios administrativos; isso NÃO comprova isolamento entre usuários.
--   O isolamento exige dois usuários autenticados em empresas diferentes, testados pela API.


-- Hardening da migration 202611090001_integrity_hardening.sql
select
  has_column_privilege('authenticated','public.products','stock_quantity','UPDATE') as autenticado_pode_alterar_saldo_diretamente,
  has_column_privilege('authenticated','public.financial_entries','source_type','INSERT') as autenticado_pode_definir_origem_financeira_no_insert,
  has_column_privilege('authenticated','public.financial_entries','source_type','UPDATE') as autenticado_pode_alterar_origem_financeira;

select
  p.proname as funcao_de_trigger,
  has_function_privilege('anon',p.oid,'EXECUTE') as anon_pode_executar,
  has_function_privilege('authenticated',p.oid,'EXECUTE') as autenticado_pode_executar
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
  and p.proname in (
    'apply_stock_movement',
    'create_sale_financial_entry',
    'create_purchase_financial_entry',
    'protect_linked_financial_entry',
    'gei360_products_category_company_guard',
    'gei360_product_category_name_sync',
    'gei360_product_category_guard_update'
  )
order by p.proname;

select conname, pg_get_constraintdef(oid) as regra
from pg_constraint
where conrelid='public.stock_movements'::regclass
  and conname='stock_movements_quantity_valid_check';
