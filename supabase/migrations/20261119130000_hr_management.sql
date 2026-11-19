-- G.E.I360 | RH: remuneração protegida, parâmetros patronais, eventos e lançamento controlado no financeiro.
-- Aditiva: preserva employees e todos os registros existentes. Salários ficam em tabela separada,
-- com leitura restrita a owner/admin para não expor remuneração a todos os membros da empresa.
begin;

create table if not exists public.employee_compensation (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  salary_base numeric(14,2) not null default 0 check (salary_base >= 0),
  contract_type text not null default 'clt'
    check (contract_type in ('clt','aprendiz','estagio','autonomo','pj')),
  weekly_hours numeric(5,2) check (weekly_hours is null or (weekly_hours >= 0 and weekly_hours <= 168)),
  work_schedule text,
  transportation_allowance numeric(14,2) not null default 0 check (transportation_allowance >= 0),
  meal_allowance numeric(14,2) not null default 0 check (meal_allowance >= 0),
  health_benefit numeric(14,2) not null default 0 check (health_benefit >= 0),
  other_benefits numeric(14,2) not null default 0 check (other_benefits >= 0),
  notes text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, employee_id)
);

alter table public.employee_compensation
  drop constraint if exists employee_compensation_weekly_hours_check;
alter table public.employee_compensation
  add constraint employee_compensation_weekly_hours_check
  check (weekly_hours is null or (weekly_hours >= 0 and weekly_hours <= 168));

create table if not exists public.hr_company_settings (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null unique references public.companies(id) on delete cascade,
  tax_regime text not null check (tax_regime in ('mei','simples_nacional','lucro_presumido','lucro_real','outro')),
  simples_annex text check (simples_annex is null or simples_annex in ('I','II','III','IV','V')),
  employer_inss_mode text not null default 'included_in_das'
    check (employer_inss_mode in ('mei_3_percent','included_in_das','separate','custom','not_applicable')),
  employer_inss_rate numeric(7,4) not null default 0 check (employer_inss_rate >= 0 and employer_inss_rate <= 100),
  fgts_rate numeric(7,4) not null default 8 check (fgts_rate >= 0 and fgts_rate <= 100),
  rat_rate numeric(7,4) not null default 0 check (rat_rate >= 0 and rat_rate <= 100),
  third_party_rate numeric(7,4) not null default 0 check (third_party_rate >= 0 and third_party_rate <= 100),
  use_13th_provision boolean not null default true,
  use_vacation_provision boolean not null default true,
  notes text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint hr_simples_annex_required check (tax_regime <> 'simples_nacional' or simples_annex is not null)
);

create table if not exists public.hr_events (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  event_type text not null check (event_type in ('ferias','ausencia','afastamento','atestado','advertencia','alteracao_cargo','outro')),
  start_date date not null,
  end_date date,
  status text not null default 'planejado' check (status in ('planejado','em_andamento','concluido','cancelado')),
  notes text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_date is null or end_date >= start_date)
);

create table if not exists public.hr_cost_postings (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  period date not null,
  financial_entry_id uuid not null references public.financial_entries(id) on delete restrict,
  amount numeric(14,2) not null check (amount > 0),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  unique(company_id, period),
  unique(financial_entry_id)
);


-- Integridade multiempresa: cada registro de RH precisa apontar para funcionário da mesma empresa.
create or replace function public.gei_hr_guard_employee_link()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if tg_op = 'UPDATE' and new.company_id is distinct from old.company_id then
    raise exception 'O registro de RH não pode ser transferido para outra empresa.';
  end if;
  if not exists (
    select 1 from public.employees e
    where e.id = new.employee_id and e.company_id = new.company_id
  ) then
    raise exception 'O funcionário informado não pertence à empresa deste registro.';
  end if;
  return new;
end;
$function$;
revoke all on function public.gei_hr_guard_employee_link() from public, anon, authenticated;
drop trigger if exists gei_hr_compensation_employee_guard on public.employee_compensation;
create trigger gei_hr_compensation_employee_guard
before insert or update on public.employee_compensation
for each row execute function public.gei_hr_guard_employee_link();
drop trigger if exists gei_hr_event_employee_guard on public.hr_events;
create trigger gei_hr_event_employee_guard
before insert or update on public.hr_events
for each row execute function public.gei_hr_guard_employee_link();

create index if not exists employee_compensation_company_idx on public.employee_compensation(company_id, employee_id);
create index if not exists hr_events_company_date_idx on public.hr_events(company_id, start_date desc);
create index if not exists hr_cost_postings_company_period_idx on public.hr_cost_postings(company_id, period desc);

alter table public.employee_compensation enable row level security;
alter table public.hr_company_settings enable row level security;
alter table public.hr_events enable row level security;
alter table public.hr_cost_postings enable row level security;

revoke all on public.employee_compensation, public.hr_company_settings, public.hr_events, public.hr_cost_postings from anon;
grant select, insert, update, delete on public.employee_compensation, public.hr_company_settings, public.hr_events, public.hr_cost_postings to authenticated;

drop policy if exists gei_hr_compensation_select on public.employee_compensation;
create policy gei_hr_compensation_select on public.employee_compensation
for select to authenticated using (public.has_company_role(company_id, array['owner','admin']::text[]));
drop policy if exists gei_hr_compensation_insert on public.employee_compensation;
create policy gei_hr_compensation_insert on public.employee_compensation
for insert to authenticated with check (
  created_by = (select auth.uid())
  and public.has_company_role(company_id, array['owner','admin']::text[])
  and exists (select 1 from public.employees e where e.id = employee_id and e.company_id = employee_compensation.company_id)
);
drop policy if exists gei_hr_compensation_update on public.employee_compensation;
create policy gei_hr_compensation_update on public.employee_compensation
for update to authenticated using (public.has_company_role(company_id, array['owner','admin']::text[]))
with check (public.has_company_role(company_id, array['owner','admin']::text[]) and exists (select 1 from public.employees e where e.id = employee_id and e.company_id = employee_compensation.company_id));
drop policy if exists gei_hr_compensation_delete on public.employee_compensation;
create policy gei_hr_compensation_delete on public.employee_compensation
for delete to authenticated using (public.has_company_role(company_id, array['owner','admin']::text[]));

drop policy if exists gei_hr_settings_select on public.hr_company_settings;
create policy gei_hr_settings_select on public.hr_company_settings
for select to authenticated using (public.has_company_role(company_id, array['owner','admin']::text[]));
drop policy if exists gei_hr_settings_insert on public.hr_company_settings;
create policy gei_hr_settings_insert on public.hr_company_settings
for insert to authenticated with check (created_by = (select auth.uid()) and public.has_company_role(company_id, array['owner','admin']::text[]));
drop policy if exists gei_hr_settings_update on public.hr_company_settings;
create policy gei_hr_settings_update on public.hr_company_settings
for update to authenticated using (public.has_company_role(company_id, array['owner','admin']::text[]))
with check (public.has_company_role(company_id, array['owner','admin']::text[]));
drop policy if exists gei_hr_settings_delete on public.hr_company_settings;
create policy gei_hr_settings_delete on public.hr_company_settings
for delete to authenticated using (public.has_company_role(company_id, array['owner','admin']::text[]));

drop policy if exists gei_hr_events_select on public.hr_events;
create policy gei_hr_events_select on public.hr_events
for select to authenticated using (public.has_company_role(company_id, array['owner','admin']::text[]));
drop policy if exists gei_hr_events_insert on public.hr_events;
create policy gei_hr_events_insert on public.hr_events
for insert to authenticated with check (
  created_by = (select auth.uid())
  and public.has_company_role(company_id, array['owner','admin']::text[])
  and exists (select 1 from public.employees e where e.id = employee_id and e.company_id = hr_events.company_id)
);
drop policy if exists gei_hr_events_update on public.hr_events;
create policy gei_hr_events_update on public.hr_events
for update to authenticated using (public.has_company_role(company_id, array['owner','admin']::text[]))
with check (public.has_company_role(company_id, array['owner','admin']::text[]) and exists (select 1 from public.employees e where e.id = employee_id and e.company_id = hr_events.company_id));
drop policy if exists gei_hr_events_delete on public.hr_events;
create policy gei_hr_events_delete on public.hr_events
for delete to authenticated using (public.has_company_role(company_id, array['owner','admin']::text[]));

drop policy if exists gei_hr_postings_select on public.hr_cost_postings;
create policy gei_hr_postings_select on public.hr_cost_postings
for select to authenticated using (public.has_company_role(company_id, array['owner','admin']::text[]));
drop policy if exists gei_hr_postings_insert on public.hr_cost_postings;
create policy gei_hr_postings_insert on public.hr_cost_postings
for insert to authenticated with check (created_by = (select auth.uid()) and public.has_company_role(company_id, array['owner','admin']::text[]));

create or replace function public.gei_post_hr_monthly_cost(
  p_company_id uuid,
  p_period date,
  p_amount numeric,
  p_notes text default null
) returns uuid
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  v_entry_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Autenticação necessária.';
  end if;
  if not public.has_company_role(p_company_id, array['owner','admin']::text[]) then
    raise exception 'Somente proprietário ou administrador pode lançar custo de RH.';
  end if;
  if p_period is null or extract(day from p_period) <> 1 then
    raise exception 'Informe o primeiro dia do mês de referência.';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'O custo estimado precisa ser maior que zero.';
  end if;
  insert into public.financial_entries
    (company_id, entry_type, description, category, amount, due_date, status, notes, created_by)
  values
    (p_company_id, 'expense',
     'Custo estimado de pessoal — ' || to_char(p_period, 'MM/YYYY'),
     'Folha de pagamento', round(p_amount,2), p_period, 'pending',
     coalesce(p_notes,'Estimativa gerencial de RH; não substitui folha oficial.'), auth.uid())
  returning id into v_entry_id;

  insert into public.hr_cost_postings(company_id, period, financial_entry_id, amount, created_by)
  values (p_company_id, p_period, v_entry_id, round(p_amount,2), auth.uid());

  return v_entry_id;
exception
  when unique_violation then
    raise exception 'Já existe um lançamento de custo de RH para este mês. Confira o Financeiro antes de tentar novamente.';
end;
$function$;

revoke all on function public.gei_post_hr_monthly_cost(uuid,date,numeric,text) from public, anon;
grant execute on function public.gei_post_hr_monthly_cost(uuid,date,numeric,text) to authenticated;

commit;
