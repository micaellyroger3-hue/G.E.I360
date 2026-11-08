# G.E.I360
Plataforma de Gestão Empresarial.

## Módulos disponíveis no código
- Autenticação e sessão de usuários com Supabase Auth.
- Cadastro e seleção de empresa e vínculo de proprietário.
- Painel inicial e gestão de funcionários.
- Cadastro de clientes e fornecedores.
- Cadastro de produtos, SKU, código de barras, preços e estoque mínimo.
- Leitura de código de barras pela câmera quando o navegador oferece suporte; também aceita digitação e leitor USB/Bluetooth.
- Movimentações de estoque: entrada, saída e ajuste de saldo.
- Vendas com carrinho de múltiplos produtos, registradas em uma única transação com baixa de estoque.
- Compras/recebimento de um produto por operação, com entrada de estoque transacional.
- Contas a pagar e receber, com situação e forma de pagamento.
- Registro de documentos empresariais e referências de notas/comprovantes.
- Relatórios operacionais básicos.

## Configuração do Supabase
1. Aplique primeiro `supabase/migrations/202611070001_employees.sql` no SQL Editor.
2. Aplique depois `supabase/migrations/202611080001_erp_modules.sql` no SQL Editor.
3. Configure o endereço publicado do GitHub Pages em **Authentication → URL Configuration** (Site URL e Redirect URLs).
4. Confirme o e-mail de cadastro, caso a confirmação esteja habilitada.

O front-end utiliza a URL do projeto e a chave publicável (publishable/anon) no navegador. Nunca coloque uma chave `service_role` ou chave secreta no front-end.

## Publicação
O workflow de publicação está em `.github/workflows/static.yml` e publica a branch `main` no GitHub Pages. Confira **Actions** e aguarde a execução terminar com sucesso.

## Limitações desta etapa
- O arquivo de migração dos módulos precisa ser executado no Supabase antes de usar os novos cadastros. Publicar o site não cria tabelas no banco.
- Vendas já aceitam vários produtos no carrinho e registram a operação de forma transacional. Compras/recebimentos ainda aceitam um produto por operação.
- Documentos aceitam anexos PDF e imagens até 10 MB em bucket privado do Supabase Storage; links temporários de visualização respeitam a associação e o perfil do usuário.
- Leitura por câmera depende de HTTPS, permissão do usuário e suporte do navegador à API BarcodeDetector. Digitação e leitores USB/Bluetooth são alternativas.
- Relatórios são operacionais e dependem dos lançamentos registrados; não substituem contabilidade.
- Emissão oficial de NF-e/NFC-e não está implementada. Ela exige dados fiscais da empresa, certificado digital, credenciamento e integração homologada com provedor/SEFAZ.
- Ainda é necessário executar testes integrados no ambiente Supabase após aplicar as migrações. As verificações de publicação do GitHub não testam o banco nem os fluxos de negócio.

