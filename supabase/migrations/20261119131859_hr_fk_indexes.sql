-- G.E.I360 | RH: índices de suporte às chaves estrangeiras.
begin;
create index if not exists employee_compensation_employee_id_idx on public.employee_compensation(employee_id);
create index if not exists employee_compensation_created_by_idx on public.employee_compensation(created_by);
create index if not exists hr_company_settings_created_by_idx on public.hr_company_settings(created_by);
create index if not exists hr_events_employee_id_idx on public.hr_events(employee_id);
create index if not exists hr_events_created_by_idx on public.hr_events(created_by);
create index if not exists hr_cost_postings_created_by_idx on public.hr_cost_postings(created_by);
commit;
