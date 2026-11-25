-- Use wall-clock time for each punch, even when several marks are recorded in one transaction.
create or replace function public.hr_register_time_punch(
  p_employee_id uuid,
  p_punch_type text
)
returns public.hr_time_punches
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_employee public.employees%rowtype;
  v_last public.hr_time_punches%rowtype;
  v_source text;
  v_result public.hr_time_punches%rowtype;
begin
  if p_punch_type is null or p_punch_type not in ('entrada','inicio_intervalo','fim_intervalo','saida') then
    raise exception 'Tipo de marcação inválido.';
  end if;

  select * into v_employee
  from public.employees e
  where e.id = p_employee_id
    and e.employment_status <> 'inativo'
    and e.status = 'active';

  if not found then raise exception 'Funcionário não encontrado ou inativo.'; end if;

  if v_employee.auth_user_id = (select auth.uid()) and exists (
    select 1 from public.company_members cm
    where cm.company_id = v_employee.company_id
      and cm.user_id = (select auth.uid())
      and cm.status = 'active'
      and cm.role = 'employee'
  ) then
    v_source := 'app_funcionario';
  elsif public.has_company_role(v_employee.company_id, array['owner','admin','manager']) then
    v_source := 'registro_gestor';
  else
    raise exception 'Você não tem autorização para registrar o ponto deste funcionário.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_employee_id::text, 0));

  select * into v_last
  from public.hr_time_punches p
  where p.employee_id = p_employee_id
  order by p.punched_at desc, p.created_at desc
  limit 1;

  if not found or v_last.punch_type = 'saida' then
    if p_punch_type <> 'entrada' then raise exception 'A primeira marcação da jornada deve ser Entrada.'; end if;
  elsif v_last.punch_type = 'entrada' then
    if p_punch_type not in ('inicio_intervalo','saida') then raise exception 'Após a entrada, registre início do intervalo ou saída.'; end if;
    if clock_timestamp() - v_last.punched_at > interval '18 hours' then raise exception 'Jornada aberta há mais de 18 horas. Solicite correção ao responsável.'; end if;
  elsif v_last.punch_type = 'inicio_intervalo' then
    if p_punch_type <> 'fim_intervalo' then raise exception 'Registre o retorno do intervalo.'; end if;
  elsif v_last.punch_type = 'fim_intervalo' then
    if p_punch_type not in ('inicio_intervalo','saida') then raise exception 'Registre outro intervalo ou a saída.'; end if;
  end if;

  insert into public.hr_time_punches(company_id, employee_id, punch_type, punched_at, source, created_by)
  values (v_employee.company_id, v_employee.id, p_punch_type, clock_timestamp(), v_source, (select auth.uid()))
  returning * into v_result;

  return v_result;
end;
$$;

revoke all on function public.hr_register_time_punch(uuid,text) from public, anon;
grant execute on function public.hr_register_time_punch(uuid,text) to authenticated;
