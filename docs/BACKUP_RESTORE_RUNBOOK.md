# Backup e restauração — G.E.I360

## Estado atual e limites do plano

## Gate obrigatório: reconciliação do histórico de migrations

Atualização da auditoria em 25/11/2026:
- Histórico remoto do Supabase: **36 versões**.
- Repositório: **40 arquivos SQL ativos** em `supabase/migrations`.
- As 36 versões remotas agora têm arquivos canônicos ativos correspondentes; os três SQLs ausentes foram recuperados do histórico aplicado.
- Quatro migrations-base históricas adicionais (`employees`, `erp_modules`, `finance_links`, `protect_linked_finance`) continuam ativas, mas não constam no histórico remoto. Os objetos centrais correspondentes foram encontrados no banco, mas o CLI precisa confirmar se as trataria como pendentes.
- Cópias históricas antigas estão preservadas em `supabase/migrations_archive/`.
- Dois arquivos locais chamados `hr_time_calculation_and_closing` usam os prefixos `20261119170000` e `20261119190000`; o arquivo `hr_timekeeping` também usa `20261119170000`, criando colisão de versão; o remoto registra apenas uma versão de cálculo/fechamento e outra de ponto/folha.

**Não execute** `supabase db push`, `supabase db reset --linked` ou `supabase migration repair` antes de revisar a matriz em `docs/MIGRATION_HISTORY_RECONCILIATION.md`), fazer backup e confirmar quais arquivos representam exatamente cada migration remota. A correção do histórico altera metadados de implantação e pode fazer o CLI reaplicar SQL; não foi feita nesta revisão.

Depois de reconciliar em computador:
1. Rode `supabase migration list` e compare com a matriz.
2. Confirme no CLI que as 36 versões remotas estão reconhecidas.
3. Revise as quatro migrations-base extras e não permita que sejam reaplicadas sem validação explícita.
4. Rode `supabase db push --dry-run`; interrompa se propor aplicar qualquer SQL já refletido no banco.
5. Só então execute o fluxo de backup e restore em projeto separado.


A organização está no plano Free. O Supabase informa que:
- projetos Free não têm backups automáticos gerenciados para download;
- o Free não inclui branching;
- projetos Free devem exportar dados regularmente com Supabase CLI e manter cópias off-site;
- o CLI exclui os schemas gerenciados `auth`, `storage` e schemas de extensões; o dump padrão também não inclui dados nem roles;
- arquivos do Storage não são incluídos no backup do banco.

Portanto, ainda não existe backup/restauração integral comprovado para este projeto. Não marcar esta etapa como concluída até restaurar em projeto separado e verificar dados, Auth, Storage e funções.

## Backup lógico manual (requer computador)

Requisitos: Supabase CLI, Docker Desktop, PostgreSQL/psql e espaço seguro para os arquivos. Use um terminal local. Não cole senhas, connection strings, tokens ou chaves no ChatGPT, GitHub, issues ou neste repositório.

1. Obtenha a connection string do banco de produção no painel Supabase, em Connect. Use uma variável de ambiente no terminal, não um arquivo versionado:

```bash
export OLD_DB_URL='postgresql://...'
mkdir -p "$HOME/gei360-backup"
cd "$HOME/gei360-backup"
```

2. Gere os três arquivos de banco conforme a documentação oficial:

```bash
supabase db dump --remote="$OLD_DB_URL" -f roles.sql --role-only
supabase db dump --remote="$OLD_DB_URL" -f schema.sql
supabase db dump --remote="$OLD_DB_URL" -f data.sql --use-copy --data-only -x "storage.buckets_vectors" -x "storage.vector_indexes"
```

3. Proteja os arquivos com criptografia e guarde uma cópia fora do GitHub e fora do próprio projeto Supabase. Não faça commit desses arquivos: eles podem conter dados pessoais e financeiros.

## Restauração em projeto separado

Nunca restaure o backup de teste sobre o projeto de produção.

1. Crie ou selecione um projeto Supabase separado para homologação.
2. Configure nele extensões e webhooks usados pelo projeto.
3. Obtenha a connection string do projeto de teste e defina-a localmente como `RESTORE_DB_URL`.
4. Antes do restore, revogue privilégios padrão herdados no destino:

```sql
ALTER DEFAULT PRIVILEGES IN SCHEMA public
REVOKE ALL ON TABLES FROM anon, authenticated;
```

5. Restaure os arquivos com a sequência oficial:

```bash
psql \
  --single-transaction \
  --variable ON_ERROR_STOP=1 \
  --file roles.sql \
  --file schema.sql \
  --command 'SET session_replication_role = replica' \
  --file data.sql \
  --dbname "$RESTORE_DB_URL"
```

6. Verifique tabelas, contagens, migrations, RLS, policies, grants, funções e isolamento. Execute os testes transacionais já usados no projeto. Não conecte o frontend de clientes ao projeto de restauração.

## O que precisa de cópia separada

O dump lógico não transporta tudo:
- **Storage:** copiar os objetos do bucket privado `company-documents` por Storage API/CLI; banco guarda apenas metadados.
- **Auth:** usuários, configurações de autenticação, templates, URLs e chaves precisam de procedimento próprio. Não copiar senhas nem tokens para o Git.
- **Edge Functions:** o código está no repositório; implantar no projeto de teste e configurar os secrets no painel, sem expô-los.
- **Realtime, extensões, webhooks e configurações do projeto:** reconfigurar e validar no destino.
- **Vault/pgsodium:** se estiverem em uso, seguir o procedimento oficial de cópia da root encryption key antes de pausar/remover o projeto antigo.

## Prova de restauração exigida

A etapa só fica concluída quando:
- o backup tem data, tamanho e checksum registrados;
- uma restauração é concluída em projeto separado;
- as contagens esperadas são comparadas sem expor dados pessoais;
- Storage objects são copiados e abertos com permissão correta;
- Auth/Edge Functions e políticas são reconfigurados;
- CI e testes de isolamento passam no projeto restaurado.

## Links oficiais

- Database Backups: https://supabase.com/docs/guides/platform/backups
- Backup and Restore using the CLI: https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore
- Supabase CLI db dump: https://supabase.com/docs/reference/cli/supabase-db-dump
- Password security: https://supabase.com/docs/guides/auth/password-security
- Pricing: https://supabase.com/pricing

## Resultado conhecido do dry-run das quatro migrations-base

A pasta ativa contém quatro versões que não estão no histórico remoto: 202611070001, 202611080001, 202611080002 e 202611080003. Portanto, espere que supabase migration list --remote as mostre como locais pendentes e que supabase db push --dry-run --remote as liste para aplicação. Isso é um bloqueio conhecido, não um teste que libera o push. Se aparecerem, não confirme nem execute db push.

A auditoria de leitura confirmou os principais objetos resultantes no banco, mas a migration 202611080001_erp_modules.sql contém um delimitador de função malformado na função record_stock_movement (AS $ / $;) e reintroduz definições antigas de RPCs/grants. Não reaplicar esses SQLs históricos. A decisão entre arquivar, criar uma baseline reproduzível ou marcar versões como aplicadas por migration repair exige backup restaurável e comparação integral; não faça isso por tentativa.
