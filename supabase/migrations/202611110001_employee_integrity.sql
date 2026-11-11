-- G.E.I360 | Integridade e isolamento do cadastro de funcionários
-- Migration aditiva: não altera registros existentes e não cria usuários de login.
begin;

do $preflight$
begin
  if to_regclass('public.employees') is null then
    raise exception 'G.E.I360: tabela employees não encontrada. Migração cancelada.';
  end if;
  if to_regprocedure('public.is_company_member(uuid)') is null
     or to_regprocedure('public.has_company_role(uuid,text[])') is null then
    raise exception 'G.E.I360: funções de autorização da empresa não encontradas.';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='employees' and column_name='company_id'
  ) or not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='employees' and column_name='created_by'
  ) then
    raise exception 'G.E.I360: employees não possui company_id e created_by. Migração cancelada.';
  end if;
end
$preflight$;

-- Impede transferir um funcionário para outra empresa ou trocar o autor original.
-- Atualiza updated_at automaticamente em edições futuras.
create or replace function public.gei360_guard_employee_integrity()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if new.company_id is distinct from old.company_id then
    raise exception 'O funcionário não pode ser transferido para outra empresa.';
  end if;
  if new.created_by is distinct from old.created_by then
    raise exception 'O autor original do cadastro não pode ser alterado.';
  end if;
  new.updated_at := now();
  return new;
end;
$function$;

revoke all on function public.gei360_guard_employee_integrity() from public, anon, authenticated;
drop trigger if exists gei360_employee_integrity_guard on public.employees;
create trigger gei360_employee_integrity_guard
before update on public.employees
for each row execute function public.gei360_guard_employee_integrity();

-- Políticas restritivas: políticas permissivas antigas não podem ampliar acesso.
drop policy if exists gei360_employees_member_guard on public.employees;
create policy gei360_employees_member_guard
on public.employees as restrictive for all to authenticated
using (public.is_company_member(company_id))
with check (public.is_company_member(company_id));

drop policy if exists gei360_employees_insert_guard on public.employees;
create policy gei360_employees_insert_guard
on public.employees as restrictive for insert to authenticated
with check (
  created_by = (select auth.uid())
  and public.has_company_role(company_id,array['owner','admin','manager']::text[])
);

drop policy if exists gei360_employees_update_guard on public.employees;
create policy gei360_employees_update_guard
on public.employees as restrictive for update to authenticated
using (public.has_company_role(company_id,array['owner','admin','manager']::text[]))
with check (
  public.is_company_member(company_id)
  and public.has_company_role(company_id,array['owner','admin','manager']::text[])
);

drop policy if exists gei360_employees_delete_guard on public.employees;
create policy gei360_employees_delete_guard
on public.employees as restrictive for delete to authenticated
using (public.has_company_role(company_id,array['owner','admin']::text[]));

commit;
