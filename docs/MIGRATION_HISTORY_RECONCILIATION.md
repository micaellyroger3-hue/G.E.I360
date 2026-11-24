# Reconciliação do histórico de migrations — G.E.I360

**Auditoria em 23/11/2026. Somente leitura no banco; arquivos recuperados em branch isolada.**

## Resultado atual

| Fonte | Quantidade |
|---|---:|
| Histórico remoto Supabase | 36 |
| Arquivos locais originais em `supabase/migrations` | 39 |
| Migrations remotas sem arquivo correspondente antes desta revisão | 3 |
| Arquivos locais sem nome correspondente remoto | 5 |
| Nomes coincidentes com prefixos diferentes | 23 |

O histórico remoto armazena não apenas versão e nome, mas também os SQLs aplicados em `supabase_migrations.schema_migrations.statements`. Foi possível recuperar o SQL exato das três migrations remotas que não tinham arquivo no repositório.

## Arquivos recuperados nesta branch

- `20261111213231_foreign_key_indexes_rls_tuning.sql`
- `20261111213250_deduplicate_category_policies.sql`
- `20261119153922_hr_timekeeping_and_hourly_pay.sql`

Os conteúdos foram reconstruídos diretamente do registro de migrations aplicado no Supabase, sem executar novamente esses SQLs no banco. Os arquivos estão somente nesta branch de documentação/reconciliação; ainda não foram integrados à `main`.

## Arquivos locais sem nome correspondente remoto

- `202611070001_employees.sql` — legado; confirmar se seus efeitos estão cobertos pelo schema atual.
- `202611080001_erp_modules.sql` — legado; confirmar cobertura atual.
- `202611080002_finance_links.sql` — confirmar triggers e vínculos financeiros existentes.
- `202611080003_protect_linked_finance.sql` — confirmar trigger/proteção existente.
- `20261119170000_hr_timekeeping.sql` — provável versão antiga do SQL agora recuperado como `hr_timekeeping_and_hourly_pay`; precisa comparação de conteúdo.

## Nomes coincidentes, prefixos diferentes

| Nome | Prefixo local | Versão remota |
|---|---:|---:|
| `integrity_hardening` | 202611090001 | 20261111213202 |
| `product_categories` | 202611100001 | 20261111213207 |
| `company_business_profiles` | 202611100002 | 20261111213135 |
| `product_barcode_integrity` | 202611100003 | 20261111213209 |
| `employee_integrity` | 202611110001 | 20261111213213 |
| `api_privilege_hardening` | 202611120001 | 20261111213334 |
| `gei_records_role_guard` | 20261116085000 | 20261116085058 |
| `least_privilege_cleanup` | 20261116121000 | 20261116090458 |
| `business_activity_detail` | 20261116122000 | 20261116090607 |
| `business_activity_detail_permissions` | 20261116123000 | 20261116090633 |
| `hr_management` | 20261119130000 | 20261119131748 |
| `hr_privilege_tightening` | 20261119132000 | 20261119131816 |
| `hr_fk_indexes` | 20261119133000 | 20261119131859 |
| `hr_timekeeping_index_policy_tuning` | 20261119173000 | 20261119153948 |
| `hr_punch_clock_timestamp` | 20261119180000 | 20261119154117 |
| `hr_time_calculation_and_closing` | 20261119170000 e 20261119190000 | 20261119162418 |
| `hr_occurrences_composite_fk_index` | 20261119191000 | 20261119162606 |
| `revoke_unsafe_default_privileges` | 20261123090000 | 20261123130925 |
| `hr_employee_self_read` | 20261123100000 | 20261123130928 |
| `move_rls_helpers_private` | 20261123101000 | 20261123130931 |
| `enforce_employee_role_and_module_access` | 20261123102000 | 20261123132034 |
| `revoke_public_sequence_privileges` | 20261123113000 | 20261123132745 |
| `move_privileged_rpcs_to_private` | 20261123123000 | 20261123133003 |

## Duplicidades e observações

- Dois arquivos locais chamados `hr_time_calculation_and_closing` usam o mesmo prefixo `20261119170000` e `20261119190000`; o remoto registra uma única migration.
- O arquivo local `hr_timekeeping.sql` também usa o prefixo `20261119170000`, criando colisão de versão com o cálculo/fechamento.
- A migration remota `hr_timekeeping_and_hourly_pay` tem SQL de 12 KB e foi recuperada literalmente do histórico do banco.
- A migration remota `foreign_key_indexes_rls_tuning` inclui geração de índices para FKs sem cobertura e ajuste de policy de `gei_records`.
- A migration `deduplicate_category_policies` remove quatro policies legadas de categorias.

## Próximas ações seguras

1. Não aplicar nenhuma migration no projeto de produção: o banco já registra as 36 versões.
2. Comparar os 39 arquivos locais com os 36 SQLs remotos, por conteúdo, e não só pelo nome.
3. Identificar e preservar os quatro arquivos legados que não têm par remoto.
4. Resolver a colisão de prefixo `20261119170000` e remover da pasta ativa somente os arquivos comprovadamente já representados pelo histórico remoto.
5. Manter um snapshot dos arquivos originais fora de `supabase/migrations` antes de qualquer reorganização.
6. Rodar `supabase migration list` e `supabase db push --dry-run` em computador com CLI, antes de qualquer push.
7. Fazer backup e provar restauração em projeto separado antes de alterar a organização final.

**Bloqueio:** não executar `db push`, `db reset --linked`, `migration repair` nem alterar a tabela de histórico remoto nesta etapa. Não foi feita nenhuma alteração no schema, dados ou histórico de produção.
