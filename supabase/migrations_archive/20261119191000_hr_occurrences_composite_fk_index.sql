-- Cover the composite employee/company foreign key for occurrence rows.
create index if not exists hr_occurrences_company_employee_fk_idx
on public.hr_time_occurrences(company_id, employee_id);
