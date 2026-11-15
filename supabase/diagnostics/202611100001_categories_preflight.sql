-- G.E.I360 | Diagnóstico de Cadastros e Categorias
-- SOMENTE LEITURA. Não altera tabelas, políticas, permissões ou registros.

-- 1. Tabelas e estado de RLS
select v.table_name,
       to_regclass('public.'||v.table_name) is not null as existe,
       coalesce(c.relrowsecurity,false) as rls_ativa,
       coalesce(c.relforcerowsecurity,false) as rls_forcada
from (values ('companies'),('company_members'),('customers'),('suppliers'),('products'),('product_categories')) v(table_name)
left join pg_class c on c.oid=to_regclass('public.'||v.table_name)
order by v.table_name;

-- 2. Colunas necessárias
select table_name,column_name,data_type,is_nullable,column_default
from information_schema.columns
where table_schema='public'
  and table_name in ('customers','suppliers','products','product_categories')
order by table_name,ordinal_position;

-- 3. Definições reais das funções de autorização
select p.proname,pg_get_function_identity_arguments(p.oid) as argumentos,pg_get_functiondef(p.oid) as definicao
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname in ('is_company_member','has_company_role')
order by p.proname;

-- 4. Políticas RLS atuais
select tablename,policyname,permissive,roles,cmd,qual,with_check
from pg_policies
where schemaname='public' and tablename in ('customers','suppliers','products','product_categories')
order by tablename,policyname;

-- 5. Resumo de produtos, sem expor dados pessoais
do $check$
declare n bigint;
begin
  if to_regclass('public.products') is not null then
    execute 'select count(*) from public.products where category is not null and btrim(category)<>''' into n;
    raise notice 'Produtos com categoria textual: %',n;
    if exists(select 1 from information_schema.columns where table_schema='public' and table_name='products' and column_name='category_id') then
      execute 'select count(*) from public.products where category_id is not null' into n;
      raise notice 'Produtos com category_id: %',n;
    end if;
  else
    raise notice 'Tabela public.products não encontrada.';
  end if;

  if to_regclass('public.product_categories') is not null then
    execute 'select count(*) from (select company_id,lower(btrim(name)) from public.product_categories group by company_id,lower(btrim(name)) having count(*)>1) d' into n;
    raise notice 'Grupos de categorias duplicadas por empresa: %',n;
    if to_regclass('public.products') is not null and exists(select 1 from information_schema.columns where table_schema='public' and table_name='products' and column_name='category_id') then
      execute 'select count(*) from public.products p left join public.product_categories pc on pc.id=p.category_id and pc.company_id=p.company_id where p.category_id is not null and pc.id is null' into n;
      raise notice 'Vínculos category_id inválidos ou de outra empresa: %',n;
    end if;
  else
    raise notice 'Tabela public.product_categories ainda não existe; a migration irá criá-la.';
  end if;
end
$check$;

-- 6. Relacionamentos e privilégios, apenas quando as tabelas existem
select tc.table_name,kcu.column_name,ccu.table_name as tabela_referenciada,ccu.column_name as coluna_referenciada,tc.constraint_name
from information_schema.table_constraints tc
join information_schema.key_column_usage kcu on tc.constraint_name=kcu.constraint_name and tc.constraint_schema=kcu.constraint_schema
join information_schema.constraint_column_usage ccu on ccu.constraint_name=tc.constraint_name and ccu.constraint_schema=tc.constraint_schema
where tc.constraint_type='FOREIGN KEY' and tc.table_schema='public'
  and tc.table_name in ('products','product_categories')
order by tc.table_name,kcu.column_name;

do $privileges$
begin
  if to_regclass('public.products') is not null and to_regclass('public.product_categories') is not null then
    raise notice 'authenticated INSERT category_id: %',
      has_column_privilege('authenticated','public.products','category_id','INSERT');
    raise notice 'authenticated UPDATE category_id: %',
      has_column_privilege('authenticated','public.products','category_id','UPDATE');
    raise notice 'anon SELECT product_categories: %',
      has_table_privilege('anon','public.product_categories','SELECT');
  end if;
end
$privileges$;
