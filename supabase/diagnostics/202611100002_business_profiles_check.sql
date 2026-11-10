-- G.E.I360 | Perfil empresarial e canais
-- Diagnóstico somente leitura. Não cria nem altera dados.

select to_regclass('public.company_business_profiles') is not null as tabela_existe;

select column_name,data_type,is_nullable,column_default
from information_schema.columns
where table_schema='public' and table_name='company_business_profiles'
order by ordinal_position;

select c.relrowsecurity as rls_ativa,c.relforcerowsecurity as rls_forcada
from pg_class c
where c.oid=to_regclass('public.company_business_profiles');

select policyname,permissive,roles,cmd,qual,with_check
from pg_policies
where schemaname='public' and tablename='company_business_profiles'
order by policyname;

select
  has_table_privilege('anon','public.company_business_profiles','SELECT') as anon_select,
  has_table_privilege('anon','public.company_business_profiles','INSERT') as anon_insert,
  has_table_privilege('authenticated','public.company_business_profiles','SELECT') as authenticated_select,
  has_table_privilege('authenticated','public.company_business_profiles','INSERT') as authenticated_insert,
  has_table_privilege('authenticated','public.company_business_profiles','UPDATE') as authenticated_update;

select business_type,count(*) as empresas
from public.company_business_profiles
group by business_type
order by business_type;
