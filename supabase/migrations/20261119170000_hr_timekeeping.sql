
-- RH: jornadas, escalas e ponto. Registros brutos são imutáveis.
alter table public.employees
  add column auth_user_id uuid null references auth.users(id) on delete set null;

create unique index employees_auth_user_id_company_uidx
  on public.employees(company_id, auth_user_id)
  where auth_user_id is not null;

create table public.hr_work_schedules (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete restrict,
  schedule_type text not null check (schedule_type in ('12x36','por_hora','fixa','6x1','5x2','personalizada','variavel')),
  effective_from date not null,
  effective_to date null,
  shift_start time null,
  shift_end time null,
  break_minutes integer not null default 0 check (break_minutes between 0 and 720),
  weekly_hours numeric(6,2) null check (weekly_hours between 0 and 168),
  hourly_rate numeric(12,2) null check (hourly_rate >= 0),
  weekdays smallint[] null,
  cycle_on_days smallint null check (cycle_on_days between 1 and 31),
  cycle_off_days smallint null check (cycle_off_days between 1 and 31),
  cycle_anchor_date date null,
  notes text null check (char_length(notes) <= 1000),
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint hr_work_schedules_employee_company_fk
    foreign key (company_id, employee_id)
    references public.employees(company_id, id) on delete restrict,
  constraint hr_work_schedules_date_range_ck
    check (effective_to is null or effective_to >= effective_from),
  constraint hr_work_schedules_cycle_ck
    check (
      (schedule_type = '12x36' and cycle_on_days = 1 and cycle_off_days = 1 and cycle_anchor_date is not null)
      or schedule_type <> '12x36'
    )
);

create index hr_work_schedules_company_employee_dates_idx
  on public.hr_work_schedules(company_id, employee_id, effective_from desc);

create table public.hr_time_punches (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete restrict,
  punch_type text not null check (punch_type in ('entrada','inicio_intervalo','fim_intervalo','saida')),
  punched_at timestamptz not null default now(),
  source text not null check (source in ('app_funcionario','registro_gestor')),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  constraint hr_time_punches_employee_company_fk
    foreign key (company_id, employee_id)
    references public.employees(company_id, id) on delete restrict
);

create index hr_time_punches_company_employee_time_idx
  on public.hr_time_punches(company_id, employee_id, punched_at desc);

create table public.hr_time_adjustments (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete restrict,
  original_punch_id uuid not null references public.hr_time_punches(id) on delete restrict,
  proposed_punched_at timestamptz not null,
  reason text not null check (char_length(trim(reason)) between 5 and 1000),
  status text not null default 'solicitado' check (status in ('solicitado','aprovado','rejeitado')),
  requested_by uuid not null references auth.users(id),
  reviewed_by uuid null references auth.users(id),
  reviewed_at timestamptz null,
  review_note text null check (char_length(review_note) <= 1000),
  created_at timestamptz not null default now(),
  constraint hr_time_adjustments_employee_company_fk
    foreign key (company_id, employee_id)
    references public.employees(company_id, id) on delete restrict
);

create index hr_time_adjustments_company_employee_idx
  on public.hr_time_adjustments(company_id, employee_id, created_at desc);

alter table public.hr_work_schedules enable row level security;
alter table public.hr_time_punches enable row level security;
alter table public.hr_time_adjustments enable row level security;

create policy hr_work_schedules_admin_select on public.hr_work_schedules
  for select to authenticated using (public.has_company_role(company_id, array['owner','admin','manager']));
create policy hr_work_schedules_admin_insert on public.hr_work_schedules
  for insert to authenticated with check (
    created_by = (select auth.uid())
    and public.has_company_role(company_id, array['owner','admin'])
    and exists (select 1 from public.employees e where e.id = employee_id and e.company_id = hr_work_schedules.company_id)
  );
create policy hr_work_schedules_admin_update on public.hr_work_schedules
  for update to authenticated using (public.has_company_role(company_id, array['owner','admin']))
  with check (public.has_company_role(company_id, array['owner','admin']));
create policy hr_work_schedules_admin_delete on public.hr_work_schedules
  for delete to authenticated using (public.has_company_role(company_id, array['owner','admin']));

create policy hr_time_punches_read on public.hr_time_punches
  for select to authenticated using (
    public.has_company_role(company_id, array['owner','admin','manager'])
    or exists (select 1 from public.employees e where e.id = employee_id and e.company_id = hr_time_punches.company_id and e.auth_user_id = (select auth.uid()))
  );

create policy hr_time_adjustments_admin_read on public.hr_time_adjustments
  for select to authenticated using (public.has_company_role(company_id, array['owner','admin','manager']));
create policy hr_time_adjustments_admin_insert on public.hr_time_adjustments
  for insert to authenticated with check (
    requested_by = (select auth.uid())
    and public.has_company_role(company_id, array['owner','admin','manager'])
    and exists (select 1 from public.hr_time_punches p where p.id = original_punch_id and p.employee_id = hr_time_adjustments.employee_id and p.company_id = hr_time_adjustments.company_id)
  );
create policy hr_time_adjustments_admin_update on public.hr_time_adjustments
  for update to authenticated using (public.has_company_role(company_id, array['owner','admin']))
  with check (public.has_company_role(company_id, array['owner','admin']));

revoke all on public.hr_work_schedules, public.hr_time_punches, public.hr_time_adjustments from anon, public;
grant select, insert, update, delete on public.hr_work_schedules to authenticated;
grant select on public.hr_time_punches to authenticated;
grant select, insert, update on public.hr_time_adjustments to authenticated;

create or replace function public.hr_claim_employee_account()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text;
  v_count integer;
begin
  select lower(u.email) into v_email
  from auth.users u
  where u.id = (select auth.uid());

  if v_email is null then
    raise exception 'Não foi possível identificar o e-mail confirmado da conta.';
  end if;

  update public.employees e
     set auth_user_id = (select auth.uid()), updated_at = now()
   where lower(e.email) = v_email
     and e.auth_user_id is null
     and exists (
       select 1 from public.company_members cm
       where cm.company_id = e.company_id
         and cm.user_id = (select auth.uid())
         and cm.status = 'active'
         and cm.role = 'employee'
     );

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

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
  if p_punch_type not in ('entrada','inicio_intervalo','fim_intervalo','saida') then
    raise exception 'Tipo de marcação inválido.';
  end if;

  select * into v_employee
  from public.employees e
  where e.id = p_employee_id
    and e.employment_status <> 'inativo'
    and e.status = 'active';

  if not found then raise exception 'Funcionário não encontrado ou inativo.'; end if;

  if v_employee.auth_user_id = (select auth.uid()) then
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
    if now() - v_last.punched_at > interval '18 hours' then raise exception 'Jornada aberta há mais de 18 horas. Solicite correção ao responsável.'; end if;
  elsif v_last.punch_type = 'inicio_intervalo' then
    if p_punch_type <> 'fim_intervalo' then raise exception 'Registre o retorno do intervalo.'; end if;
  elsif v_last.punch_type = 'fim_intervalo' then
    if p_punch_type not in ('inicio_intervalo','saida') then raise exception 'Registre outro intervalo ou a saída.'; end if;
  end if;

  insert into public.hr_time_punches(company_id, employee_id, punch_type, source, created_by)
  values (v_employee.company_id, v_employee.id, p_punch_type, v_source, (select auth.uid()))
  returning * into v_result;

  return v_result;
end;
$$;

revoke all on function public.hr_claim_employee_account() from public, anon;
grant execute on function public.hr_claim_employee_account() to authenticated;
revoke all on function public.hr_register_time_punch(uuid,text) from public, anon;
grant execute on function public.hr_register_time_punch(uuid,text) to authenticated;

comment on table public.hr_time_punches is 'Marcações originais e imutáveis de ponto. Correções devem ser registradas em hr_time_adjustments.';
comment on table public.hr_time_adjustments is 'Trilha de solicitações e aprovações de ajuste; não altera nem apaga marcações originais.';
comment on table public.hr_work_schedules is 'Escalas e jornadas previstas por funcionário, incluindo 12x36 e remuneração por hora.';
