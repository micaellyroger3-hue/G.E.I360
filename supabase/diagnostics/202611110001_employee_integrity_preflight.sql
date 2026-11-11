-- G.E.I360 | Diagnóstico somente leitura: segurança de funcionários
select
  to_regclass('public.employees') is not null as employees_table_exists,
  to_regprocedure('public.is_company_member(uuid)') is not null as member_function_exists,
  to_regprocedure('public.has_company_role(uuid,text[])') is not null as role_function_exists;

select
  policyname,
  permissive,
  cmd,
  roles,
  qual,
  with_check
from pg_policies
where schemaname='public' and tablename='employees'
order by policyname;

select
  trigger_name,
  action_timing,
  event_manipulation,
  action_statement
from information_schema.triggers
where event_object_schema='public'
  and event_object_table='employees'
order by trigger_name;

select
  count(*) as employee_records,
  count(*) filter (where company_id is null) as missing_company_id,
  count(*) filter (where created_by is null) as missing_created_by
from public.employees;
