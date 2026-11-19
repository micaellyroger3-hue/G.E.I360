alter table public.hr_company_settings drop constraint if exists hr_company_settings_simples_annex_check;
alter table public.hr_company_settings add constraint hr_company_settings_simples_annex_check check (simples_annex is null or simples_annex = any(array['I','II','III','IV','V','mixed']::text[]));
