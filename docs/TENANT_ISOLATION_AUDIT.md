# Auditoria de isolamento multiempresa — G.E.I360

## Objetivo
Revisar os pontos que definem a fronteira de segurança entre empresas e usuários: `companies`, `company_members`, `profiles`, a possível tabela legada `empresas`, políticas RLS e as funções `is_company_member(uuid)` e `has_company_role(uuid,text[])`.

## Diagnóstico
Execute primeiro `supabase/diagnostics/202611110002_tenant_isolation_audit.sql` no SQL Editor do Supabase. O arquivo é somente leitura: consulta estado de RLS, políticas, definições das funções, privilégios, restrições e índices. Não altera dados.

Revise especialmente:
- Se as funções de autorização usam a identidade autenticada (`auth.uid()`) e verificam o vínculo exato entre usuário e empresa.
- Se funções `SECURITY DEFINER` têm `search_path` seguro/fixo e permissões mínimas.
- Se políticas permissivas antigas podem ampliar o acesso por combinação OR.
- Se a inclusão em `company_members` exige convite ou ação de owner/admin autorizado, sem permitir autoinscrição em qualquer empresa.
- Se `empresas` é uma tabela antiga sem uso atual. Não apagar nem alterar até localizar referências no app, views, triggers e funções.

## Limitação importante
O SQL Editor executa com privilégios administrativos. Resultados de lá não provam o isolamento de usuários pela API. A validação final precisa de duas contas autenticadas e duas empresas distintas, testando leitura e escrita cruzadas com os IDs da outra empresa.

## Segurança da implantação
Este diagnóstico não cria contas, empresas, associações nem dados de teste. Nenhuma política ou migration de produção é alterada por este arquivo. Não fazer merge ou aplicar correções antes de revisar os resultados e obter autorização explícita.
