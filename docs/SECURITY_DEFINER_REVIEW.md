# Revisão de funções SECURITY DEFINER — G.E.I360

## Helpers de autorização RLS
- `has_company_role(uuid,text[])` e `is_company_member(uuid)` são helpers internos usados por políticas RLS e por funções de negócio.
- A implementação privilegiada fica no schema `private`, não exposto pela API REST do Supabase.
- Os nomes antigos em `public` permanecem apenas como wrappers `SECURITY INVOKER`; não executam SQL privilegiado por conta própria.
- O acesso aos helpers privados é limitado a `authenticated` e `service_role`; o schema não concede uso a `anon` ou `PUBLIC`.
- `private.is_company_module_enabled(uuid,text)` verifica vínculo ativo, disponibilidade no catálogo e ativação do módulo para a empresa. É usado por políticas RLS restritivas e por RPCs privilegiadas.
- A migration preserva os OIDs dos helpers originais ao movê-los, mantendo dependências existentes nas políticas RLS.

## RPCs privilegiadas expostas intencionalmente
As funções abaixo são chamadas diretamente pelo aplicativo e permanecem `SECURITY DEFINER` para realizar operações transacionais com validação própria:

| RPC | Controles obrigatórios |
|---|---|
| `create_company` | exige `auth.uid()` e respeita regras de vínculo/primeira empresa |
| `create_sale_cart` | owner/admin/manager; valida cliente, produtos, quantidades e estoque; exige Vendas, Produtos e Serviços e Estoque habilitados |
| `hr_claim_employee_account` | associa somente ficha ativa, e-mail confirmado, usuário autenticado com papel employee e RH habilitado |
| `hr_register_time_punch` | funcionário vinculado ou gestor autorizado; valida tipo, sequência e RH habilitado |
| `receive_purchase_cart` | owner/admin/manager; valida fornecedor, produtos, quantidades e módulos Compras, Produtos e Serviços e Estoque |
| `record_stock_movement` | owner/admin/manager; valida empresa, produto, tipo, quantidade, saldo e módulos Estoque e Produtos e Serviços |

Todas as seis implementações permanecem `SECURITY DEFINER` dentro do schema `private`, com `SET search_path TO ''`, objetos qualificados, validação de usuário e autorização no escopo da empresa. Os endpoints `public` correspondentes são wrappers `SECURITY INVOKER`, executáveis por authenticated e não por anon. Após a migração, o Advisor deixou de reportar essas funções expostas.

## Barreiras de módulo e papel
- 26 políticas RLS restritivas aplicam o estado do módulo também a chamadas REST diretas.
- Funcionário não lê dados comerciais, financeiros ou documentos empresariais; mantém jornada própria e operação do ramo habilitada.
- Visualizador tem leitura de negócio; gerente opera módulos sem acesso à remuneração/fechamento restrito; owner/admin mantêm administração.
- O bucket de documentos exige papel autorizado e módulo Fiscal habilitado.
- Desativar um módulo não apaga dados; apenas suspende o acesso até reativação.

## Riscos residuais
- O Advisor não reporta mais funções SECURITY DEFINER no schema exposto; o único aviso de segurança restante é proteção contra senhas vazadas desligada.
- A proteção contra senhas vazadas permanece desligada no plano Free; Supabase informa que o recurso está disponível no Pro ou superior.
- Nenhum convite real foi disparado nesta revisão.
