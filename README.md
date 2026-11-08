# G.E.I360
Plataforma de Gestão Empresarial.

## O que está implementado nesta versão
- Cadastro e login de usuários pelo Supabase Auth.
- Cadastro e leitura de empresas vinculadas ao usuário.
- Criação automática do vínculo do criador como proprietário (`owner`).
- Painel inicial com resumo da empresa e equipe.
- Navegação entre Visão geral, Minha empresa e Funcionários.
- Cadastro, edição, consulta e exclusão de funcionários com controle por RLS.

## Configuração necessária no Supabase
1. Abra o projeto Supabase conectado ao G.E.I360.
2. Entre em **SQL Editor**.
3. Abra o arquivo `supabase/migrations/202611070001_employees.sql` deste repositório, copie todo o conteúdo e execute uma única vez.
4. Em **Authentication → URL Configuration**, adicione o endereço publicado do GitHub Pages em **Site URL** e **Redirect URLs**.
5. Se a confirmação de e-mail estiver habilitada, confirme o endereço recebido antes de entrar.

O front-end usa a URL do projeto Supabase e a chave publicável (publishable/anon) configurada em `index.html`. Nunca coloque uma `service_role` ou chave secreta no navegador.

## Publicação
O workflow em `.github/workflows/static.yml` publica o conteúdo do repositório no GitHub Pages quando há commits na branch `main`. Aguarde a execução terminar em **Actions** e abra o endereço do GitHub Pages do repositório.

## Escopo desta entrega
Esta é a primeira versão funcional do núcleo de acesso, empresas e funcionários. Os demais módulos empresariais (estoque, vendas, compras, financeiro, fiscal, RH avançado, emissão fiscal e integrações) ainda precisam de tabelas, regras, validações e integrações próprias. A emissão de nota fiscal não é ativada apenas por uma tela: exige credenciamento, certificado e integração homologada com o provedor fiscal.
