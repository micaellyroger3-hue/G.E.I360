-- G.E.I360: cadastro de funcionários por empresa
-- Execute no Supabase SQL Editor uma única vez.
create table if not exists public.employees (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  full_name text not null,
  email text,
  phone text,
  job_title text,
  department text,
  status text not null default 'active' check (status in ('active','inactive')),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists employees_company_id_idx on public.employees(company_id);
alter table public.employees enable row level security;

drop policy if exists employees_members_select on public.employees;
create policy employees_members_select
on public.employees for select to authenticated
using (public.is_company_member(company_id));

drop policy if exists employees_managers_insert on public.employees;
create policy employees_managers_insert
on public.employees for insert to authenticated
with check (
  created_by = (select auth.uid())
  and public.has_company_role(company_id, array['owner','admin','manager']::text[])
);

drop policy if exists employees_managers_update on public.employees;
create policy employees_managers_update
on public.employees for update to authenticated
using (public.has_company_role(company_id, array['owner','admin','manager']::text[]))
with check (public.has_company_role(company_id, array['owner','admin','manager']::text[]));

drop policy if exists employees_admins_delete on public.employees;
create policy employees_admins_delete
on public.employees for delete to authenticated
using (public.has_company_role(company_id, array['owner','admin']::text[]));

grant select, insert, update, delete on public.employees to authenticated;
