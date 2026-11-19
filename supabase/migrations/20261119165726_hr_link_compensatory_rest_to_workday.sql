alter table public.hr_schedule_exceptions add column if not exists compensation_for_date date;
do $$
begin
 if not exists(select 1 from pg_constraint where conname='hr_schedule_exceptions_compensation_date_check') then
  alter table public.hr_schedule_exceptions add constraint hr_schedule_exceptions_compensation_date_check
   check (compensation_for_date is null or (exception_type='extra_rest' and compensation_for_date<>exception_date));
 end if;
end $$;
create index if not exists hr_schedule_exceptions_compensation_date_idx
 on public.hr_schedule_exceptions(company_id,employee_id,compensation_for_date)
 where exception_type='extra_rest' and compensation_for_date is not null;
comment on column public.hr_schedule_exceptions.compensation_for_date is 'Data de trabalho em domingo/feriado compensada por esta folga extra, para vincular a compensação à apuração.';
