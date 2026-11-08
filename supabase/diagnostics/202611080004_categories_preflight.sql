-- G.E.I360 | Diagnóstico prévio de Categorias
-- SOMENTE LEITURA: não cria, altera ou exclui tabelas, políticas ou registros.

-- 1. Tabelas e estado de RLS
select
  v.table_name,
  to_regclass('public.' || v.table_name) is not null as existe,
  coalesce(c.relrowsecurity, false) as rls_ativa
from (values
  ('companies'),
  ('customers'),
  ('suppliers'),
  ('products'),
  ('product_categories')
) as v(table_name)
left join pg_class c
  on c.oid = to_regclass('public.' || v.table_name)
order by v.table_name;

-- 2. Colunas necessárias para clientes, fornecedores, produtos e categorias
select
  table_name,
  ordinal_position,
  column_name,
  data_type,
  is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name in (
    'customers',
    'suppliers',
    'products',
    'product_categories'
  )
order by table_name, ordinal_position;

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
    'customers',
    'suppliers',
    'products',
    'product_categories'
  )
order by tablename, policyname;

-- 4. Funções de autorização exigidas pela migração
select
  'is_company_member(uuid)' as assinatura,
  to_regprocedure('public.is_company_member(uuid)') is not null as existe
union all
select
  'has_company_role(uuid,text[])',
  to_regprocedure('public.has_company_role(uuid,text[])') is not null;
