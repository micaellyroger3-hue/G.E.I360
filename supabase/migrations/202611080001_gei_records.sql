-- G.E.I360 — camada inicial de dados empresariais
-- Execute no Supabase SQL Editor depois de conferir que public.companies
-- e public.company_members existem e possuem as colunas id / company_id / user_id.
-- Esta migration não altera nem apaga as tabelas existentes.

create table if not exists public.gei_records (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  module text not null check (module in (
    'customers','suppliers','products','stock','purchases','sales',
    'pos','finance','services','production','employees','fiscal','branches'
  )),
  data jsonb not null default '{}'::jsonb,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists gei_records_company_module_idx
  on public.gei_records (company_id, module, created_at desc);

create or replace function public.gei_records_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists gei_records_updated_at on public.gei_records;
create trigger gei_records_updated_at
before update on public.gei_records
for each row execute function public.gei_records_set_updated_at();

alter table public.gei_records enable row level security;

drop policy if exists "gei_records_select_member" on public.gei_records;
create policy "gei_records_select_member"
on public.gei_records for select to authenticated
using (
  exists (
    select 1 from public.company_members cm
    where cm.company_id = gei_records.company_id
      and cm.user_id = auth.uid()
  )
);

drop policy if exists "gei_records_insert_member" on public.gei_records;
create policy "gei_records_insert_member"
on public.gei_records for insert to authenticated
with check (
  created_by = auth.uid()
  and exists (
    select 1 from public.company_members cm
    where cm.company_id = gei_records.company_id
      and cm.user_id = auth.uid()
  )
);

drop policy if exists "gei_records_update_member" on public.gei_records;
create policy "gei_records_update_member"
on public.gei_records for update to authenticated
using (
  exists (
    select 1 from public.company_members cm
    where cm.company_id = gei_records.company_id
      and cm.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.company_members cm
    where cm.company_id = gei_records.company_id
      and cm.user_id = auth.uid()
  )
);

drop policy if exists "gei_records_delete_member" on public.gei_records;
create policy "gei_records_delete_member"
on public.gei_records for delete to authenticated
using (
  exists (
    select 1 from public.company_members cm
    where cm.company_id = gei_records.company_id
      and cm.user_id = auth.uid()
  )
);
