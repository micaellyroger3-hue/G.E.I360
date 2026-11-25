-- G.E.I360 | Keep RLS helper implementations out of the exposed public API.
-- Existing policies keep their function dependencies when ALTER FUNCTION moves
-- the original OIDs into the non-exposed private schema.
BEGIN;

CREATE SCHEMA IF NOT EXISTS private AUTHORIZATION postgres;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA private TO authenticated, service_role;

ALTER FUNCTION public.has_company_role(uuid, text[]) SET SCHEMA private;
ALTER FUNCTION public.is_company_member(uuid) SET SCHEMA private;

REVOKE ALL ON FUNCTION private.has_company_role(uuid, text[]) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.is_company_member(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.has_company_role(uuid, text[]) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.is_company_member(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.has_company_role(
  p_company_id uuid,
  p_roles text[]
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path TO ''
AS $function$
  SELECT private.has_company_role(p_company_id, p_roles);
$function$;

CREATE OR REPLACE FUNCTION public.is_company_member(
  p_company_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path TO ''
AS $function$
  SELECT private.is_company_member(p_company_id);
$function$;

REVOKE ALL ON FUNCTION public.has_company_role(uuid, text[]) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_company_member(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_company_role(uuid, text[]) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_company_member(uuid) TO authenticated, service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA private
REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon, authenticated;

COMMENT ON SCHEMA private IS 'Internal G.E.I360 database helpers; do not expose through PostgREST';
COMMENT ON FUNCTION public.has_company_role(uuid, text[]) IS 'SECURITY INVOKER compatibility wrapper; implementation is private.has_company_role';
COMMENT ON FUNCTION public.is_company_member(uuid) IS 'SECURITY INVOKER compatibility wrapper; implementation is private.is_company_member';

COMMIT;
