-- G.E.I360 — regras de apuração, calendário, ocorrências, banco de horas e fechamento.
-- A migração é aditiva: não apaga nem reescreve marcações ou cadastros existentes.

create table if not exists public.hr_time_rules (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null unique references public.companies(id) on delete cascade,
  weekly_standard_minutes integer not null default 2640 check (weekly_standard_minutes between 1 and 10080),
  overtime_daily_threshold_minutes integer check (overtime_daily_threshold_minutes between 0 and 1440),
  overtime_weekly_threshold_minutes integer check (overtime_weekly_threshold_minutes between 0 and 10080),
  overtime_multiplier numeric(6,3) not null default 1.500 check (overtime_multiplier between 1 and 5),
  sunday_holiday_multiplier numeric(6,3) not null default 2.000 check (sunday_holiday_multiplier between 1 and 5),
  night_additional_percent numeric(6,3) not null default 20 check (night_additional_percent between 0 and 200),
  night_start time not null default '22:00',
  night_end time not null default '05:00',
  night_reduced_hour boolean not null default true,
  night_hour_minutes numeric(6,3) not null default 52.500 check (night_hour_minutes between 1 and 60),
  daily_tolerance_minutes integer not null default 10 check (daily_tolerance_minutes between 0 and 60),
  bank_enabled boolean not null default false,
  bank_agreement_type text not null default 'none' check (bank_agreement_type in ('none','individual','collective')),
  bank_validity_months integer check (bank_validity_months between 1 and 24),
  break_minimum_minutes integer not null default 60 check (break_minimum_minutes between 0 and 720),
  timezone text not null default 'America/Sao_Paulo',
  notes text,
  created_by uuid not null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.hr_holidays (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  holiday_date date not null,
  title text not null check (length(trim(title)) between 2 and 120),
  scope text not null default 'company' check (scope in ('national','state','municipal','company')),
  state_code text,
  city_name text,
  is_paid boolean not null default true,
  notes text,
  created_by uuid not null default auth.uid(),
  created_at timestamptz not null default now(),
  unique(company_id,holiday_date,title)
);

create table if not exists public.hr_time_occurrences (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  employee_id uuid not null,
  occurrence_date date not null,
  occurrence_type text not null check (occurrence_type in ('absence','missing_entry','missing_exit','missing_break_start','missing_break_end','late_arrival','early_departure','justified_absence','medical_leave','vacation','day_off_worked','other')),
  status text not null default 'pending' check (status in ('pending','justified','unjustified','approved','rejected','cancelled')),
  minutes integer check (minutes between 0 and 1440),
  reason text not null check (length(trim(reason)) between 3 and 1000),
  employee_note text,
  manager_note text,
  evidence_reference text,
  requested_by uuid not null default auth.uid(),
  reviewed_by uuid,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key(company_id,employee_id) references public.employees(company_id,id) on delete cascade
);

create table if not exists public.hr_time_bank_entries (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  employee_id uuid not null,
  effective_date date not null,
  entry_type text not null check (entry_type in ('credit','debit','expiry','adjustment','payout')),
  minutes integer not null check (minutes > 0 and minutes <= 10080),
  source_type text not null check (source_type in ('overtime','compensation','manual','absence','expiry','payroll')),
  source_id uuid,
  multiplier numeric(6,3) not null default 1 check (multiplier between 0.1 and 5),
  description text not null check (length(trim(description)) between 3 and 500),
  expires_on date,
  approved_by uuid not null default auth.uid(),
  created_at timestamptz not null default now(),
  foreign key(company_id,employee_id) references public.employees(company_id,id) on delete cascade
);

create table if not exists public.hr_time_periods (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  employee_id uuid not null,
  period_month date not null check (extract(day from period_month)=1),
  status text not null default 'open' check (status in ('open','closed','reopened')),
  summary jsonb not null default '{}'::jsonb,
  closed_by uuid,
  closed_at timestamptz,
  reopened_by uuid,
  reopened_at timestamptz,
  reopen_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id,employee_id,period_month),
  foreign key(company_id,employee_id) references public.employees(company_id,id) on delete cascade
);

create index if not exists hr_holidays_company_date_idx on public.hr_holidays(company_id,holiday_date);
create index if not exists hr_occurrences_company_date_idx on public.hr_time_occurrences(company_id,occurrence_date,employee_id);
create index if not exists hr_occurrences_employee_status_idx on public.hr_time_occurrences(employee_id,status,occurrence_date);
create index if not exists hr_bank_employee_date_idx on public.hr_time_bank_entries(company_id,employee_id,effective_date);
create index if not exists hr_periods_company_month_idx on public.hr_time_periods(company_id,period_month);

alter table public.hr_time_rules enable row level security;
alter table public.hr_holidays enable row level security;
alter table public.hr_time_occurrences enable row level security;
alter table public.hr_time_bank_entries enable row level security;
alter table public.hr_time_periods enable row level security;

drop policy if exists hr_time_rules_admin_all on public.hr_time_rules;
create policy hr_time_rules_admin_all on public.hr_time_rules for all to authenticated
using (public.has_company_role(company_id,array['owner','admin']))
with check (public.has_company_role(company_id,array['owner','admin']) and created_by=(select auth.uid()));

drop policy if exists hr_holidays_member_read on public.hr_holidays;
create policy hr_holidays_member_read on public.hr_holidays for select to authenticated
using (public.is_company_member(company_id));
drop policy if exists hr_holidays_admin_write on public.hr_holidays;
create policy hr_holidays_admin_write on public.hr_holidays for all to authenticated
using (public.has_company_role(company_id,array['owner','admin']))
with check (public.has_company_role(company_id,array['owner','admin']) and created_by=(select auth.uid()));

drop policy if exists hr_occurrences_manager_read on public.hr_time_occurrences;
create policy hr_occurrences_manager_read on public.hr_time_occurrences for select to authenticated
using (public.has_company_role(company_id,array['owner','admin','manager']) or exists (
 select 1 from public.employees e join public.company_members cm on cm.company_id=e.company_id
 where e.id=hr_time_occurrences.employee_id and e.company_id=hr_time_occurrences.company_id
 and e.auth_user_id=(select auth.uid()) and cm.user_id=(select auth.uid()) and cm.status='active' and cm.role='employee'
));
drop policy if exists hr_occurrences_manager_insert on public.hr_time_occurrences;
create policy hr_occurrences_manager_insert on public.hr_time_occurrences for insert to authenticated
with check (
 (requested_by=(select auth.uid()) and public.has_company_role(company_id,array['owner','admin','manager']))
 or
 (requested_by=(select auth.uid()) and status='pending' and exists (
  select 1 from public.employees e join public.company_members cm on cm.company_id=e.company_id
  where e.id=hr_time_occurrences.employee_id and e.company_id=hr_time_occurrences.company_id
  and e.auth_user_id=(select auth.uid()) and cm.user_id=(select auth.uid()) and cm.status='active' and cm.role='employee'
 ))
);
drop policy if exists hr_occurrences_admin_update on public.hr_time_occurrences;
create policy hr_occurrences_admin_update on public.hr_time_occurrences for update to authenticated
using (public.has_company_role(company_id,array['owner','admin','manager']))
with check (public.has_company_role(company_id,array['owner','admin','manager']));

drop policy if exists hr_bank_manager_read on public.hr_time_bank_entries;
create policy hr_bank_manager_read on public.hr_time_bank_entries for select to authenticated
using (public.has_company_role(company_id,array['owner','admin','manager']) or exists (
 select 1 from public.employees e join public.company_members cm on cm.company_id=e.company_id
 where e.id=hr_time_bank_entries.employee_id and e.company_id=hr_time_bank_entries.company_id
 and e.auth_user_id=(select auth.uid()) and cm.user_id=(select auth.uid()) and cm.status='active' and cm.role='employee'
));
drop policy if exists hr_bank_admin_insert on public.hr_time_bank_entries;
create policy hr_bank_admin_insert on public.hr_time_bank_entries for insert to authenticated
with check (approved_by=(select auth.uid()) and public.has_company_role(company_id,array['owner','admin']));
-- Ledger is append-only: no UPDATE or DELETE policy is created.

drop policy if exists hr_periods_admin_all on public.hr_time_periods;
create policy hr_periods_admin_all on public.hr_time_periods for all to authenticated
using (public.has_company_role(company_id,array['owner','admin']))
with check (public.has_company_role(company_id,array['owner','admin']));

grant select,insert,update,delete on public.hr_time_rules,public.hr_holidays,public.hr_time_occurrences,public.hr_time_periods to authenticated;
grant select,insert on public.hr_time_bank_entries to authenticated;
revoke all on public.hr_time_rules,public.hr_holidays,public.hr_time_occurrences,public.hr_time_bank_entries,public.hr_time_periods from anon;
