# G.E.I360
Plataforma de gestão empresarial multiempresa.

## Aplicativo publicado
- **Acesso:** https://micaellyroger3-hue.github.io/G.E.I360/
- **Formato:** PWA instalável em Android e desktop.
- **Publicação:** deploy do GitHub Pages e validação automatizada confirmados; o histórico atualizado fica em [GitHub Actions](https://github.com/micaellyroger3-hue/G.E.I360/actions).

O modo offline mantém apenas a estrutura de abertura. Login e dados empresariais exigem internet.

## Módulos disponíveis no código
- Cadastro, login, renovação de sessão, recuperação de senha e logout.
- Cadastro e seleção de empresas; perfil por ramo e canais comerciais.
- Funcionários (fichas; cadastrar ficha não cria login de funcionário).
- Clientes, fornecedores, categorias, produtos, SKU e código de barras.
- Estoque, entradas, saídas e ajustes.
- Compras e vendas com carrinho; integração automática com movimentações e lançamentos financeiros.
- Contas a pagar/receber, documentos e anexos privados.
- Painel de indicadores, relatórios e exportação CSV.
- **Operação específica por ramo:** restaurante/lanchonete (produção, desperdício, ficha de preparo); mercado (validade, perdas, reposição); comércio (campanhas e tarefas); serviços (ordens de serviço); distribuidora/e-commerce (expedição); construção (diário de obra).

## Como funciona a personalização por ramo
Na tela **Minha empresa**, o responsável informa o ramo e os canais usados. A tela **Operação do ramo** apresenta formulários específicos para o perfil selecionado. Os registros ficam em `gei_records`, vinculados à empresa e protegidos por RLS.

**Limites importantes:** os registros setoriais são lançamentos operacionais manuais. Não dão baixa automática no estoque, não calculam custo real de receita, não sincronizam pedidos com iFood/marketplaces e não substituem módulos completos de produção, logística ou fiscal. A seleção do canal iFood não é integração oficial.

## Supabase e segurança
Projeto `mxikqdarqgatqoecfprg`, status ativo/saudável, PostgreSQL 17.

Onze migrations direcionadas estão registradas no Supabase:
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

Verificações confirmadas:
- 20/20 tabelas públicas com RLS habilitado.
- Nenhum grant de tabela a `anon` nas tabelas empresariais auditadas.
- Nenhum privilégio estrutural `TRUNCATE/REFERENCES/TRIGGER/MAINTAIN` para `authenticated` nas tabelas auditadas.
- Bucket `company-documents` privado.
- A tabela legada `public.empresas` tem zero linhas; privilégios de `anon`, `public` e `authenticated` revogados e policy restritiva de negação total. A aplicação usa `public.companies`.
- Teste transacional de registro setorial aprovado; teste de isolamento confirmou zero linhas visíveis para usuário sem associação. Os dados de teste foram revertidos por `ROLLBACK`.
- Fluxos transacionais de compra/venda e proteção de estoque/financeiro aprovados em testes SQL com rollback.

### Alertas e limites de homologação
- O Advisor ainda sinaliza seis funções `SECURITY DEFINER` executáveis por `authenticated`: RPCs usadas pelo app (`create_company`, `create_sale_cart`, `receive_purchase_cart`, `record_stock_movement`) e helpers de RLS (`has_company_role`, `is_company_member`). Três RPCs antigas sem chamadas no frontend (`create_sale`, `receive_purchase`, `get_my_companies`) tiveram EXECUTE revogado. As seis restantes exigem sessão e validam empresa/cargo; `search_path` está vazio. Manter revisão periódica.
- Proteção de senha vazada permanece desativada no Auth (recurso não disponível no plano Free atual).
- Ainda falta teste ponta a ponta no navegador com duas contas reais, matriz completa de papéis, upload/download de documentos entre empresas e teste de restauração de backup. Não cadastrar clientes pagantes até essa homologação.

## Integrações que ainda não existem
- iFood: sem importação/sincronização de pedidos e cardápio.
- NF-e/NFC-e: documentos e anexos; sem emissão ou transmissão à SEFAZ.
- IA generativa: não há assistente generativo conectado.
- Convite/login de funcionários: cadastro de ficha não cria credencial.

## Segurança de migrations e chaves
O banco já tinha tabelas e dados antes desta revisão, sem histórico inicial de migrations. O antigo instalador `supabase/INSTALL_GEI360_ALL.sql` está desativado para impedir execução incompatível. **Não executar o instalador antigo nem `supabase db push`** até reconciliar formalmente todo o histórico.

O navegador pode conter somente URL do projeto e chave publicável. Nunca expor `service_role`, `sb_secret_` ou credenciais de terceiros no front-end.
