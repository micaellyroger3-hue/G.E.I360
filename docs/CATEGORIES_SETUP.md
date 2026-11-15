# G.E.I360 — Instalação do módulo Categorias

Esta etapa acrescenta o cadastro de categorias e o vínculo seguro entre categorias e produtos.

## O que muda

- Nova tela **Categorias** no menu.
- Cadastro, pesquisa, edição e ativação/desativação de categorias.
- Seleção de categoria no cadastro de produtos.
- Cada categoria pertence a uma única empresa.
- A chave estrangeira composta impede vincular um produto à categoria de outra empresa.
- Produtos antigos mantêm a coluna textual `category`; a migração cria `category_id` e preenche o vínculo sem apagar o texto.
- Categorias usadas por produtos não podem ser excluídas. Marque-as como inativas.

## Ordem segura no Supabase

Projeto esperado: `mxikqdarqgatqoecfprg`.

1. Abra o SQL Editor do projeto correto.
2. Copie e execute primeiro `supabase/diagnostics/202611100001_categories_preflight.sql`. É somente leitura.
3. Confira se existem `companies`, `products`, `is_company_member(uuid)` e `has_company_role(uuid,text[])`.
4. Confira se `products.company_id`, `products.category` e `products.created_by` têm os tipos esperados.
5. Se o diagnóstico indicar duplicidades, vínculos inválidos ou funções ausentes, não execute a migração. Corrija o schema primeiro.
6. Somente depois da revisão, execute `supabase/migrations/202611100001_product_categories.sql`.

## O que a migração faz

- Cria `product_categories` se ainda não existir.
- Acrescenta `products.category_id` se ainda não existir.
- Cria uma chave estrangeira composta por `company_id` e `category_id`.
- Converte os nomes de categorias antigos de `products.category` em registros por empresa e preenche `category_id`.
- Habilita RLS e cria políticas permissivas e restritivas por empresa.
- Restringe inclusão e edição a owner/admin/manager e exclusão a owner/admin.
- Acrescenta apenas os privilégios de coluna necessários para `products.category_id`, preservando as restrições de saldo do estoque.
- Mantém a exclusão de categorias usadas por produtos bloqueada pela chave estrangeira.

A migração não apaga tabelas, produtos, clientes, fornecedores nem lançamentos. Ela faz alterações estruturais aditivas e preenche a nova chave de categoria.

## Teste depois da migração e da publicação autorizada

1. Entre na empresa já existente.
2. Abra **Categorias** e crie uma categoria fictícia, por exemplo `Alimentos`.
3. Edite a categoria e marque como inativa; confirme que ela aparece como inativa.
4. Reative a categoria.
5. Abra **Estoque**, cadastre um produto fictício e selecione a categoria.
6. Volte a Categorias e tente excluir a categoria vinculada: o sistema deve impedir e orientar a inativação.
7. Confirme que o produto continua com sua categoria.

## Importante

- Esta branch não é publicada automaticamente.
- A migração não foi executada no Supabase.
- Não faça merge na `main` antes da revisão e autorização.
- Não use nem compartilhe `service_role` ou chaves secretas.
