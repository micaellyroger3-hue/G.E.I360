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

-- Evita erro quando a tabela ainda não existe ou o schema está incompleto.
do $diagnostic$
declare
  v_count bigint;
  v_missing_company_id boolean;
  v_missing_created_by boolean;
begin
  if to_regclass('public.employees') is null then
    raise notice 'public.employees ainda não existe; a migration-base precisa ser aplicada primeiro.';
    return;
  end if;

  select
    not exists (select 1 from information_schema.columns where table_schema='public' and table_name='employees' and column_name='company_id'),
    not exists (select 1 from information_schema.columns where table_schema='public' and table_name='employees' and column_name='created_by')
  into v_missing_company_id,v_missing_created_by;

  if v_missing_company_id or v_missing_created_by then
    raise notice 'Schema incompleto: company_id ausente=%, created_by ausente=%',
      v_missing_company_id,v_missing_created_by;
    return;
  end if;

  execute 'select count(*) from public.employees' into v_count;
  raise notice 'Registros de funcionários: %',v_count;
  execute 'select count(*) from public.employees where company_id is null' into v_count;
  raise notice 'Registros sem company_id: %',v_count;
  execute 'select count(*) from public.employees where created_by is null' into v_count;
  raise notice 'Registros sem created_by: %',v_count;
end
$diagnostic$;
