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


## Verificação adicional por conteúdo — 24/11/2026

Comparação dos arquivos na branch de reconciliação:

- `supabase/migrations/20261119170000_hr_timekeeping.sql` e o arquivo recuperado `20261119153922_hr_timekeeping_and_hourly_pay.sql` têm o mesmo blob SHA do GitHub (`77928cf3f26279c9cf3883fc6cf779e0ccf7bdd0`) e 12.005 caracteres. É uma duplicação exata do conteúdo; manter ambos na pasta ativa faria o CLI enxergar duas versões distintas para o mesmo SQL.
- Há três arquivos de RH com colisão no prefixo `20261119170000`: `hr_timekeeping.sql` (12.005 caracteres), `hr_time_calculation_and_closing.sql` (12.505 caracteres) e `hr_time_calculation_and_closing.sql` na versão `20261119190000` (21.175 caracteres). Os dois arquivos de cálculo têm conteúdos diferentes.
- O histórico remoto identifica uma única migration `hr_time_calculation_and_closing` na versão `20261119162418`. O arquivo local de versão correspondente ainda não foi recuperado/validado nesta revisão. Não escolher uma das duas versões locais por suposição.
- O SQL remoto `hr_timekeeping_and_hourly_pay` foi recuperado literalmente; o blob idêntico confirma que o arquivo local `hr_timekeeping.sql` representa exatamente essa migration, apesar do prefixo divergente.

### Decisão técnica nesta etapa

Não renomear nem excluir nenhum arquivo ativo ainda. Primeiro preservar uma cópia integral dos 39 arquivos originais, obter o SQL remoto exato da versão `20261119162418`, comparar os arquivos de cálculo por conteúdo e validar a lista resultante com `supabase migration list` e `supabase db push --dry-run` em ambiente isolado. O backup restaurável continua sendo pré-requisito para qualquer reorganização que possa influenciar um push de produção.

**Nenhum comando de push, repair, reset ou alteração do banco foi executado nesta revisão.**


## Correspondência exata da migration 20261119162418 — 24/11/2026

Consulta somente de leitura ao registro remoto `supabase_migrations.schema_migrations` recuperou o SQL integral da versão `20261119162418`, nome `hr_time_calculation_and_closing`. A comparação byte a byte (conteúdo UTF-8 retornado pelo GitHub e pelo registro remoto) confirmou:

- `supabase/migrations/20261119190000_hr_time_calculation_and_closing.sql` tem **21.175 caracteres e é idêntico** ao SQL remoto da versão `20261119162418`.
- `supabase/migrations/20261119170000_hr_time_calculation_and_closing.sql` tem **12.505 caracteres e NÃO é idêntico** ao SQL remoto. Não deve ser tratado como a migration aplicada em produção nem receber o prefixo remoto sem revisão de proveniência.
- `supabase/migrations/20261119153922_hr_timekeeping_and_hourly_pay.sql` permanece idêntico ao arquivo duplicado `20261119170000_hr_timekeeping.sql` (mesmo blob SHA já registrado acima); a versão remota correspondente é `20261119153922`.

A lista remota de migrations foi consultada novamente em 24/11/2026 e contém a versão `20261119162418` uma única vez. Portanto, a correspondência correta do SQL de apuração/fechamento foi identificada, mas a organização final dos arquivos locais ainda exige revisão controlada: não apagar nem renomear os arquivos conflitantes nesta etapa. A PR continua em rascunho; não houve `db push`, reparo de histórico, reset, aplicação de migration ou alteração de dados/schema.


## Inventário comparativo de prefixos — 24/11/2026

Nova leitura somente de consulta encontrou **36 versões remotas** e **42 arquivos SQL locais** em `supabase/migrations/`. Comparando apenas os prefixos de 14 dígitos (sem presumir equivalência de conteúdo):

- **23 das 36 versões remotas** não têm arquivo local com o mesmo prefixo.
- Existem arquivos locais sem prefixo de 14 dígitos e arquivos com prefixos que não aparecem no histórico remoto.
- Há colisão local de prefixo `20261119170000`: dois arquivos diferentes compartilham a mesma versão, além de um deles duplicar por conteúdo a migration de ponto `20261119153922`.

Esse inventário confirma que não é seguro executar `db push` nem fazer renomeação em lote com base apenas em nomes. O próximo trabalho é comparar o conteúdo de cada migration remota com os arquivos locais e produzir um mapa 1:1 (remota → arquivo local idêntico, arquivo ausente, divergência ou arquivo local legado), preservando todos os arquivos originais. Depois disso ainda será necessário validar em ambiente isolado e comprovar backup/restauração antes de qualquer operação de produção.


## Matriz de comparação integral — 24/11/2026

Método: leitura do conteúdo SQL integral das 36 linhas de `supabase_migrations.schema_migrations` e dos 42 arquivos SQL da branch. Comparação textual após normalizar CRLF para LF e remover espaços/quebras apenas nas extremidades. Resultado classifica equivalência do conteúdo, não apenas nomes ou prefixos.

### 27 correspondências exatas (36 versões remotas)

| Versão remota | Nome remoto | Arquivo local com SQL idêntico |
|---|---|---|
| 20261111213207 | product_categories | 202611100001_product_categories.sql |
| 20261111213209 | product_barcode_integrity | 202611100003_product_barcode_integrity.sql |
| 20261111213213 | employee_integrity | 202611110001_employee_integrity.sql |
| 20261111213231 | foreign_key_indexes_rls_tuning | 20261111213231_foreign_key_indexes_rls_tuning.sql |
| 20261111213250 | deduplicate_category_policies | 20261111213250_deduplicate_category_policies.sql |
| 20261111213334 | api_privilege_hardening | 202611120001_api_privilege_hardening.sql |
| 20261116085058 | gei_records_role_guard | 20261116085000_gei_records_role_guard.sql |
| 20261116090458 | least_privilege_cleanup | 20261116121000_least_privilege_cleanup.sql |
| 20261116090607 | business_activity_detail | 20261116122000_business_activity_detail.sql |
| 20261116090633 | business_activity_detail_permissions | 20261116123000_business_activity_detail_permissions.sql |
| 20261116125032 | guard_company_creation_by_role | 20261116125032_guard_company_creation_by_role.sql |
| 20261119131748 | hr_management | 20261119130000_hr_management.sql |
| 20261119131816 | hr_privilege_tightening | 20261119132000_hr_privilege_tightening.sql |
| 20261119131859 | hr_fk_indexes | 20261119133000_hr_fk_indexes.sql |
| 20261119153922 | hr_timekeeping_and_hourly_pay | 20261119153922_hr_timekeeping_and_hourly_pay.sql **e** 20261119170000_hr_timekeeping.sql (duplicação exata) |
| 20261119153948 | hr_timekeeping_index_policy_tuning | 20261119173000_hr_timekeeping_index_policy_tuning.sql |
| 20261119154117 | hr_punch_clock_timestamp | 20261119180000_hr_punch_clock_timestamp.sql |
| 20261119162418 | hr_time_calculation_and_closing | 20261119190000_hr_time_calculation_and_closing.sql |
| 20261119162606 | hr_occurrences_composite_fk_index | 20261119191000_hr_occurrences_composite_fk_index.sql |
| 20261119165027 | hr_tax_parameters_fap_and_mixed_annex | 20261119165027_hr_tax_parameters_fap_and_mixed_annex.sql |
| 20261119165352 | hr_allow_mixed_simples_annex | 20261119165352_hr_allow_mixed_simples_annex.sql |
| 20261119165726 | hr_link_compensatory_rest_to_workday | 20261119165726_hr_link_compensatory_rest_to_workday.sql |
| 20261119165904 | hr_employee_anexo_iv_share | 20261119165904_hr_employee_anexo_iv_share.sql |
| 20261119170819 | hr_daily_extension_agreement_reference | 20261119170819_hr_daily_extension_agreement_reference.sql |
| 20261123132034 | enforce_employee_role_and_module_access | 20261123102000_enforce_employee_role_and_module_access.sql |
| 20261123132745 | revoke_public_sequence_privileges | 20261123113000_revoke_public_sequence_privileges.sql |
| 20261123133003 | move_privileged_rpcs_to_private | 20261123123000_move_privileged_rpcs_to_private.sql |

### 9 versões remotas sem arquivo local de conteúdo idêntico

| Versão remota | Nome remoto |
|---|---|
| 20261111213135 | company_business_profiles |
| 20261111213202 | integrity_hardening |
| 20261116000938 | sector_operations_records |
| 20261116001106 | legacy_empresas_lockdown |
| 20261116001449 | revoke_unused_legacy_rpcs |
| 20261116083715 | brazil_local_business_dates |
| 20261123130925 | revoke_unsafe_default_privileges |
| 20261123130928 | hr_employee_self_read |
| 20261123130931 | move_rls_helpers_private |

### 16 arquivos locais sem correspondência remota exata

- 202611070001_employees.sql
- 202611080001_erp_modules.sql
- 202611080002_finance_links.sql
- 202611080003_protect_linked_finance.sql
- 202611090001_integrity_hardening.sql
- 202611100002_company_business_profiles.sql
- 20261116000938_sector_operations_records.sql
- 20261116001106_legacy_empresas_lockdown.sql
- 20261116001449_revoke_unused_legacy_rpcs.sql
- 20261116083715_brazil_local_business_dates.sql
- 20261119170000_hr_time_calculation_and_closing.sql
- 20261123090000_revoke_unsafe_default_privileges.sql
- 20261123100000_hr_employee_self_read.sql
- 20261123101000_move_rls_helpers_private.sql

**Nota:** o inventário acima é de 42 arquivos e 36 registros remotos. A contagem de 16 arquivos locais sem correspondência inclui o arquivo de RH que colide no prefixo 20261119170000. As versões com mesmo nome/prefixo, mas SQL diferente, permanecem divergências e precisam de proveniência/revisão; não são equivalências.

### Decisão operacional

A comparação de conteúdo fechou 27 correspondências, identificou 9 SQLs remotos ausentes localmente e 16 arquivos locais sem par exato. Isso ainda não autoriza um push: arquivos sem par podem ser migrations antigas, drafts locais, migrations já consolidadas sob outra versão ou divergências reais. Não mover, apagar, renomear, reparar ou aplicar automaticamente. Próxima etapa: investigar proveniência dos 9 SQLs ausentes e dos 16 arquivos locais sem par, preparar uma árvore candidata separada e validar em projeto isolado com `supabase migration list` e `supabase db push --dry-run`. Backup completo restaurável segue pré-requisito para produção.

Nenhum SQL foi aplicado; nenhum dado, schema ou histórico remoto foi alterado.
