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

### 14 arquivos locais sem correspondência remota exata

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

**Nota:** o inventário acima é de 42 arquivos e 36 registros remotos. Há 28 arquivos locais com correspondência exata (um SQL remoto é representado por dois arquivos locais duplicados) e 14 arquivos locais sem par exato. As versões com mesmo nome/prefixo, mas SQL diferente, permanecem divergências e precisam de proveniência/revisão; não são equivalências.

### Decisão operacional

A comparação de conteúdo fechou 27 correspondências remotas (28 arquivos locais correspondentes, contando a duplicação), identificou 9 SQLs remotos sem arquivo local idêntico e 14 arquivos locais sem par exato. Isso ainda não autoriza um push: arquivos sem par podem ser migrations antigas, drafts locais, migrations já consolidadas sob outra versão ou divergências reais. Não mover, apagar, renomear, reparar ou aplicar automaticamente. Próxima etapa: investigar proveniência dos 9 SQLs ausentes e dos 16 arquivos locais sem par, preparar uma árvore candidata separada e validar em projeto isolado com `supabase migration list` e `supabase db push --dry-run`. Backup completo restaurável segue pré-requisito para produção.

Nenhum SQL foi aplicado; nenhum dado, schema ou histórico remoto foi alterado.


## Análise de proveniência dos 9 SQLs remotos sem cópia idêntica — 24/11/2026

Foi feita comparação direcionada entre cada SQL remoto sem correspondência exata e o arquivo local de mesmo propósito/nome. **Os nove têm um arquivo local semanticamente relacionado, mas nenhum é idêntico byte/textualmente após normalização de fim de linha.** Portanto, não são simplesmente nove arquivos ausentes: são nove pares com divergência que exigem revisão de conteúdo.

| Versão remota | Arquivo local relacionado | Tamanho local / remoto (caracteres) | Observação |
|---|---|---:|---|
| 20261111213135 company_business_profiles | 202611100002_company_business_profiles.sql | 3581 / 3486 | Divergência começa após os comentários iniciais; remoto inclui preflight de tabela |
| 20261111213202 integrity_hardening | 202611090001_integrity_hardening.sql | 2048 / 1634 | Divergência após cabeçalho; SQL local tem conteúdo adicional |
| 20261116000938 sector_operations_records | 20261116000938_sector_operations_records.sql | 540 / 389 | Remoto inicia com transação e alteração de constraint; local contém cabeçalho/comentários adicionais |
| 20261116001106 legacy_empresas_lockdown | 20261116001106_legacy_empresas_lockdown.sql | 547 / 308 | Remoto inicia com REVOKE; conteúdo local difere |
| 20261116001449 revoke_unused_legacy_rpcs | 20261116001449_revoke_unused_legacy_rpcs.sql | 489 / 346 | Remoto inicia com REVOKE de RPCs; conteúdo local difere |
| 20261116083715 brazil_local_business_dates | 20261116083715_brazil_local_business_dates.sql | 2695 / 2592 | Conteúdo remoto começa diretamente com ALTER TABLE; arquivo local tem diferenças |
| 20261123130925 revoke_unsafe_default_privileges | 20261123090000_revoke_unsafe_default_privileges.sql | 977 / 454 | SQL remoto é menor e começa com REVOKE de privilégios |
| 20261123130928 hr_employee_self_read | 20261123100000_hr_employee_self_read.sql | 742 / 560 | SQL remoto recria política; arquivo local contém conteúdo diferente |
| 20261123130931 move_rls_helpers_private | 20261123101000_move_rls_helpers_private.sql | 2215 / 2000 | SQL remoto cria schema private e revoga acesso; arquivo local contém diferenças |

Os tamanhos acima são do texto retornado pelas duas fontes, após normalização de CRLF/LF e trim. O primeiro ponto de divergência foi calculado por comparação textual. Não foi feita inferência de equivalência funcional.

### Conclusão da proveniência

O problema dos nove pares é divergência de conteúdo entre o SQL efetivamente registrado no Supabase e o arquivo versionado localmente. O registro remoto é a evidência do que foi aplicado em produção; o arquivo local não deve substituí-lo sem revisão. Próximo passo seguro: revisar cada diff semanticamente, identificar se o SQL local contém correções posteriores não aplicadas ou comentários/estrutura adicionais, e criar uma proposta de reconciliação em branch separada sem sobrescrever os originais. Não executar `migration repair`, `db push` ou SQL de produção para “alinhar” esses pares nesta etapa.


## Correção da análise semântica dos 9 pares — 24/11/2026

A revisão anterior classificou os nove pares como divergências de conteúdo com base em comparação textual. Essa classificação foi conservadora demais. Foi feita nova comparação diretamente entre cada registro remoto `schema_migrations.statements` e seu arquivo local relacionado, removendo comentários SQL, diferenças de espaços/caixa e os delimitadores externos `BEGIN/COMMIT`.

**Resultado corrigido: os 9 pares têm SQL operacional equivalente.** Em nenhum dos nove pares foi encontrada diferença nas instruções SQL efetivas após essa normalização. As diferenças observadas são comentários, formatação e, no caso de `company_business_profiles`, os delimitadores externos de transação presentes no arquivo local e ausentes no texto armazenado no histórico remoto.

| Versão remota | Arquivo local relacionado | Resultado da comparação |
|---|---|---|
| 20261111213135 company_business_profiles | 202611100002_company_business_profiles.sql | SQL equivalente; diferenças de comentários/formatação e BEGIN/COMMIT |
| 20261111213202 integrity_hardening | 202611090001_integrity_hardening.sql | SQL equivalente; comentários/formatação |
| 20261116000938 sector_operations_records | 20261116000938_sector_operations_records.sql | SQL equivalente; comentários/formatação |
| 20261116001106 legacy_empresas_lockdown | 20261116001106_legacy_empresas_lockdown.sql | SQL equivalente; comentários/formatação |
| 20261116001449 revoke_unused_legacy_rpcs | 20261116001449_revoke_unused_legacy_rpcs.sql | SQL equivalente; comentários/formatação |
| 20261116083715 brazil_local_business_dates | 20261116083715_brazil_local_business_dates.sql | SQL equivalente; comentários/formatação |
| 20261123130925 revoke_unsafe_default_privileges | 20261123090000_revoke_unsafe_default_privileges.sql | SQL equivalente; comentários/formatação |
| 20261123130928 hr_employee_self_read | 20261123100000_hr_employee_self_read.sql | SQL equivalente; comentários/formatação |
| 20261123130931 move_rls_helpers_private | 20261123101000_move_rls_helpers_private.sql | SQL equivalente; comentários/formatação |

Essa correção não altera o inventário de versões: continuam existindo 36 migrations remotas, 42 arquivos locais na branch e três arquivos recuperados com SQL remoto exato. Também não elimina a divergência de prefixos: o CLI compara versões, portanto arquivos com prefixos locais diferentes dos remotos ainda podem ser considerados pendentes, mesmo quando o SQL é equivalente.

### Situação operacional após a correção

- Os nove pares acima estão conciliados por conteúdo SQL; não precisam ser reescritos por diferença semântica.
- Permanecem cinco arquivos locais sem versão remota correspondente identificada, além de arquivos com prefixos diferentes, a duplicidade exata de `hr_timekeeping` e a colisão local de versão `20261119170000`.
- A PR #45 contém somente a documentação e três SQLs recuperados do histórico remoto; não altera o banco.
- Não há branch de desenvolvimento Supabase criada no projeto neste momento.
- Não foi localizado, entre as ações disponíveis nesta conexão, um fluxo de backup/exportação e restauração verificável. Não declarar backup validado.
- Ainda faltam uma árvore local candidata sem colisões, execução de `supabase migration list` e `supabase db push --dry-run` com CLI em ambiente controlado, e comprovação de backup/restauração antes de qualquer push de produção.

**Bloqueio mantido:** não executar `db push`, `migration repair`, `db reset --linked`, nem reorganizar/excluir migrations ativas até concluir essas validações. Nenhum dado, schema ou histórico remoto foi alterado nesta revisão.


## Avaliação dos 5 arquivos locais sem par remoto — 24/11/2026

A revisão de proveniência foi aprofundada com leitura do SQL local e consulta somente de leitura ao catálogo do banco. Os cinco arquivos abaixo não têm uma versão remota própria correspondente no histórico de 36 migrations. Os objetos centrais existem hoje no banco, mas isso não autoriza reaplicar os arquivos antigos: alguns recriam policies, funções e grants que já foram endurecidos por migrations posteriores.

### Riscos confirmados de reaplicação

1. **`202611070001_employees.sql`** — recria a policy `employees_members_select` usando `is_company_member(company_id)`, enquanto a policy atualmente registrada no banco limita a leitura a gestores autorizados ou ao próprio funcionário autenticado. Reaplicar o arquivo antigo pode ampliar a leitura de fichas de funcionários.
2. **`202611080001_erp_modules.sql`** — recria policies e concede `SELECT, INSERT, UPDATE, DELETE` em tabelas do ERP. No banco atual, `authenticated` não tem privilégio de tabela para INSERT/UPDATE em `products` e `financial_entries`; a migration antiga concederia novamente esses privilégios amplos, contornando a intenção dos grants por coluna. O arquivo também recria RPCs legadas `create_sale` e `receive_purchase` e concede execução a `authenticated`; no banco atual, ambas estão sem EXECUTE para `authenticated` e `anon`. As migrations posteriores de revogação já estão aplicadas e não seriam repetidas pelo CLI.
3. **`202611080002_finance_links.sql`** — substitui as funções dos gatilhos financeiros por versões antigas que usam `current_date`. As definições atuais consultadas usam a data local de São Paulo (`America/Sao_Paulo`) e, no recebimento de compra, calculam a data a partir de `received_at/created_at`. Reaplicar a migration antiga pode desfazer essa correção de calendário, pois a migration remota posterior não será reaplicada.
4. **`202611080003_protect_linked_finance.sql`** — recria a função e o trigger de proteção dos lançamentos financeiros vinculados. Deve permanecer fora de qualquer reaplicação até comparar integralmente sua definição com a versão atual do banco.
5. **`20261119170000_hr_time_calculation_and_closing.sql`** — é uma versão local antiga de 12.505 caracteres, diferente da migration remota `20261119162418`, cujo arquivo correspondente é `20261119190000_hr_time_calculation_and_closing.sql` (21.175 caracteres, correspondência exata). A versão remota contém regras e proteções adicionais, incluindo exceções de escala, referências de acordo, multiplicadores e políticas mais detalhadas. O banco atual contém `hr_schedule_exceptions` e colunas adicionais como `compensation_for_date`, confirmando que a estrutura evoluiu além do arquivo local antigo. Não substituir a versão remota pela local antiga.

### Evidências consultadas

- Os objetos principais de RH/ERP existem atualmente no schema `public`, incluindo tabelas de funcionários, estoque, vendas, financeiro, compras e as tabelas de apuração de jornada.
- As funções atuais `create_sale_financial_entry()` e `create_purchase_financial_entry()` usam datas locais do Brasil; o arquivo antigo de vínculos financeiros usa `current_date`.
- `has_table_privilege` confirmou que `authenticated` não tem INSERT/UPDATE em nível de tabela em `products` e `financial_entries`; o arquivo legado de ERP concederia esses privilégios.
- `has_function_privilege` confirmou que `authenticated` e `anon` não podem executar as RPCs antigas `create_sale` e `receive_purchase`; o arquivo legado de ERP concederia EXECUTE novamente a `authenticated`.

### Decisão técnica

Os cinco arquivos não devem ser aplicados automaticamente nem apenas renomeados para coincidir com versões remotas. Os quatro arquivos iniciais são artefatos legados que podem desfazer endurecimentos posteriores; o arquivo local de RH é uma versão antiga/incompleta em relação ao SQL remoto aplicado. Preservar os originais em Git, manter a lista remota como fonte de verdade e preparar uma árvore candidata sem esses arquivos ativos somente depois de backup restaurável e validação isolada.

**Bloqueio reforçado:** executar `db push` com a pasta atual pode reintroduzir grants e RPCs revogados, e enfraquecer políticas de leitura. Portanto, não executar push, repair, reset, rename ou exclusão automática. Nenhum dado, schema ou histórico de produção foi alterado nesta análise.
