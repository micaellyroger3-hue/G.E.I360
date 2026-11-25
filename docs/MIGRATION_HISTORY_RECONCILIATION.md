# Reconciliação do histórico de migrations — G.E.I360

**Atualização em 25/11/2026. Auditoria remota somente leitura; sem execução de SQL de alteração.**

## Estado conferido

| Fonte | Quantidade |
|---|---:|
| Histórico remoto Supabase | 36 versões |
| Arquivos SQL em `supabase/migrations` | 40 |
| Versões remotas com arquivo canônico ativo correspondente | 36 |
| Arquivos legados adicionais ainda ativos | 4 |
| Cópias históricas em `supabase/migrations_archive` | 29 |

As 36 versões retornadas por `supabase migration list` foram conferidas contra os nomes canônicos presentes na pasta ativa. Os três SQLs que faltavam na auditoria anterior foram recuperados do histórico remoto e agora estão no repositório:
- `20261111213231_foreign_key_indexes_rls_tuning.sql`
- `20261111213250_deduplicate_category_policies.sql`
- `20261119153922_hr_timekeeping_and_hourly_pay.sql`

## Quatro migrations-base históricas adicionais

Estes quatro arquivos continuam na pasta ativa, mas não aparecem como versões no histórico remoto:
- `202611070001_employees.sql`
- `202611080001_erp_modules.sql`
- `202611080002_finance_links.sql`
- `202611080003_protect_linked_finance.sql`

Os objetos centrais relacionados foram encontrados no banco em consultas somente leitura. Isso não prova, por si só, que executar novamente esses quatro SQLs seja seguro. Eles também estão preservados em `supabase/migrations_archive/`. Não apagar nem mover da pasta ativa até conferir o comportamento do Supabase CLI e revisar cada SQL.

## Arquivos históricos e duplicidades

- Prefixos antigos que representam migrations remotas foram preservados no arquivo histórico com prefixo `legacy-prefix-`.
- Cópias antigas de RH foram arquivadas para preservar o conteúdo original e evitar colisões de versões na pasta ativa.
- O arquivo `20261119170000_hr_timekeeping.sql` e as cópias antigas de cálculo/fechamento foram mantidos em arquivo, não descartados.
- A pasta ativa contém os 36 nomes correspondentes às versões remotas e quatro arquivos-base adicionais.

## Segurança e produção

- A lista remota registra 36 versões.
- Nenhum `db push`, `db reset`, `migration repair` ou SQL de alteração foi executado nesta revisão.
- A consulta remota encontrou 33/33 tabelas públicas com RLS habilitado; FORCE RLS está desativado nas 33. Não foi alterado.
- O papel `anon` não tem concessões diretas de SELECT/INSERT/UPDATE/DELETE nas 33 tabelas públicas examinadas.
- A proteção contra senhas vazadas permanece desativada no Auth, conforme aviso do Advisor.

## Próximas ações seguras — exigem computador

1. No checkout desta branch, executar `supabase migration list` e guardar a saída.
2. Executar `supabase db push --dry-run`; não confirmar/aplicar nada.
3. Se o dry-run propor aplicar qualquer uma das quatro migrations-base históricas, parar e revisar o SQL completo, pois seus objetos já existem em produção.
4. Comparar o plano do CLI com as 36 versões remotas e confirmar que nenhuma migration canônica será reaplicada.
5. Fazer backup lógico, cópias separadas de Storage/Auth/Edge Functions e provar restauração em projeto separado antes de qualquer mudança de produção.

**Bloqueio mantido:** não executar `db push`, `db reset --linked`, `migration repair` nem alterar a tabela remota de histórico até concluir essas verificações e a restauração de ensaio.
