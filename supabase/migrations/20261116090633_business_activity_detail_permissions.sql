-- G.E.I360 | Permissões de coluna para detalhamento da atividade
BEGIN;
GRANT INSERT (business_activity_detail) ON TABLE public.company_business_profiles TO authenticated;
GRANT UPDATE (business_activity_detail) ON TABLE public.company_business_profiles TO authenticated;
COMMIT;
