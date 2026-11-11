-- G.E.I360 | Auditoria somente leitura: isolamento entre empresas e usuários
-- Execute no SQL Editor do Supabase. Não cria, altera ou apaga dados.
-- IMPORTANTE: executar no SQL Editor NÃO comprova o RLS visto pela API autenticada.

-- 1) Existência, RLS e FORCE RLS das tabelas de identidade/empresa.
with expected(table_name) as (
  values ('companies'),('company_members'),('profiles'),('empresas')
)
select e.table_name,
       c.oid is not null as exists,
       coalesce(c.relrowsecurity,false) as rls_enabled,
       coalesce(c.relforcerowsecurity,false) as rls_forced,
       c.relkind
from expected e
left join pg_class c on c.oid=to_regclass('public.'||e.table_name)
order by e.table_name;

-- 2) Todas as políticas existentes, inclusive permissive/restrictive e expressões.
select schemaname,tablename,policyname,permissive,roles,cmd,qual,with_check
from pg_policies
where schemaname='public'
  and tablename in ('companies','company_members','profiles','empresas')
order by tablename,policyname;

-- 3) Definição e propriedades das funções que decidem associação/cargo.
-- Inspecione prosecdef (SECURITY DEFINER), proconfig (search_path) e ACL.
select n.nspname as schema_name,
       p.proname as function_name,
       pg_get_function_identity_arguments(p.oid) as arguments,
       p.prosecdef as security_definer,
       p.proconfig as function_settings,
       p.proacl as privileges,
       pg_get_functiondef(p.oid) as function_definition
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
  and p.proname in ('is_company_member','has_company_role')
order by p.proname,arguments;

-- 4) Grants em tabelas e colunas sensíveis.
select grantee,table_name,privilege_type
from information_schema.table_privileges
where table_schema='public'
  and table_name in ('companies','company_members','profiles','empresas')
order by table_name,grantee,privilege_type;

select grantee,table_name,column_name,privilege_type
from information_schema.column_privileges
where table_schema='public'
  and table_name in ('companies','company_members','profiles','empresas')
order by table_name,grantee,column_name,privilege_type;

-- 5) Restrições e índices da tabela de associação: procurar unicidade por empresa/usuário.
select conname,contype,pg_get_constraintdef(oid) as definition
from pg_constraint
where conrelid=to_regclass('public.company_members')
order by conname;

select indexname,indexdef
from pg_indexes
where schemaname='public' and tablename='company_members'
order by indexname;

-- 6) Diagnóstico da tabela legada empresas: contagem de políticas e presença.
-- Não consulta conteúdo empresarial nem altera a tabela.
select to_regclass('public.empresas') as legacy_table,
       (select count(*) from pg_policies
        where schemaname='public' and tablename='empresas') as policy_count;

-- 7) Funções helper: quem pode executá-las.
select p.proname,
       has_function_privilege('anon',p.oid,'EXECUTE') as anon_can_execute,
       has_function_privilege('authenticated',p.oid,'EXECUTE') as authenticated_can_execute,
       has_function_privilege('public',p.oid,'EXECUTE') as public_can_execute
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname in ('is_company_member','has_company_role')
order by p.proname;

-- Interpretação e limites:
-- * Confirme que as funções verificam auth.uid() e associam user_id + company_id.
-- * SECURITY DEFINER exige search_path fixo/seguro e privilégios mínimos.
-- * Políticas permissivas são combinadas por OR; uma política ampla pode abrir acesso.
-- * A tabela empresas pode ser legado. Não apagar nem migrar sem rastrear referências.
-- * Se company_members permitir auto-inclusão em qualquer company_id, há risco de
--   autoinscrição/elevação. A política deve exigir convite/owner/admin autorizado.
-- * SQL Editor usa privilégios administrativos; não simula o usuário autenticado.
-- * A prova final exige duas contas reais, duas empresas e chamadas autenticadas à API,
--   tentando ler/alterar IDs da outra empresa. Faça isso em ambiente de teste.
