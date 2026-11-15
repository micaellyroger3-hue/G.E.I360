-- G.E.I360 | ARQUIVO DESATIVADO POR SEGURANÇA
-- NÃO EXECUTE COMO INSTALADOR.
--
-- O projeto Supabase alvo já possuía schema e dados antes desta revisão,
-- mas seu histórico de migrations estava vazio. A sequência histórica do
-- repositório não corresponde integralmente ao schema preexistente.
--
-- Executar o antigo pacote consolidado poderia ignorar colunas já existentes,
-- duplicar políticas/constraints ou falhar em objetos com formatos diferentes.
-- O banco foi corrigido por migrations direcionadas, registradas no Supabase.
--
-- Migrations aplicadas e verificadas:
-- company_business_profiles
-- integrity_hardening
-- product_categories
-- product_barcode_integrity
-- employee_integrity
-- foreign_key_indexes_rls_tuning
-- deduplicate_category_policies
-- api_privilege_hardening
--
-- Antes de qualquer nova migration:
-- 1. Faça backup.
-- 2. Consulte Supabase > Database > Migrations.
-- 3. Compare o schema real com o arquivo específico da migration.
-- 4. Faça preflight de dados, constraints, colunas e políticas.
-- 5. Aplique somente a migration compatível e teste em seguida.
--
-- Esta consulta é apenas um marcador inofensivo para que o arquivo continue
-- válido como SQL; ela não altera o banco.
select
  'INSTALLER_DISABLED_SCHEMA_DRIFT'::text as status,
  current_database() as database_name,
  now() as checked_at;
