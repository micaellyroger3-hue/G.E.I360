-- Keep PostgREST-facing RPCs as SECURITY INVOKER wrappers.
-- Their privileged implementations live in the non-exposed private schema.
BEGIN;

ALTER FUNCTION public.create_company(text,text) SET SCHEMA private;
ALTER FUNCTION public.create_sale_cart(uuid,uuid,jsonb,numeric,text) SET SCHEMA private;
ALTER FUNCTION public.hr_claim_employee_account() SET SCHEMA private;
ALTER FUNCTION public.hr_register_time_punch(uuid,text) SET SCHEMA private;
ALTER FUNCTION public.receive_purchase_cart(uuid,uuid,jsonb,text) SET SCHEMA private;
ALTER FUNCTION public.record_stock_movement(uuid,uuid,text,numeric,numeric,text) SET SCHEMA private;

CREATE FUNCTION public.create_company(
  p_name text,
  p_tax_id text DEFAULT NULL::text
)
RETURNS uuid
LANGUAGE sql
SECURITY INVOKER
SET search_path TO ''
AS $function$
  SELECT private.create_company(p_name,p_tax_id);
$function$;

CREATE FUNCTION public.create_sale_cart(
  p_company_id uuid,
  p_customer_id uuid,
  p_items jsonb,
  p_discount numeric DEFAULT 0,
  p_notes text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE sql
SECURITY INVOKER
SET search_path TO ''
AS $function$
  SELECT private.create_sale_cart(p_company_id,p_customer_id,p_items,p_discount,p_notes);
$function$;

CREATE FUNCTION public.hr_claim_employee_account()
RETURNS integer
LANGUAGE sql
SECURITY INVOKER
SET search_path TO ''
AS $function$
  SELECT private.hr_claim_employee_account();
$function$;

CREATE FUNCTION public.hr_register_time_punch(
  p_employee_id uuid,
  p_punch_type text
)
RETURNS public.hr_time_punches
LANGUAGE sql
SECURITY INVOKER
SET search_path TO ''
AS $function$
  SELECT private.hr_register_time_punch(p_employee_id,p_punch_type);
$function$;

CREATE FUNCTION public.receive_purchase_cart(
  p_company_id uuid,
  p_supplier_id uuid,
  p_items jsonb,
  p_notes text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE sql
SECURITY INVOKER
SET search_path TO ''
AS $function$
  SELECT private.receive_purchase_cart(p_company_id,p_supplier_id,p_items,p_notes);
$function$;

CREATE FUNCTION public.record_stock_movement(
  p_company_id uuid,
  p_product_id uuid,
  p_movement_type text,
  p_quantity numeric,
  p_unit_cost numeric DEFAULT 0,
  p_note text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE sql
SECURITY INVOKER
SET search_path TO ''
AS $function$
  SELECT private.record_stock_movement(p_company_id,p_product_id,p_movement_type,p_quantity,p_unit_cost,p_note);
$function$;

REVOKE ALL ON FUNCTION private.create_company(text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.create_sale_cart(uuid,uuid,jsonb,numeric,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.hr_claim_employee_account() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.hr_register_time_punch(uuid,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.receive_purchase_cart(uuid,uuid,jsonb,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.record_stock_movement(uuid,uuid,text,numeric,numeric,text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION private.create_company(text,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.create_sale_cart(uuid,uuid,jsonb,numeric,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.hr_claim_employee_account() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.hr_register_time_punch(uuid,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.receive_purchase_cart(uuid,uuid,jsonb,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.record_stock_movement(uuid,uuid,text,numeric,numeric,text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.create_company(text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.create_sale_cart(uuid,uuid,jsonb,numeric,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.hr_claim_employee_account() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.hr_register_time_punch(uuid,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.receive_purchase_cart(uuid,uuid,jsonb,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.record_stock_movement(uuid,uuid,text,numeric,numeric,text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.create_company(text,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_sale_cart(uuid,uuid,jsonb,numeric,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.hr_claim_employee_account() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.hr_register_time_punch(uuid,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.receive_purchase_cart(uuid,uuid,jsonb,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.record_stock_movement(uuid,uuid,text,numeric,numeric,text) TO authenticated, service_role;

COMMENT ON FUNCTION public.create_company(text,text) IS 'SECURITY INVOKER RPC wrapper; privileged implementation is private.create_company';
COMMENT ON FUNCTION public.create_sale_cart(uuid,uuid,jsonb,numeric,text) IS 'SECURITY INVOKER RPC wrapper; privileged implementation is private.create_sale_cart';
COMMENT ON FUNCTION public.hr_claim_employee_account() IS 'SECURITY INVOKER RPC wrapper; privileged implementation is private.hr_claim_employee_account';
COMMENT ON FUNCTION public.hr_register_time_punch(uuid,text) IS 'SECURITY INVOKER RPC wrapper; privileged implementation is private.hr_register_time_punch';
COMMENT ON FUNCTION public.receive_purchase_cart(uuid,uuid,jsonb,text) IS 'SECURITY INVOKER RPC wrapper; privileged implementation is private.receive_purchase_cart';
COMMENT ON FUNCTION public.record_stock_movement(uuid,uuid,text,numeric,numeric,text) IS 'SECURITY INVOKER RPC wrapper; privileged implementation is private.record_stock_movement';

COMMIT;
