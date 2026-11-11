# G.E.I360 — auditoria consolidada de finalização

Atualizado em 2026-11-11. Documento de trabalho para concluir a versão integrada sem abrir tarefas pequenas e desconectadas.

## Estado técnico confirmado

- Repositório: `micaellyroger3-hue/G.E.I360`; branch principal: `main`.
- A versão integrada está na PR #5, branch `integration/categorias-perfil-empresarial-20261110`.
- A PR #5 continua aberta/em rascunho; não foi publicada na branch principal.
- A validação estática anterior passou. A validação dos commits desta revisão está aguardando execução no GitHub Actions.
- As migrations mais recentes de categorias, perfil empresarial, código de barras e integridade de funcionários estão no GitHub, mas ainda não foram aplicadas no Supabase.
- Nenhuma alteração foi feita diretamente no banco nesta revisão.

## Funcionalidades já presentes no código integrado

| Área | O que existe |
|---|---|
| Acesso | Cadastro, login, renovação de sessão, recuperação de senha e logout |
| Empresas | Cadastro, seleção de empresa e leitura do vínculo/cargo |
| Funcionários | Cadastro, edição, exclusão e controle de ações por cargo |
| Perfil empresarial | Ramo de atividade, canais comerciais e recomendações de módulos |
| Clientes e fornecedores | Cadastro, pesquisa, edição e exclusão |
| Categorias | Cadastro por empresa e vínculo de produtos com integridade referencial |
| Produtos | Catálogo, SKU, código de barras, preço, custo, estoque mínimo e situação |
| Código de barras | Digitação, leitor USB/Bluetooth e câmera em navegadores compatíveis |
| Estoque | Entrada, saída e ajuste por operação transacional |
| Vendas | Carrinho com vários produtos, baixa de estoque e lançamento financeiro automático |
| Compras | Recebimento com vários produtos, entrada no estoque e lançamento financeiro automático |
| Financeiro | Contas a pagar/receber, situação, vencimentos e proteção de lançamentos vinculados |
| Documentos | Upload privado de PDF/imagens e abertura por URL assinada temporária |
| Relatórios | Indicadores operacionais/financeiros e exportação CSV |
| PWA | Instalação no Android/desktop e shell estático offline |

## Correções e entregas aplicadas nesta revisão

O formulário de criação de empresa fazia um INSERT manual em `company_members`, embora o banco já possua o gatilho `handle_new_company_owner` que cria o vínculo do proprietário. Isso podia gerar uma tentativa duplicada e erro de chave única.

- Removida do frontend a inserção duplicada.
- O gatilho existente permanece responsável por criar o proprietário.
- Adicionado teste de regressão ao validador estático.
- Cache do service worker atualizado de `gei360-shell-v11` para `gei360-shell-v12`, para que dispositivos instalados recebam a versão nova.

## Segurança: pacote consolidado preparado

- Criada a migration `supabase/migrations/202611120001_api_privilege_hardening.sql`.
- Ela revoga privilégios de tabela de `anon` e `PUBLIC` nas tabelas empresariais existentes, remove `TRUNCATE`, `REFERENCES`, `TRIGGER` e `MAINTAIN` de `authenticated`, preserva os privilégios operacionais de linha já concedidos e limita a execução das RPCs e funções de trigger.
- Criado `supabase/diagnostics/FINALIZATION_PRECHECK.sql`, um único diagnóstico somente leitura que reúne estrutura/RLS, policies, grants, funções, triggers, constraints, índices, bucket e contagens.
- O diagnóstico e a migration estão versionados, mas ainda não foram executados no Supabase. O resultado das duas consultas de pós-verificação da migration deve ser zero linhas.
- A migration não apaga dados nem substitui a revisão das políticas RLS. O teste multiempresa real ainda precisa de duas contas autenticadas.

## O que ainda não deve ser anunciado como integração concluída

- **NF-e/NFC-e:** o módulo organiza documentos e anexos; não emite nem transmite documentos à SEFAZ.
- **iFood:** o perfil permite selecionar o canal, mas não importa pedidos nem sincroniza catálogo.
- **IA generativa:** o painel usa regras e cálculos transparentes; não existe assistente generativo conectado.
- **Convites de funcionários:** cadastrar uma ficha de funcionário não cria uma conta de acesso/login.
- **Operação offline:** apenas a tela estática de abertura fica disponível sem internet; os dados e módulos exigem conexão.

## Pendências para liberar a versão integrada

### 1. Consolidar e validar o banco, sem apagar dados

- Conferir as definições reais de `is_company_member` e `has_company_role`.
- Revisar todas as políticas permissivas e restritivas de RLS, especialmente `companies`, `company_members`, `profiles`, tabelas comerciais e financeiras.
- Corrigir privilégios de `anon`: remover escrita e, principalmente, `TRUNCATE` das tabelas empresariais.
- Aplicar privilégio mínimo a `authenticated`, preservando as operações que passam pelas RPCs transacionais.
- Conferir funções `SECURITY DEFINER`, `search_path`, permissões de execução, sequências, triggers e bucket privado.
- Avaliar `empresas` como legado; não apagar nem migrar sem rastrear referências e dados.
- Preparar uma migração consolidada, idempotente e com preflight/validações. Não aplicar automaticamente sem conferir o resultado no projeto correto.

### 2. Testes funcionais integrados

- Duas contas autenticadas e duas empresas: impedir leitura e escrita cruzadas.
- Testar owner, admin, manager, employee e viewer conforme a matriz de permissões definida.
- Criar produto, categoria e código de barras; confirmar bloqueio de duplicidade na mesma empresa.
- Registrar entrada, saída e ajuste; conferir saldo e histórico.
- Fazer venda com vários produtos; conferir cabeçalho, itens, baixa de estoque e lançamento financeiro.
- Receber compra com vários produtos; conferir pedido, itens, entrada de estoque e despesa financeira.
- Marcar lançamento financeiro como pago e confirmar proteção dos dados de origem.
- Enviar, abrir e excluir documento; confirmar que o bucket continua privado e que outra empresa não acessa o arquivo.
- Testar paginação, filtros, exportação CSV, recuperação de senha e troca de empresa.

### 3. Homologação e publicação

- Aguardar GitHub Actions verde na revisão atual.
- Revisar a PR integrada e só então incorporá-la à `main`.
- Confirmar publicação do GitHub Pages e atualização do PWA em Android e desktop.
- Fazer backup e testar restauração antes de liberar clientes.
- Só habilitar recursos fiscais/iFood depois das credenciais, contratos, configuração e homologações externas necessárias.

## Critério de conclusão

O G.E.I360 só deve ser considerado pronto para clientes quando os testes autenticados provarem o isolamento multiempresa, os fluxos de venda/compra/estoque/financeiro fecharem corretamente, os anexos estiverem privados, o backup puder ser restaurado e a versão publicada corresponder ao código validado.
