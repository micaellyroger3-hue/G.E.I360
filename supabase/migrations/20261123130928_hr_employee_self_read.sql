-- G.E.I360 | Funcionário comum acessa somente a própria ficha.
-- Gestores autorizados continuam vendo os funcionários da empresa.
-- Não altera registros, vínculos ou remuneração.
BEGIN;

DROP POLICY IF EXISTS employees_members_select ON public.employees;

CREATE POLICY employees_members_select
ON public.employees
FOR SELECT
TO authenticated
USING (
  public.has_company_role(
    company_id,
    ARRAY['owner','admin','manager']::text[]
  )
  OR (
    auth_user_id = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1
      FROM public.company_members cm
      WHERE cm.company_id = employees.company_id
        AND cm.user_id = (SELECT auth.uid())
        AND cm.status = 'active'
        AND cm.role = 'employee'
    )
  )
);

COMMIT;
