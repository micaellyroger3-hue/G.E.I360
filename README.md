# G.E.I360
Plataforma de gestão empresarial multiempresa.

## Aplicativo publicado
- **Apresentação para mercadinhos:** [Conheça o G.E.I360 e o projeto-piloto](https://micaellyroger3-hue.github.io/G.E.I360/apresentacao-mercadinhos.html).
- **Acesso:** https://micaellyroger3-hue.github.io/G.E.I360/
- **Formato:** PWA instalável em Android e desktop.
- **Publicação:** deploy do GitHub Pages e validação automatizada confirmados; o histórico atualizado fica em [GitHub Actions](https://github.com/micaellyroger3-hue/G.E.I360/actions).

O modo offline mantém apenas a estrutura de abertura. Login e dados empresariais exigem internet.

## Módulos disponíveis no código
- Cadastro, login, renovação de sessão, recuperação de senha e logout.
- Cadastro e seleção de empresas; perfil por ramo e canais comerciais.
- Funcionários e RH: fichas da equipe, remuneração mensal ou por hora, convites, escalas (12x36, 6x1, 5x2, fixa e variável) e registro gerencial de ponto (não homologado como REP).
- Clientes, fornecedores, categorias, produtos, SKU e código de barras.
- Estoque, entradas, saídas e ajustes.
- Compras e vendas com carrinho; integração automática com movimentações e lançamentos financeiros.
- Contas a pagar/receber, documentos e anexos privados.
- Painel de indicadores, relatórios e exportação CSV.
- **Operação específica por ramo:** alimentação preparada (restaurantes, lanchonetes, padarias, pizzarias e cafeterias); mercado e alimentos (mercadinhos, supermercados, mercearias, açougues e hortifrutis); comércio (campanhas e tarefas); serviços (ordens de serviço); distribuidora/e-commerce (expedição); construção (diário de obra). Para outros ramos, os módulos gerais continuam disponíveis e o perfil genérico permite registros operacionais manuais.

## Como funciona a personalização por ramo
Na tela **Minha empresa**, o responsável informa o ramo e os canais usados. A lista contempla segmentos de alimentação e comércio; quando a atividade não estiver listada, pode ser usado **Outro ramo** para os módulos gerais. A tela **Operação do ramo** apresenta formulários específicos para os perfis implementados. Os registros ficam em `gei_records`, vinculados à empresa e protegidos por RLS.

**Limites importantes:** os registros setoriais são lançamentos operacionais manuais. Não dão baixa automática no estoque, não calculam custo real de receita, não sincronizam pedidos com iFood/marketplaces e não substituem módulos completos de produção, logística ou fiscal. A seleção do canal iFood não é integração oficial.

## Supabase e segurança
Projeto `mxikqdarqgatqoecfprg`, status ativo/saudável, PostgreSQL 17.

Trinta migrations direcionadas estão registradas no Supabase:
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
17. `guard_company_creation_by_role`
18. `hr_management`
19. `hr_privilege_tightening`
20. `hr_fk_indexes`
21. `hr_timekeeping_and_hourly_pay`
22. `hr_timekeeping_index_policy_tuning`
23. `hr_punch_clock_timestamp`
24. `hr_time_calculation_and_closing`
25. `hr_occurrences_composite_fk_index`
26. `hr_tax_parameters_fap_and_mixed_annex`
27. `hr_allow_mixed_simples_annex`
28. `hr_link_compensatory_rest_to_workday`
29. `hr_employee_anexo_iv_share`
30. `hr_daily_extension_agreement_reference`

Verificações confirmadas:
- 33/33 tabelas públicas com RLS habilitado.
- Nenhum grant de tabela a `anon` nas tabelas empresariais auditadas.
- Nenhum privilégio estrutural `TRUNCATE/REFERENCES/TRIGGER/MAINTAIN` para `authenticated` nas tabelas auditadas.
- Catálogo de módulos somente leitura pela API; exclusões de empresa/membros e criação/exclusão direta de perfis revogadas do cliente.
- Bucket `company-documents` privado.
- A tabela legada `public.empresas` tem zero linhas; privilégios de `anon`, `public` e `authenticated` revogados e policy restritiva de negação total. A aplicação usa `public.companies`.
- Testes SQL transacionais aprovados para criação de empresa e vínculo owner, venda, compra, entrada/saída/ajuste de estoque, geração de contas, proteção contra estoque insuficiente e imutabilidade de lançamentos vinculados; todos os registros de teste foram revertidos por `ROLLBACK`.
- Matriz parcial de papéis testada: owner e manager autorizados para vendas; employee e viewer bloqueados; usuário sem vínculo não visualiza dados empresariais.
- Registros de operação setorial: employee pode inserir; viewer não pode gravar; atualização direta bloqueada para manter histórico append-only.
- Datas de vendas e financeiro usam `America/Sao_Paulo`; indicadores de vencimento e relatórios também comparam datas no fuso de Brasília.

### Alertas e limites de homologação
- O Advisor ainda sinaliza oito funções `SECURITY DEFINER` executáveis por `authenticated`: RPCs usadas pelo app (`create_company`, `create_sale_cart`, `receive_purchase_cart`, `record_stock_movement`) e helpers de RLS (`has_company_role`, `is_company_member`). Três RPCs antigas sem chamadas no frontend (`create_sale`, `receive_purchase`, `get_my_companies`) tiveram EXECUTE revogado. As oito restantes exigem sessão e validam empresa/cargo; `search_path` está vazio. Manter revisão periódica.
- Proteção de senha vazada permanece desativada no Auth (recurso não disponível no plano Free atual).
- Ainda falta teste ponta a ponta no navegador com duas contas reais, matriz completa de papéis, upload/download de documentos entre empresas e teste de restauração de backup. Não cadastrar clientes pagantes até essa homologação.

## Limites funcionais que ainda precisam de implementação
- O menu agora é montado dinamicamente pelo catálogo `gei_module_catalog` e pelas atribuições `company_modules`. Proprietários e administradores podem ativar/desativar os módulos disponíveis em **Minha empresa**. A ausência de atribuição individual mantém o padrão `is_available` do catálogo; módulos ainda não implementados não são apresentados. Isso organiza a interface, mas não substitui RLS e políticas do banco.
- O perfil empresarial usa tipos predefinidos (alimentação preparada, mercado/alimentos e outros segmentos), com campo livre para detalhar a subatividade específica (por exemplo, lanchonete, padaria, açougue, hortifruti ou cafeteria).

## Integrações que ainda não existem
- iFood: sem importação/sincronização de pedidos e cardápio.
- NF-e/NFC-e: documentos e anexos; sem emissão ou transmissão à SEFAZ.
- IA generativa: não há assistente generativo conectado.
- Convites de funcionários: Edge Function segura ativa com `@supabase/server`; a ficha não cria login automaticamente. Owner/admin envia convite a partir de uma ficha com e-mail. A pessoa aceita o link e define a senha no aplicativo.

## Segurança de migrations e chaves
O banco já tinha tabelas e dados antes desta revisão, sem histórico inicial de migrations. O antigo instalador `supabase/INSTALL_GEI360_ALL.sql` está desativado para impedir execução incompatível. **Não executar o instalador antigo nem `supabase db push`** até reconciliar formalmente todo o histórico.

O navegador pode conter somente URL do projeto e chave publicável. Nunca expor `service_role`, `sb_secret_` ou credenciais de terceiros no front-end.
- A navegação dinâmica e os controles do catálogo foram publicados com validação automatizada e cache PWA `gei360-shell-v37`; ainda requerem conferência visual no aparelho do usuário.


### RH — apuração de jornada
O módulo inclui escala e ponto gerencial, apuração mensal de horas, extras diárias/semanais estimadas, adicional noturno e hora reduzida configuráveis, calendário de feriados, alertas de marcações ausentes, ocorrências justificadas, livro de banco de horas e fechamento/reabertura de competência. Consulte [docs/HR_MODULE.md](docs/HR_MODULE.md) para critérios e limites regulatórios. **Não declarar REP-P certificado nem folha oficial:** a conformidade integral com a Portaria MTP 671/2021 depende de requisitos técnicos e documentais adicionais, incluindo HLB, armazenamento/NSR, comprovantes e assinaturas ICP-Brasil.
