-- G.E.I360 | Privilégio mínimo para objetos do schema public
-- Corrige grants estruturais existentes e impede que novas tabelas/funções
-- criadas pelo papel postgres herdem acesso amplo para anon/authenticated.
-- Não altera linhas, políticas RLS, ownership ou dados empresariais.

BEGIN;

-- TRUNCATE não é filtrado por RLS. REFERENCES/TRIGGER/MAINTAIN não são
-- necessários para operações normais do aplicativo via PostgREST.
REVOKE TRUNCATE, REFERENCES, TRIGGER, MAINTAIN
ON ALL TABLES IN SCHEMA public
FROM anon, authenticated;

-- Novos objetos devem receber somente os grants explícitos definidos
-- na migration que os cria.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
REVOKE ALL ON TABLES FROM anon, authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
REVOKE ALL ON SEQUENCES FROM anon, authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
REVOKE EXECUTE ON FUNCTIONS FROM anon, authenticated;

COMMIT;
