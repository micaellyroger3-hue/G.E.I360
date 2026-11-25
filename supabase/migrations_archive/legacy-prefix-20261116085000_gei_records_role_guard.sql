-- Restrict sector-operation writes to active non-viewer members.
-- These records are append-only; corrections are new records, not UPDATEs.
DROP POLICY IF EXISTS gei_records_member_insert ON public.gei_records;
CREATE POLICY gei_records_member_insert
  ON public.gei_records
  FOR INSERT
  TO authenticated
  WITH CHECK (
    created_by = (SELECT auth.uid())
    AND public.has_company_role(
      company_id,
      ARRAY['owner','admin','manager','employee']::text[]
    )
  );

DROP POLICY IF EXISTS gei_records_member_update ON public.gei_records;
REVOKE UPDATE ON TABLE public.gei_records FROM PUBLIC, anon, authenticated;
