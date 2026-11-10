-- G.E.I360 | Perfil inteligente por ramo e canais comerciais
-- Não armazena tokens de terceiros. Integrações reais exigem backend seguro.
begin;

do $preflight$
begin
  if to_regclass('public.companies') is null then
    raise exception 'G.E.I360: tabela companies não encontrada.';
  end if;
  if to_regprocedure('public.is_company_member(uuid)') is null
     or to_regprocedure('public.has_company_role(uuid,text[])') is null then
    raise exception 'G.E.I360: funções de autorização da empresa não encontradas.';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='companies'
      and column_name='id' and data_type='uuid'
  ) then
    raise exception 'G.E.I360: companies.id não é UUID; migração cancelada.';
  end if;
end
$preflight$;

create table if not exists public.company_business_profiles (
  company_id uuid primary key references public.companies(id) on delete cascade,
  business_type text not null default 'other',
  sales_channels text[] not null default '{}'::text[],
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint company_business_profiles_type_check check (
    business_type in ('restaurant','grocery','retail','services','distributor','ecommerce','construction','other')
  ),
  constraint company_business_profiles_channels_check check (
    sales_channels <@ array['ifood','whatsapp','instagram','physical_store','own_delivery','ecommerce','marketplace']::text[]
  )
);

alter table public.company_business_profiles enable row level security;

drop policy if exists gei360_business_profile_member_read on public.company_business_profiles;
create policy gei360_business_profile_member_read
on public.company_business_profiles for select to authenticated
using (public.is_company_member(company_id));

drop policy if exists gei360_business_profile_admin_insert on public.company_business_profiles;
create policy gei360_business_profile_admin_insert
on public.company_business_profiles for insert to authenticated
with check (
  created_by=(select auth.uid())
  and public.has_company_role(company_id,array['owner','admin']::text[])
);

drop policy if exists gei360_business_profile_admin_update on public.company_business_profiles;
create policy gei360_business_profile_admin_update
on public.company_business_profiles for update to authenticated
using (public.has_company_role(company_id,array['owner','admin']::text[]))
with check (public.has_company_role(company_id,array['owner','admin']::text[]));

revoke all on public.company_business_profiles from public, anon, authenticated;
grant select on public.company_business_profiles to authenticated;
grant insert (company_id,business_type,sales_channels,created_by) on public.company_business_profiles to authenticated;
grant update (business_type,sales_channels) on public.company_business_profiles to authenticated;

create or replace function public.gei360_set_business_profile_updated_at()
returns trigger
language plpgsql
set search_path = public
as $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;

revoke all on function public.gei360_set_business_profile_updated_at() from public, anon, authenticated;
drop trigger if exists gei360_business_profile_updated_at on public.company_business_profiles;
create trigger gei360_business_profile_updated_at
before update on public.company_business_profiles
for each row execute function public.gei360_set_business_profile_updated_at();

commit;
