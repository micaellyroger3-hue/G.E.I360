-- G.E.I360 | Remoção de privilégios DML sem uso e catálogo somente leitura
-- Mantém políticas RLS como autorização por linha; reduz a superfície de escrita da API.
BEGIN;

-- O catálogo é administrado por migrations, não pelo navegador do cliente.
REVOKE ALL PRIVILEGES ON TABLE public.gei_module_catalog FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.gei_module_catalog TO authenticated;

-- Não há fluxo de exclusão de empresas/membros no frontend atual.
-- Remover grants que não possuem policy correspondente e não são usados pela aplicação.
REVOKE DELETE ON TABLE public.companies FROM authenticated;
REVOKE DELETE ON TABLE public.company_members FROM authenticated;

-- Perfis são criados pelo trigger confiável de Auth; o cliente só edita/lê o próprio perfil.
REVOKE INSERT, DELETE ON TABLE public.profiles FROM authenticated;

COMMIT;
