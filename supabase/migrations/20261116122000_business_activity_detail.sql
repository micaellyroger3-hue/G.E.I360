-- G.E.I360 | Detalhamento livre da atividade empresarial
-- Permite identificar subatividades alimentícias e demais especializações sem criar tipos rígidos.
BEGIN;
ALTER TABLE public.company_business_profiles
  ADD COLUMN IF NOT EXISTS business_activity_detail text;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid='public.company_business_profiles'::regclass
      AND conname='company_business_profiles_activity_detail_length'
  ) THEN
    ALTER TABLE public.company_business_profiles
      ADD CONSTRAINT company_business_profiles_activity_detail_length
      CHECK (business_activity_detail IS NULL OR length(btrim(business_activity_detail)) <= 120);
  END IF;
END
$$;
COMMIT;
