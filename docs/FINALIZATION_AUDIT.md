# G.E.I360 — auditoria consolidada de finalização
Atualizado em 16/11/2026 após merge, deploy e hardening do Supabase.

## Estado de publicação
- Repositório: `micaellyroger3-hue/G.E.I360`.
- PR #5 integrada na main.
- PR #6 (operações específicas por ramo) integrada na main.
- PRs #5, #6, #7 e #8 integradas na `main`.
- Validação automatizada e deploy do GitHub Pages concluídos com sucesso; consultar o histórico atualizado em [GitHub Actions](https://github.com/micaellyroger3-hue/G.EI360/actions).
- URL: https://micaellyroger3-hue.github.io/G.E.I360/

## Banco e migrations
Projeto Supabase `mxikqdarqgatqoecfprg`: ACTIVE_HEALTHY, PostgreSQL 17.

Migrations remotas registradas:
1. `company_business_profiles`
2. `integrity_hardening`
3. `product_categories`
4. `product_barcode_integrity`
5. `employee_integrity`
6. `foreign_key_indexes_rls_tuning`
7. `deduplicate_category_policies`
8. `api_privilege_hardening`
9. `sector_operations_records`
10. `legacy_empresas_lockdown`
11. `revoke_unused_legacy_rpcs`
12. `brazil_local_business_dates`
13. `gei_records_role_guard`
14. `least_privilege_cleanup`
15. `business_activity_detail`
16. `business_activity_detail_permissions`

O banco já possuía schema e dados antes da revisão. O antigo instalador consolidado foi desativado para impedir execução de migrations-base incompatíveis; não executar `supabase/INSTALL_GEI360_ALL.sql` nem `supabase db push` até reconciliação formal.

## Controles confirmados
- 20/20 tabelas públicas auditadas com RLS habilitado.
- Zero grants de tabela a `anon` nas tabelas auditadas.
- Zero privilégios estruturais `TRUNCATE/REFERENCES/TRIGGER/MAINTAIN` para `authenticated` nas tabelas auditadas.
- Bucket `company-documents` privado.
- `public.empresas`: zero registros, sem dependências conhecidas; todos os privilégios revogados de `public`, `anon` e `authenticated`; policy restritiva `gei360_legacy_empresas_deny_all` nega toda operação autenticada. A aplicação usa `public.companies`.
- `gei_records`: RLS ativo; leitura limitada a membros ativos; inserção exige associação ativa. O código de módulo `sector_ops` foi incluído na constraint.

## Testes executados
- Compra transacional: pedido/item, entrada de estoque e despesa financeira automática — PASS, rollback.
- Venda transacional: venda/item, baixa de estoque e receita financeira automática — PASS, rollback.
- Escrita direta em saldo de estoque e origem financeira por authenticated — negada.
- Isolamento de empresa: usuário sem associação viu zero registros de empresa alheia — PASS.
- Operação setorial: inserção simulada como proprietário autorizada; leitura por usuário não membro retornou zero linhas — PASS, rollback.
- CI validou sintaxe JavaScript, navegação, PWA, cache, scripts de perfil, migrações e fluxos críticos.
- Deploy de Pages concluído no commit publicado.

## Alertas restantes do Advisor
- Seis funções `SECURITY DEFINER` executáveis por authenticated continuam sinalizadas: `create_company`, `create_sale_cart`, `has_company_role`, `is_company_member`, `receive_purchase_cart`, `record_stock_movement`. Três RPCs antigas sem chamadas no frontend (`create_sale`, `receive_purchase`, `get_my_companies`) tiveram EXECUTE revogado. As seis restantes exigem `auth.uid()` e verificam associação/cargo; `search_path` está vazio. O uso é intencional para RPCs e helpers RLS, mas requer revisão periódica.
- Proteção contra senha vazada desativada no Supabase Auth por limitação do plano Free.
- Índices recém-criados marcados como não utilizados refletem pouco tráfego; não remover sem métricas reais.

## Funcionalidades setoriais e limites
- Restaurante/lanchonete: registro de desperdício, produção e ficha de preparo.
- Mercado: controle manual de validade, perdas e reposição.
- Comércio: campanhas e tarefas.
- Serviços: ordens de serviço.
- Distribuidora/e-commerce: expedição e separação.
- Construção: diário de obra.
- Os registros são manuais e não alteram automaticamente estoque/financeiro.
- iFood sem integração oficial; NF-e/NFC-e sem emissão SEFAZ; IA generativa não conectada. O convite/login de funcionários foi implementado em Edge Function; a ficha continua separada da conta de acesso.

## Achados adicionais da revisão de 16/11/2026
- A aplicação passou a exibir datas de vendas e vencimentos financeiros vinculados usando a data local derivada de `created_at`, evitando o deslocamento de dia causado por `CURRENT_DATE` em sessão UTC.
- A migration `brazil_local_business_dates` corrigiu os defaults de `sales.sale_date` e `financial_entries.due_date` para `America/Sao_Paulo` e alinhou os gatilhos de venda/compra às datas locais. Nenhuma linha histórica foi alterada.
- O perfil empresarial passou a identificar exemplos de segmentos de alimentação e comércio e a opção genérica **Outro ramo**. O núcleo geral atende atividades diferentes; os fluxos setoriais continuam manuais e recursos não implementados devem permanecer como planejados.
- O cadastro de perfil empresarial está vazio na empresa de teste porque o ramo e os canais ainda não foram salvos; isso é esperado e não é falha de RLS.

## Homologação ainda necessária antes de vender acesso
1. Testar no navegador duas contas reais em empresas distintas.
2. Testar matriz owner/admin/manager/employee/viewer em todas as telas e documentos.
3. Validar upload/download privado e recuperação de senha por e-mail.
4. Configurar e testar backup e restauração.
5. Fazer smoke test em Android e desktop com sessão real.

A aplicação está publicada e a validação automatizada passou. Isso não equivale a homologação comercial completa; manter o acesso em beta até concluir os testes reais acima.


## Atualização de 16/11/2026 — catálogo dinâmico
- O menu consulta `gei_module_catalog` e `company_modules` por empresa.
- Proprietários e administradores podem ativar/desativar módulos disponíveis em **Minha empresa**; módulos essenciais permanecem bloqueados para desativação.
- Para módulos sem linha em `company_modules`, o padrão é `is_available` do catálogo. Isso preserva o acesso inicial às áreas existentes sem criar atribuições automaticamente.
- A navegação dinâmica não substitui RLS. As tabelas continuam protegidas pelas políticas de associação e papel.
- O menu só apresenta áreas implementadas no frontend. PDV, multi-filial e auditoria permanecem fora do menu até implementação.
- Código, validação automatizada e publicação do Pages foram concluídos no commit `28b6cf875db98402163d93e55afb01bd2812a995`. A conferência visual final em Android ainda depende do aparelho do usuário.


## Atualização de 16/11/2026 — convite seguro de funcionários
- Edge Function `invite-company-member` implantada no Supabase e ativa (versão 4). O middleware `@supabase/server@1.9.2` valida o JWT via JWKS e fornece contexto de usuário e cliente administrativo; `verify_jwt=false` é intencional no gateway para usar a validação do middleware.
- O fluxo valida a sessão e exige associação ativa com papel owner/admin; o papel concedido é sempre employee.
- A interface adiciona **Convidar acesso** às fichas com e-mail. A pessoa aceita o convite, define a senha no app e acessa a empresa.
- Nenhum e-mail real foi disparado durante a implementação; a homologação do SMTP/redirect com e-mail de teste ainda depende do proprietário.
