# Auditoria de privilégios padrão — G.E.I360

**Data da inspeção:** 23/11/2026  
**Projeto:** Supabase `mxikqdarqgatqoecfprg`  
**Branch de correção:** `security/default-privileges-20261123`

## Evidência somente leitura

- Projeto Supabase em estado `ACTIVE_HEALTHY`, PostgreSQL 17.
- 33/33 tabelas do schema `public` com RLS habilitado; 100 policies registradas.
- O papel `anon` não possui privilégios diretos nas tabelas atuais do schema `public`.
- O papel `authenticated` ainda possuía `TRUNCATE`, `REFERENCES` e `TRIGGER` em nove tabelas novas do RH: `hr_holidays`, `hr_schedule_exceptions`, `hr_time_adjustments`, `hr_time_bank_entries`, `hr_time_occurrences`, `hr_time_periods`, `hr_time_punches`, `hr_time_rules` e `hr_work_schedules`.
- Os privilégios padrão do papel `postgres` no schema `public` concediam acesso amplo a `anon` e `authenticated` para novas tabelas, sequences e funções. Isso explica por que objetos criados depois da limpeza anterior voltaram a receber grants estruturais.
- As tabelas empresariais atuais são de propriedade de `postgres`. O papel `postgres` não é membro de `supabase_admin`; por isso esta migration não tenta alterar os privilégios padrão separados desse papel gerenciado pelo Supabase.

## Correção proposta

A migration `20261123090000_revoke_unsafe_default_privileges.sql`:

1. Revoga de `anon` e `authenticated` os privilégios estruturais `TRUNCATE`, `REFERENCES`, `TRIGGER` e `MAINTAIN` das tabelas existentes em `public`.
2. Remove os grants padrão de tabelas e sequences para objetos futuros criados por `postgres`.
3. Remove o `EXECUTE` padrão de funções futuras para `anon` e `authenticated`; cada RPC necessária deverá receber concessão explícita na própria migration.
4. Não altera dados, policies, ownership, grants normais de leitura/escrita das tabelas atuais nem configurações de autenticação.

## Estado de implantação

Esta é uma proposta em pull request. **Não foi aplicada ao banco de produção.** Antes de aplicar, validar em ambiente separado e conferir que migrations futuras concedem explicitamente apenas os privilégios necessários.

## Pendências que permanecem fora desta correção

- O Advisor ainda aponta oito funções `SECURITY DEFINER` executáveis por usuários autenticados; a revisão funcional de cada RPC e de suas verificações de autorização continua necessária.
- O Advisor informa que a proteção contra senhas vazadas está desativada no Supabase Auth.
- O isolamento entre duas empresas e todos os papéis ainda precisa de homologação ponta a ponta com contas de teste distintas.
- O bucket de documentos está privado e tem policies por pasta/empresa, mas upload/download entre duas empresas ainda não foi homologado no navegador.
- Não há branch de desenvolvimento Supabase; backup e restauração não foram comprovados nesta execução.
