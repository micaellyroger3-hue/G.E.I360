alter table public.hr_time_rules add column if not exists daily_extension_agreement_reference text;
comment on column public.hr_time_rules.daily_extension_agreement_reference is 'Referência do ACT/CCT que autoriza ampliação da jornada diária; separada do acordo individual escrito 12x36 e dos instrumentos de repouso.';
