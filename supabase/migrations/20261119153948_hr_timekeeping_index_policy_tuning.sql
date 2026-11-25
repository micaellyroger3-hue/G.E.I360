-- Ajustes de performance e consolidação das políticas de leitura do ponto.
drop policy hr_work_schedules_admin_select on public.hr_work_schedules;
drop policy hr_work_schedules_employee_select on public.hr_work_schedules;

create policy hr_work_schedules_select on public.hr_work_schedules
  for select to authenticated using (
    public.has_company_role(company_id, array['owner','admin','manager'])
    or (
      exists (
        select 1 from public.employees e
        where e.id = employee_id
          and e.company_id = hr_work_schedules.company_id
          and e.auth_user_id = (select auth.uid())
      )
      and exists (
        select 1 from public.company_members cm
        where cm.company_id = hr_work_schedules.company_id
          and cm.user_id = (select auth.uid())
          and cm.status = 'active'
          and cm.role = 'employee'
      )
    )
  );

-- A FK composta (company_id, employee_id) já garante o vínculo do funcionário
-- à empresa; removemos as FKs simples redundantes que geravam índices separados.
alter table public.hr_time_punches drop constraint hr_time_punches_employee_id_fkey;
alter table public.hr_time_adjustments drop constraint hr_time_adjustments_employee_id_fkey;

create index if not exists employees_auth_user_id_idx
  on public.employees(auth_user_id);
create index if not exists hr_time_punches_created_by_idx
  on public.hr_time_punches(created_by);
create index if not exists hr_time_adjustments_original_punch_id_idx
  on public.hr_time_adjustments(original_punch_id);
create index if not exists hr_time_adjustments_requested_by_idx
  on public.hr_time_adjustments(requested_by);
create index if not exists hr_time_adjustments_reviewed_by_idx
  on public.hr_time_adjustments(reviewed_by);
create index if not exists hr_work_schedules_created_by_idx
  on public.hr_work_schedules(created_by);
