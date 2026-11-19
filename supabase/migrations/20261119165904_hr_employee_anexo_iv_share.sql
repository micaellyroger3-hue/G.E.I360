alter table public.employee_compensation add column if not exists anexo_iv_share numeric(5,2);
do $$
begin
 if not exists(select 1 from pg_constraint where conname='employee_compensation_anexo_iv_share_range') then
  alter table public.employee_compensation add constraint employee_compensation_anexo_iv_share_range check (anexo_iv_share is null or anexo_iv_share between 0 and 100);
 end if;
end $$;
comment on column public.employee_compensation.anexo_iv_share is 'Participação da remuneração deste empregado em atividades do Anexo IV do Simples; nulo usa a proporção geral da empresa.';
