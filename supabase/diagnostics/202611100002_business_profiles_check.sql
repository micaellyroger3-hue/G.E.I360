-- G.E.I360 | Perfil empresarial e canais
-- Diagnóstico somente leitura. Funciona antes e depois da migration.

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

-- Privilégios e contagem são condicionais para o diagnóstico não falhar
-- quando a tabela ainda não foi criada pela migration.
do $diagnostic$
declare
  v_anon_select boolean;
  v_anon_insert boolean;
  v_auth_select boolean;
  v_auth_insert boolean;
  v_auth_update boolean;
  v_count bigint;
begin
  if to_regclass('public.company_business_profiles') is null then
    raise notice 'company_business_profiles ainda não existe; execute a migration somente após revisar os pré-requisitos.';
    return;
  end if;

  select
    has_table_privilege('anon','public.company_business_profiles','SELECT'),
    has_table_privilege('anon','public.company_business_profiles','INSERT'),
    has_table_privilege('authenticated','public.company_business_profiles','SELECT'),
    has_table_privilege('authenticated','public.company_business_profiles','INSERT'),
    has_table_privilege('authenticated','public.company_business_profiles','UPDATE')
  into v_anon_select,v_anon_insert,v_auth_select,v_auth_insert,v_auth_update;

  execute 'select count(*) from public.company_business_profiles' into v_count;
  raise notice 'Privilégios: anon SELECT=%, anon INSERT=%, authenticated SELECT=%, INSERT=%, UPDATE=%',
    v_anon_select,v_anon_insert,v_auth_select,v_auth_insert,v_auth_update;
  raise notice 'Perfis empresariais cadastrados: %',v_count;
end
$diagnostic$;
