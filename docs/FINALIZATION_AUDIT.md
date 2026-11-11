# G.E.I360 — auditoria consolidada de finalização

Atualizado em 2026-11-11 após inspeção e correções no Supabase.

## Estado confirmado

- Repositório: `micaellyroger3-hue/G.E.I360`.
- Integração de código: PR #5, branch `integration/categorias-perfil-empresarial-20261110`.
- A PR continua separada da `main`; não declarar deploy concluído.
- Projeto Supabase `mxikqdarqgatqoecfprg`: `ACTIVE_HEALTHY`, PostgreSQL 17.
- O banco já possuía tabelas e dados antes desta revisão, mas o histórico de migrations estava vazio. Não foi seguro executar o antigo instalador de dez migrations como um único bloco.

## Correções aplicadas diretamente no Supabase

Migrations registradas no projeto:
1. `company_business_profiles`
2. `integrity_hardening`
3. `product_categories`
4. `product_barcode_integrity`
5. `employee_integrity`
6. `foreign_key_indexes_rls_tuning`
7. `deduplicate_category_policies`
8. `api_privilege_hardening`

Além delas, o hardening inicial de ACL foi aplicado e depois formalizado pela migration `api_privilege_hardening`.

### Verificações pós-correção

| Verificação | Resultado |
|---|---|
| Tabelas públicas auditadas com RLS habilitado | 20 de 20 |
| Grants de tabela a `anon` nas tabelas auditadas | 0 |
| Privilégios estruturais de `authenticated` (`TRUNCATE`, `REFERENCES`, `TRIGGER`, `MAINTAIN`) | 0 |
| FKs públicas sem índice de cobertura | 0 |
| Bucket `company-documents` | Privado |
| Duplicidade de código de barras entre produtos atuais | 0 grupos |
| Helpers do proprietário (`is_company_member` / `has_company_role`) | PASS |

### Testes transacionais executados

Foram criados registros temporários dentro de uma transação e tudo foi revertido por `ROLLBACK`:

- Recebimento de compra com um item: criou pedido/item, entrada de estoque e despesa financeira automática; saldo de estoque conferido em 10 — PASS.
- Venda com um item: criou venda/item, saída de estoque e receita financeira automática; saldo conferido em 8 — PASS.
- Três tentativas sob o papel `authenticated`: escrita direta em `stock_quantity`, atualização direta do saldo e gravação direta de `source_type/source_id` no financeiro foram negadas — PASS.
- Teste adicional de isolamento: foi criada uma segunda empresa temporária e a associação do usuário foi marcada como inativa; sob o papel `authenticated`, a leitura dessa empresa retornou zero linhas e a tentativa de escrita foi negada — PASS.
- Os registros temporários não permaneceram no banco.

## Alertas restantes do Supabase Advisor

- `public.empresas`: RLS habilitado sem policies. É uma tabela legada; não foi apagada nem recebeu policy permissiva. Deve continuar inacessível até uma decisão consciente sobre migração/remoção.
- Nove funções `SECURITY DEFINER` continuam executáveis por `authenticated`: RPCs transacionais e helpers do aplicativo. O alerta do Advisor é esperado para esse desenho, mas essas funções exigem revisão periódica. As funções de trigger foram bloqueadas para chamadas diretas por API.
- Proteção contra senhas vazadas está desativada; ativar em Authentication nas configurações do Supabase.
- Índices recém-criados aparecem como não utilizados porque há pouco tráfego; não remover sem observar carga real.
- O Advisor não substitui teste com duas contas reais.

## O que ainda não está comprovado

- Isolamento ponta a ponta entre duas empresas e dois usuários diferentes.
- Matriz completa de permissões para owner/admin/manager/employee/viewer usando sessões reais.
- Fluxo de upload/download de documentos usando duas empresas e contas diferentes.
- Homologação completa do frontend publicado.
- Execução bem-sucedida do GitHub Actions na cabeça atual da PR #5, merge para `main` e deploy.

## Importante: migrations e instalador

O banco tinha schema e dados antes da revisão, mas nenhum histórico de migrations. Foram aplicadas oito migrations direcionadas, registradas pelo Supabase com versões geradas pelo serviço. Isso **não equivale** a ter reconciliado toda a sequência histórica do repositório.

O arquivo `supabase/INSTALL_GEI360_ALL.sql` foi desativado para impedir que alguém execute migrations-base incompatíveis com o schema já existente. Não usar o antigo instalador nem `supabase db push` até reconciliar os arquivos locais e o histórico remoto.

## Funcionalidades e limites do produto

- NF-e/NFC-e: documentos e anexos; sem emissão/transmissão SEFAZ.
- iFood: seleção de canal; sem sincronização real.
- IA generativa: não conectada.
- Ficha de funcionário não cria usuário de login.
- Offline: apenas shell estático.

## Critério de liberação

Liberar para clientes somente após: isolamento multiempresa comprovado com duas contas; testes de permissões e documentos; proteção de senha vazada ativada; validação verde do GitHub Actions; revisão/merge da PR #5; deploy e smoke test da versão publicada; backup e teste de restauração.
