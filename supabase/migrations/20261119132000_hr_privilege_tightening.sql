-- G.E.I360 | RH: remove privilégios estruturais herdados por padrão nas tabelas novas.
begin;
revoke truncate, references, trigger on public.employee_compensation, public.hr_company_settings, public.hr_events, public.hr_cost_postings from authenticated;
revoke update, delete on public.hr_cost_postings from authenticated;
commit;
