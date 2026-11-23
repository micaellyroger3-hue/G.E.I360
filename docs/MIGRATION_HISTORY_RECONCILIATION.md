# Reconciliação do histórico de migrations — G.E.I360

**Auditoria somente leitura em 23/11/2026. Não executar reparo ainda.**

## Resumo

| Fonte | Quantidade |
|---|---:|
| Histórico remoto Supabase | 36 |
| Arquivos locais em `supabase/migrations` | 39 |
| Nomes remotos sem arquivo local | 3 |
| Arquivos locais sem nome remoto correspondente | 5 |
| Nomes correspondentes com prefixo de versão diferente | 23 |

O histórico remoto foi criado/atualizado por aplicações de migration via Supabase. Os arquivos locais mantêm prefixos de timestamp diferentes. O CLI compara versões, não apenas nomes; portanto, um `supabase db push` pode considerar arquivos já aplicados como pendentes.

## Remotas sem arquivo local

| Versão remota | Nome |
|---|---|
| 20261111213231 | `foreign_key_indexes_rls_tuning` |
| 20261111213250 | `deduplicate_category_policies` |
| 20261119153922 | `hr_timekeeping_and_hourly_pay` |

O SQL exato dessas três aplicações ainda não foi identificado entre os arquivos locais. Não criar migrations vazias para fingir que estão representadas.

## Arquivos locais sem nome correspondente remoto

| Arquivo local | Observação |
|---|---|
| `202611070001_employees.sql` | Migration inicial/legada; schema atual de RH evoluiu |
| `202611080001_erp_modules.sql` | Migration inicial/legada do ERP |
| `202611080002_finance_links.sql` | Triggers/links financeiros legados; confirmar cobertura no banco |
| `202611080003_protect_linked_finance.sql` | Trigger de proteção financeira legado; confirmar cobertura |
| `20261119170000_hr_timekeeping.sql` | Possível correspondência com `hr_timekeeping_and_hourly_pay`; não confirmada |

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
| `hr_time_calculation_and_closing` | 20261119170000 **e** 20261119190000 | 20261119162418 |
| `hr_occurrences_composite_fk_index` | 20261119191000 | 20261119162606 |
| `revoke_unsafe_default_privileges` | 20261123090000 | 20261123130925 |
| `hr_employee_self_read` | 20261123100000 | 20261123130928 |
| `move_rls_helpers_private` | 20261123101000 | 20261123130931 |
| `enforce_employee_role_and_module_access` | 20261123102000 | 20261123132034 |
| `revoke_public_sequence_privileges` | 20261123113000 | 20261123132745 |
| `move_privileged_rpcs_to_private` | 20261123123000 | 20261123133003 |

## Duplicidades e correspondências ainda não provadas

- Existem dois arquivos locais chamados `hr_time_calculation_and_closing`, um com 220 linhas e outro com 352 linhas, enquanto o remoto registra uma única versão.
- O arquivo `hr_timekeeping.sql` pode corresponder à migration remota `hr_timekeeping_and_hourly_pay`, mas a equivalência precisa ser confirmada pelo conteúdo e pelo schema.
- A tabela `gei_records` atual usa `module_code`, `record_type` e `payload`; a migration antiga do PR #1 usa `module` e `data`, portanto é obsoleta e não deve ser aplicada.

## Plano seguro

1. Fazer backup antes de tocar no histórico.
2. Em computador com Supabase CLI, executar `supabase migration list` e salvar a saída.
3. Recuperar o SQL exato das três migrations remotas sem arquivo (Git history, branch antiga ou dump revisado).
4. Confirmar quais migrations locais são legadas e quais são a fonte real de cada objeto.
5. Criar uma branch que alinhe nomes/versões sem mudar o schema de produção.
6. Usar `supabase migration repair` somente para versões cuja equivalência tenha sido comprovada; essa operação altera a tabela de histórico.
7. Rodar `supabase db push --dry-run` e revisar cada operação antes de qualquer push real.
8. Repetir o processo em um projeto de homologação antes de considerar o histórico sincronizado.

**Proibido nesta etapa:** `db push`, `db reset --linked`, exclusão de migrations, reparo de histórico ou qualquer alteração destrutiva em produção.
