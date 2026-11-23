-- G.E.I360 | Enforce company module switches and role-based business data reads.
-- Disabled modules remain stored; RLS blocks access until the module is re-enabled.
BEGIN;

CREATE OR REPLACE FUNCTION private.is_company_module_enabled(
  p_company_id uuid,
  p_module_code text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT
    EXISTS (
      SELECT 1
      FROM public.company_members cm
      WHERE cm.company_id = p_company_id
        AND cm.user_id = (SELECT auth.uid())
        AND cm.status = 'active'
    )
    AND EXISTS (
      SELECT 1
      FROM public.gei_module_catalog c
      LEFT JOIN public.company_modules m
        ON m.company_id = p_company_id
       AND m.module_code = c.code
      WHERE c.code = p_module_code
        AND c.is_available = true
        AND (c.is_core = true OR COALESCE(m.is_enabled, true) = true)
    );
$function$;

REVOKE ALL ON FUNCTION private.is_company_module_enabled(uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.is_company_module_enabled(uuid, text) TO authenticated, service_role;

-- Employees can work with their own time/operational data, but not browse
-- company-wide customer, sales, purchase, finance or business-document data.
ALTER POLICY business_documents_member_read ON public.business_documents
USING (private.has_company_role(company_id, ARRAY['owner','admin','manager','viewer']::text[]));
ALTER POLICY customers_member_read ON public.customers
USING (private.has_company_role(company_id, ARRAY['owner','admin','manager','viewer']::text[]));
ALTER POLICY financial_entries_member_read ON public.financial_entries
USING (private.has_company_role(company_id, ARRAY['owner','admin','manager','viewer']::text[]));
ALTER POLICY products_member_read ON public.products
USING (private.has_company_role(company_id, ARRAY['owner','admin','manager','viewer']::text[]));
ALTER POLICY purchase_items_member_select ON public.purchase_order_items
USING (private.has_company_role(company_id, ARRAY['owner','admin','manager','viewer']::text[]));
ALTER POLICY purchase_orders_member_select ON public.purchase_orders
USING (private.has_company_role(company_id, ARRAY['owner','admin','manager','viewer']::text[]));
ALTER POLICY sale_items_member_read ON public.sale_items
USING (private.has_company_role(company_id, ARRAY['owner','admin','manager','viewer']::text[]));
ALTER POLICY sales_member_read ON public.sales
USING (private.has_company_role(company_id, ARRAY['owner','admin','manager','viewer']::text[]));
ALTER POLICY stock_movements_member_read ON public.stock_movements
USING (private.has_company_role(company_id, ARRAY['owner','admin','manager','viewer']::text[]));
ALTER POLICY suppliers_member_read ON public.suppliers
USING (private.has_company_role(company_id, ARRAY['owner','admin','manager','viewer']::text[]));
ALTER POLICY gei360_categories_member_read ON public.product_categories
USING (private.has_company_role(company_id, ARRAY['owner','admin','manager','viewer']::text[]));

DROP POLICY IF EXISTS company_documents_member_read ON storage.objects;
CREATE POLICY company_documents_member_read
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'company-documents'
  AND EXISTS (
    SELECT 1
    FROM public.company_members cm
    WHERE cm.company_id::text = (storage.foldername(objects.name))[1]
      AND cm.user_id = (SELECT auth.uid())
      AND cm.status = 'active'
      AND cm.role = ANY (ARRAY['owner','admin','manager','viewer']::text[])
  )
);

-- A restrictive policy ANDs with all existing role policies, so the module
-- switch is enforced for direct REST calls as well as for the app navigation.
DO $module_gates$
DECLARE
  item record;
  policy_name text;
BEGIN
  FOR item IN
    SELECT * FROM (VALUES
      ('business_documents','fiscal'),
      ('customers','cadastros'),
      ('financial_entries','financeiro'),
      ('product_categories','cadastros'),
      ('products','produtos_servicos'),
      ('purchase_order_items','compras'),
      ('purchase_orders','compras'),
      ('sale_items','vendas'),
      ('sales','vendas'),
      ('stock_movements','estoque'),
      ('suppliers','cadastros'),
      ('employees','rh'),
      ('employee_compensation','rh'),
      ('hr_company_settings','rh'),
      ('hr_cost_postings','rh'),
      ('hr_events','rh'),
      ('hr_holidays','rh'),
      ('hr_schedule_exceptions','rh'),
      ('hr_time_adjustments','rh'),
      ('hr_time_bank_entries','rh'),
      ('hr_time_occurrences','rh'),
      ('hr_time_periods','rh'),
      ('hr_time_punches','rh'),
      ('hr_time_rules','rh'),
      ('hr_work_schedules','rh')
    ) AS v(table_name,module_code)
  LOOP
    policy_name := 'gei_module_gate_' || item.table_name;
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', policy_name, item.table_name);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I AS RESTRICTIVE FOR ALL TO authenticated USING (private.is_company_module_enabled(company_id, %L)) WITH CHECK (private.is_company_module_enabled(company_id, %L))',
      policy_name, item.table_name, item.module_code, item.module_code
    );
  END LOOP;
END
$module_gates$;

DROP POLICY IF EXISTS gei_module_gate_gei_records ON public.gei_records;
CREATE POLICY gei_module_gate_gei_records
ON public.gei_records
AS RESTRICTIVE
FOR ALL
TO authenticated
USING (
  private.is_company_module_enabled(company_id, 'servicos')
  OR private.is_company_module_enabled(company_id, 'industria')
)
WITH CHECK (
  private.is_company_module_enabled(company_id, 'servicos')
  OR private.is_company_module_enabled(company_id, 'industria')
);

DROP POLICY IF EXISTS gei_module_gate_company_documents ON storage.objects;
CREATE POLICY gei_module_gate_company_documents
ON storage.objects
AS RESTRICTIVE
FOR ALL
TO authenticated
USING (
  bucket_id <> 'company-documents'
  OR EXISTS (
    SELECT 1
    FROM public.company_members cm
    JOIN public.gei_module_catalog c
      ON c.code = 'fiscal' AND c.is_available = true
    LEFT JOIN public.company_modules m
      ON m.company_id = cm.company_id AND m.module_code = c.code
    WHERE cm.company_id::text = (storage.foldername(objects.name))[1]
      AND cm.user_id = (SELECT auth.uid())
      AND cm.status = 'active'
      AND (c.is_core = true OR COALESCE(m.is_enabled, true) = true)
  )
)
WITH CHECK (
  bucket_id <> 'company-documents'
  OR EXISTS (
    SELECT 1
    FROM public.company_members cm
    JOIN public.gei_module_catalog c
      ON c.code = 'fiscal' AND c.is_available = true
    LEFT JOIN public.company_modules m
      ON m.company_id = cm.company_id AND m.module_code = c.code
    WHERE cm.company_id::text = (storage.foldername(objects.name))[1]
      AND cm.user_id = (SELECT auth.uid())
      AND cm.status = 'active'
      AND (c.is_core = true OR COALESCE(m.is_enabled, true) = true)
  )
);

COMMENT ON FUNCTION private.is_company_module_enabled(uuid, text)
IS 'Checks active company membership and the company-specific module switch; used by RLS restrictive policies';

COMMIT;
