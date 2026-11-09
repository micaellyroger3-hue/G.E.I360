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
1. Aplique primeiro `supabase/migrations/202611070001_employees.sql` no SQL Editor.
2. Aplique depois `supabase/migrations/202611080001_erp_modules.sql` no SQL Editor.
3. Aplique por último `supabase/migrations/202611080002_finance_links.sql` no SQL Editor. Essa migração vincula automaticamente vendas confirmadas a contas a receber e compras recebidas a contas a pagar. Os lançamentos vinculados não podem ser editados ou excluídos manualmente; a baixa/recebimento continua disponível.
4. Aplique `supabase/migrations/202611080003_protect_linked_finance.sql` no SQL Editor. Ela reforça no próprio banco a proteção dos lançamentos vinculados, permitindo somente alterar a situação de pagamento.
5. Aplique `supabase/migrations/202611090001_integrity_hardening.sql` no SQL Editor. Ela permite ajustes de estoque para saldo zero, protege o saldo contra alterações diretas e restringe os campos de vínculo financeiro.
6. Configure o endereço publicado do GitHub Pages em **Authentication → URL Configuration** (Site URL e Redirect URLs).
7. Confirme o e-mail de cadastro, caso a confirmação esteja habilitada.

O front-end utiliza a URL do projeto e a chave publicável (publishable/anon) no navegador. Nunca coloque uma chave `service_role` ou chave secreta no front-end.

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
