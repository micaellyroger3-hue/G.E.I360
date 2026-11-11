# G.E.I360
Plataforma de Gestão Empresarial.

## Aplicativo instalável
O G.E.I360 pode ser instalado pelo navegador compatível no Android/desktop (menu do navegador → Instalar aplicativo ou Adicionar à tela inicial). O service worker mantém apenas a estrutura estática do aplicativo disponível para abrir sem conexão; autenticação, cadastros, consultas, estoque, vendas e financeiro continuam exigindo internet e acesso ao Supabase. Nenhum dado empresarial ou token de sessão é colocado no cache offline.

## Módulos disponíveis no código
- Cadastro, login e recuperação de senha por e-mail (dependem da configuração de URLs e do serviço de e-mail do Supabase).
- Autenticação e sessão de usuários com Supabase Auth, com renovação automática do token e preservação da sessão em falhas temporárias de rede.
- Cadastro e seleção de empresa e vínculo de proprietário.
- Painel inicial e cadastro de funcionários (registros de equipe; convites e criação de usuários de acesso ainda dependem de configuração segura no servidor).
- Cadastro de clientes e fornecedores.
- Cadastro de produtos, SKU, código de barras, preços e estoque mínimo.
- Leitura de código de barras pela câmera quando o navegador oferece suporte; também aceita digitação e leitor USB/Bluetooth.
- Movimentações de estoque: entrada, saída e ajuste de saldo.
- Vendas com carrinho de múltiplos produtos, registradas em uma única transação com baixa de estoque.
- Compras/recebimento com vários produtos por pedido, atualizando o estoque em uma única transação.
- Contas a pagar e receber, com situação e forma de pagamento.
- Registro de documentos empresariais e referências de notas/comprovantes.
- Relatórios operacionais básicos com exportação CSV.
- Carregamento paginado dos registros da empresa para evitar o limite padrão de retorno do PostgREST.

## Configuração do Supabase
1. Abra o projeto Supabase correto: `mxikqdarqgatqoecfprg`.
2. Execute primeiro `supabase/diagnostics/FINALIZATION_PRECHECK.sql`. É somente leitura. Guarde o resultado e não continue se houver tabela/função ausente, schema incompatível ou duplicidades.
3. Faça um backup do banco.
4. Para aplicar as dez migrations na ordem correta em uma única transação, execute o conteúdo de `supabase/INSTALL_GEI360_ALL.sql` no SQL Editor. Se qualquer etapa falhar, a transação inteira será revertida.
5. Confira as duas consultas de privilégios no final do instalador: ambas devem retornar zero linhas.
6. Faça os testes funcionais e de isolamento descritos em `docs/FINALIZATION_AUDIT.md`.
7. Configure o endereço publicado do GitHub Pages em **Authentication → URL Configuration** (Site URL e Redirect URLs).
8. Confirme o e-mail de cadastro, caso a confirmação esteja habilitada.

O front-end utiliza a URL do projeto e a chave publicável (publishable/anon) no navegador. Nunca coloque uma chave `service_role` ou chave secreta no front-end.

## Consolidação final de segurança e instalação
Antes de liberar a versão integrada, execute uma única vez o diagnóstico somente leitura `supabase/diagnostics/FINALIZATION_PRECHECK.sql` e guarde o resultado. Ele reúne estrutura/RLS, políticas, privilégios, funções, triggers, constraints, índices, bucket privado e volumes de dados.

Depois de revisar o resultado e confirmar que o projeto é o correto, aplique a migration `supabase/migrations/202611120001_api_privilege_hardening.sql`. Ela remove privilégios de tabela de `anon` e `PUBLIC`, retira privilégios estruturais desnecessários de `authenticated` e preserva as permissões de leitura/operação já usadas pelo aplicativo e pelas RPCs autenticadas. Ela não remove dados nem políticas RLS.

A migration não substitui a revisão das políticas RLS nem o teste de isolamento com duas contas e duas empresas. Confira as duas consultas de pós-verificação no final do próprio arquivo; ambas devem retornar zero linhas.

**Ordem de migrations:** funcionários → módulos ERP → vínculos financeiros → proteção financeira → integridade operacional → categorias → perfil empresarial → código de barras → integridade de funcionários → hardening de privilégios. Antes de aplicar migrations opcionais, rode os preflights correspondentes e corrija incompatibilidades/dados duplicados indicados.

## Publicação
O workflow de publicação está em `.github/workflows/static.yml` e publica a branch `main` no GitHub Pages. Confira **Actions** e aguarde a execução terminar com sucesso.

## Limitações desta etapa
- As quatro migrações precisam ser executadas no Supabase, na ordem indicada, antes de usar os novos módulos. Publicar o site não cria tabelas no banco.
- Vendas já aceitam vários produtos no carrinho e registram a operação de forma transacional. Compras/recebimentos também aceitam vários produtos por pedido e atualizam o estoque transacionalmente.
- Documentos aceitam anexos PDF e imagens até 10 MB em bucket privado do Supabase Storage; links temporários de visualização respeitam a associação e o perfil do usuário.
- Leitura por câmera depende de HTTPS, permissão do usuário e suporte do navegador à API BarcodeDetector. Digitação e leitores USB/Bluetooth são alternativas.
- Vendas confirmadas e compras recebidas geram lançamentos financeiros vinculados automaticamente após a terceira migração. O vínculo evita duplicidade. A quarta migração reforça a proteção no banco, permitindo somente alterar a situação de pagamento.
- Relatórios são operacionais e dependem dos lançamentos registrados; não substituem contabilidade.
- Emissão oficial de NF-e/NFC-e não está implementada. Ela exige dados fiscais completos da empresa, enquadramento tributário, certificado digital, credenciamento fiscal quando aplicável e integração homologada com provedor/SEFAZ. O módulo de documentos organiza notas recebidas e anexos, mas não autoriza nem transmite documentos fiscais.
- Ainda é necessário executar testes integrados no ambiente Supabase após aplicar as migrações. As verificações de publicação do GitHub não testam o banco nem os fluxos de negócio.


## Inteligência de gestão e IA
O painel já apresenta análises automáticas transparentes a partir dos registros da empresa (estoque mínimo, contas vencidas, valores a receber/pagar, vendas e produtos inativos). Essa camada inicial é baseada em regras e cálculos, não em IA generativa. A arquitetura segura para o futuro assistente conversacional está documentada em `docs/AI_ASSISTANT_ARCHITECTURE.md`; a IA generativa só será ativada após configurar um provedor e uma função de servidor com autenticação, isolamento por empresa e segredo protegido.


## Perfil inteligente por ramo e canais comerciais
- Cadastro de ramo: restaurante/lanchonete, mercado, varejo, serviços, distribuidora, e-commerce, construção ou outro.
- Canais: iFood, WhatsApp, Instagram, loja física, entrega própria, loja virtual e marketplaces.
- O cadastro exibe estado completo/incompleto e recomenda módulos já existentes, com acesso direto aos módulos.
- Aplique `supabase/migrations/202611100002_company_business_profiles.sql` após executar o diagnóstico somente leitura `supabase/diagnostics/202611100002_business_profiles_check.sql`.
- Selecionar iFood não ativa pedidos reais. Veja `docs/IFOOD_INTEGRATION_PLAN.md` para requisitos oficiais, credenciais, segurança e homologação.


## Instalação do módulo Categorias
1. Execute primeiro o diagnóstico somente leitura `supabase/diagnostics/202611100001_categories_preflight.sql`.
2. Confira tabelas, funções de autorização, colunas, duplicidades e vínculos existentes.
3. Se o diagnóstico estiver consistente, revise e execute `supabase/migrations/202611100001_product_categories.sql` no SQL Editor do projeto correto.
4. Consulte `docs/CATEGORIES_SETUP.md` para os testes funcionais.

A migração cria categorias por empresa, vincula produtos por chave estrangeira composta, mantém o texto antigo e bloqueia vínculos entre empresas. Ela ainda não foi aplicada ao Supabase. Não execute a migração antes da revisão do diagnóstico.


## Códigos de barras
O cadastro de produtos aceita digitação, leitor USB/Bluetooth e leitura pela câmera em navegadores compatíveis. Para impedir códigos duplicados dentro da mesma empresa, revise primeiro `supabase/diagnostics/202611100003_barcode_preflight.sql` e depois, se não houver duplicidades, aplique `supabase/migrations/202611100003_product_barcode_integrity.sql`. Consulte `docs/BARCODE_SETUP.md`. A migração ainda não foi aplicada ao Supabase.
