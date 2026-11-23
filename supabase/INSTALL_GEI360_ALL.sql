-- G.E.I360 | ARQUIVO DESATIVADO POR SEGURANÇA
-- NÃO EXECUTE COMO INSTALADOR.
--
-- Estado verificado em 23/11/2026:
-- - histórico remoto Supabase: 36 migrations;
-- - repositório: 39 arquivos em supabase/migrations;
-- - 3 nomes remotos sem arquivo local, 5 arquivos locais sem nome remoto;
-- - vários prefixos de versão diferentes e arquivos locais duplicados.
--
-- O schema e os dados de produção estão ativos, mas o histórico local/remoto
-- precisa ser reconciliado antes de qualquer db push, reset --linked ou restore.
-- O antigo pacote consolidado não é uma fonte confiável para recriar produção.
--
-- Não foram alterados dados ou histórico de migrations nesta auditoria.
-- Consulte docs/MIGRATION_HISTORY_RECONCILIATION.md e
-- docs/BACKUP_RESTORE_RUNBOOK.md antes de qualquer operação.
--
-- Esta consulta é apenas um marcador inofensivo para que o arquivo continue
-- válido como SQL; ela não altera o banco.
select
  'INSTALLER_DISABLED_SCHEMA_DRIFT'::text as status,
  current_database() as database_name,
  now() as checked_at;
