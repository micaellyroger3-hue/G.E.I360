-- G.E.I360 | Pré-check final consolidado (SOMENTE LEITURA)
-- Rode uma única vez no SQL Editor do projeto Supabase correto.
-- Não cria, altera ou apaga tabelas, registros, permissões ou políticas.
-- O resultado orienta a aplicação das migrations; SQL Editor não prova RLS via API.

-- 1) Estrutura e RLS das tabelas empresariais.
with expected(table_name) as (
  values
  ('companies'),('company_members'),('company_modules'),('profiles'),('empresas'),
  ('employees'),('customers'),('suppliers'),('products'),('product_categories'),
  ('stock_movements'),('sales'),('sale_items'),('purchase_orders'),
  ('purchase_order_items'),('financial_entries'),('business_documents'),
  ('gei_module_catalog'),('gei_records'),('company_business_profiles')
)
select e.table_name,
       c.oid is not null as exists,
       coalesce(c.relrowsecurity,false) as rls_enabled,
       coalesce(c.relforcerowsecurity,false) as force_rls,
       case when c.oid is null then 'MISSING'
            when not c.relrowsecurity then 'RLS DISABLED'
            else 'RLS ENABLED' end as status
from expected e
left join pg_class c on c.oid=to_regclass('public.'||e.table_name)
order by e.table_name;

-- 2) Privilégios de tabela por papel: destaque anon/PUBLIC e privilégios estruturais.
select grantee,table_name,privilege_type
from information_schema.table_privileges
where table_schema='public'
  and table_name in (
    'companies','company_members','company_modules','profiles','empresas',
    'employees','customers','suppliers','products','product_categories',
    'stock_movements','sales','sale_items','purchase_orders',
    'purchase_order_items','financial_entries','business_documents',
    'gei_module_catalog','gei_records','company_business_profiles'
  )
  and grantee in ('anon','authenticated','PUBLIC')
order by table_name,grantee,privilege_type;

-- 3) Permissões sensíveis por coluna (saldo e origem dos lançamentos financeiros).
select grantee,table_name,column_name,privilege_type
from information_schema.column_privileges
where table_schema='public'
  and (
    (table_name='products' and column_name in ('stock_quantity','company_id','created_by'))
    or (table_name='financial_entries' and column_name in ('source_type','source_id','company_id','created_by'))
    or (table_name='employees' and column_name in ('company_id','created_by'))
  )
order by table_name,column_name,grantee,privilege_type;

-- 4) Todas as políticas RLS das tabelas empresariais.
select schemaname,tablename,policyname,permissive,roles,cmd,qual,with_check
from pg_policies
where schemaname='public'
  and tablename in (
    'companies','company_members','company_modules','profiles','empresas',
    'employees','customers','suppliers','products','product_categories',
    'stock_movements','sales','sale_items','purchase_orders',
    'purchase_order_items','financial_entries','business_documents',
    'gei_module_catalog','gei_records','company_business_profiles'
  )
order by tablename,policyname;

-- 5) Funções de autorização, RPCs e SECURITY DEFINER: search_path e ACL.
select n.nspname as schema_name,p.proname as function_name,
       pg_get_function_identity_arguments(p.oid) as arguments,
       p.prosecdef as security_definer,p.proconfig as function_settings,
       p.proacl as acl,pg_get_functiondef(p.oid) as definition
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
  and p.proname in (
    'is_company_member','has_company_role','handle_new_company_owner','handle_new_user',
    'record_stock_movement','create_sale','create_sale_cart','receive_purchase',
    'receive_purchase_cart','apply_stock_movement','create_sale_financial_entry',
    'create_purchase_financial_entry','protect_linked_financial_entry',
    'gei360_validate_product_category_company','gei360_sync_product_category_name',
    'gei360_guard_product_category_update','gei360_guard_employee_integrity',
    'gei360_normalize_product_barcode','gei360_set_business_profile_updated_at'
  )
order by p.proname,arguments;

-- 6) Triggeres ligados aos fluxos operacionais.
select event_object_table as table_name,trigger_name,action_timing,
       event_manipulation,action_statement
from information_schema.triggers
where trigger_schema='public'
  and event_object_table in (
    'companies','employees','products','stock_movements','sales',
    'purchase_orders','financial_entries','product_categories','company_business_profiles'
  )
order by event_object_table,trigger_name;

-- 7) Restrições e índices que sustentam isolamento e integridade.
select conrelid::regclass as table_name,conname,contype,pg_get_constraintdef(oid) as definition
from pg_constraint
where connamespace='public'::regnamespace
  and conrelid::regclass::text in (
    'public.company_members','public.products','public.product_categories',
    'public.sales','public.sale_items','public.purchase_orders',
    'public.purchase_order_items','public.financial_entries','public.employees'
  )
order by table_name,conname;

select schemaname,tablename,indexname,indexdef
from pg_indexes
where schemaname='public'
  and tablename in ('company_members','products','product_categories','financial_entries')
order by tablename,indexname;

-- 8) Bucket de documentos: precisa ser privado.
select id,name,public,file_size_limit,allowed_mime_types
from storage.buckets
where id='company-documents';

-- 9) Resumo de volumes sem expor conteúdo empresarial.
select 'companies' as table_name,count(*) as total from public.companies
union all select 'company_members',count(*) from public.company_members
union all select 'employees',count(*) from public.employees
union all select 'customers',count(*) from public.customers
union all select 'suppliers',count(*) from public.suppliers
union all select 'products',count(*) from public.products
union all select 'sales',count(*) from public.sales
union all select 'purchase_orders',count(*) from public.purchase_orders
union all select 'financial_entries',count(*) from public.financial_entries
union all select 'business_documents',count(*) from public.business_documents
order by table_name;

-- Limites importantes:
-- * Se alguma tabela opcional não existir, o primeiro relatório a identifica.
-- * O diagnóstico não corrige nada e não comprova isolamento de usuários.
-- * A prova real de isolamento exige duas contas autenticadas, duas empresas e
--   requisições API tentando ler e escrever dados cruzados.
-- * Não execute migrations se houver tabela/coluna/função ausente ou schema incompatível.
