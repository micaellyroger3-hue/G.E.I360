-- Prevent authenticated employees/managers from creating additional companies.
-- First-company onboarding remains available to users with no company membership.
CREATE OR REPLACE FUNCTION public.create_company(
    p_name text,
    p_tax_id text DEFAULT NULL::text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_user_id uuid;
    v_company_id uuid;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Usuário não autenticado.';
    END IF;

    -- Serialize concurrent first-company attempts for the same account.
    PERFORM pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(v_user_id::text, 0)
    );

    -- A user with existing memberships may create another company only
    -- when at least one active membership grants owner/admin privileges.
    IF EXISTS (
        SELECT 1
        FROM public.company_members
        WHERE user_id = v_user_id
    ) AND NOT EXISTS (
        SELECT 1
        FROM public.company_members
        WHERE user_id = v_user_id
          AND status = 'active'
          AND role IN ('owner', 'admin')
    ) THEN
        RAISE EXCEPTION 'Somente proprietário ou administrador pode criar outra empresa.';
    END IF;

    IF NULLIF(TRIM(p_name), '') IS NULL THEN
        RAISE EXCEPTION 'O nome da empresa é obrigatório.';
    END IF;

    INSERT INTO public.companies (
        name,
        tax_id,
        created_by
    )
    VALUES (
        TRIM(p_name),
        NULLIF(TRIM(p_tax_id), ''),
        v_user_id
    )
    RETURNING id INTO v_company_id;

    RETURN v_company_id;
END;
$function$;

-- Keep the RPC callable by signed-in users only; authorization is enforced above.
REVOKE ALL ON FUNCTION public.create_company(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_company(text, text) TO authenticated, service_role;
