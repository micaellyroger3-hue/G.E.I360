# Revisão de funções SECURITY DEFINER — G.E.I360

## Helpers de autorização RLS
- `has_company_role(uuid,text[])` e `is_company_member(uuid)` são helpers internos usados por políticas RLS e por funções de negócio.
- A implementação privilegiada fica no schema `private`, não exposto pela API REST do Supabase.
- Os nomes antigos em `public` permanecem apenas como wrappers `SECURITY INVOKER` para compatibilidade; não executam SQL privilegiado por conta própria.
- O acesso aos helpers privados é limitado a `authenticated` e `service_role`; o schema não concede uso a `anon` ou `PUBLIC`.
- A migration preserva os OIDs das funções originais ao movê-las, mantendo dependências existentes nas políticas RLS.

## RPCs privilegiadas que continuam expostas intencionalmente
As funções abaixo são chamadas diretamente pelo aplicativo e permanecem `SECURITY DEFINER` por realizarem operações transacionais que não devem depender de permissões diretas amplas nas tabelas:

| RPC | Controle obrigatório |
|---|---|
| `create_company` | exige `auth.uid()` e impede criação fora das regras de vínculo/primeira empresa |
| `create_sale_cart` | exige papel autorizado na empresa e valida cliente, produtos, quantidades e estoque |
| `hr_claim_employee_account` | associa somente ficha elegível ao usuário autenticado e ao e-mail confirmado |
| `hr_register_time_punch` | aceita funcionário vinculado ou gestor autorizado; valida tipo e sequência de marcações |
| `receive_purchase_cart` | exige owner/admin/manager; valida fornecedor e produtos dentro da empresa; bloqueia duplicidade e estoque cruzado |
| `record_stock_movement` | exige owner/admin/manager; valida empresa, produto, tipo, quantidade e saldo antes da saída |

Todas devem manter `SET search_path TO ''`, nomes de objetos qualificados, validação de usuário e autorização no escopo da empresa. O aviso do Advisor para essas seis RPCs é acompanhado como risco residual intencional, não como prova isolada de vulnerabilidade.

## Limites
- O Advisor ainda pode reportar as seis RPCs públicas necessárias ao aplicativo.
- A migration deve ser testada antes de aplicar em produção.
- Nenhuma chamada de convite ou alteração de dados empresariais faz parte desta revisão.
