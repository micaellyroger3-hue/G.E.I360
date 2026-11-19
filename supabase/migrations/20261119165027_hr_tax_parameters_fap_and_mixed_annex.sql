alter table public.hr_company_settings
 add column if not exists fap_factor numeric(6,4),
 add column if not exists rat_confirmed boolean not null default false,
 add column if not exists third_party_confirmed boolean not null default false,
 add column if not exists anexo_iv_revenue_share numeric(5,2),
 add column if not exists fpas_code text;
do $$
begin
 if not exists(select 1 from pg_constraint where conname='hr_company_settings_fap_factor_range') then
  alter table public.hr_company_settings add constraint hr_company_settings_fap_factor_range check (fap_factor is null or fap_factor between 0.5 and 2.0);
 end if;
 if not exists(select 1 from pg_constraint where conname='hr_company_settings_anexo_iv_share_range') then
  alter table public.hr_company_settings add constraint hr_company_settings_anexo_iv_share_range check (anexo_iv_revenue_share is null or anexo_iv_revenue_share between 0 and 100);
 end if;
end $$;
comment on column public.hr_company_settings.fap_factor is 'FAP vigente do estabelecimento, informado após consulta oficial; nunca presumido.';
comment on column public.hr_company_settings.anexo_iv_revenue_share is 'Percentual da receita bruta total do Simples Nacional oriunda de atividades do Anexo IV, para cálculo proporcional em atividades mistas.';
comment on column public.hr_company_settings.rat_confirmed is 'Indica que RAT/SAT e FAP foram conferidos pelo responsável.';
comment on column public.hr_company_settings.third_party_confirmed is 'Indica que FPAS e alíquota de terceiros foram conferidos pelo responsável.';
