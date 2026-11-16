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
- iFood sem integração oficial; NF-e/NFC-e sem emissão SEFAZ; IA generativa não conectada; ficha de funcionário não cria usuário de login.

## Homologação ainda necessária antes de vender acesso
1. Testar no navegador duas contas reais em empresas distintas.
2. Testar matriz owner/admin/manager/employee/viewer em todas as telas e documentos.
3. Validar upload/download privado e recuperação de senha por e-mail.
4. Configurar e testar backup e restauração.
5. Fazer smoke test em Android e desktop com sessão real.

A aplicação está publicada e a validação automatizada passou. Isso não equivale a homologação comercial completa; manter o acesso em beta até concluir os testes reais acima.
