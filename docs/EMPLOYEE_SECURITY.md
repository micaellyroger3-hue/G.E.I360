# Proteção do cadastro de funcionários — G.E.I360

## O que esta atualização faz
- Impede trocar a empresa de origem de um funcionário por edição direta na API.
- Impede substituir o usuário que criou o cadastro.
- Atualiza `updated_at` em alterações futuras.
- Acrescenta políticas RLS restritivas para que políticas permissivas antigas não ampliem o acesso entre empresas.
- Mantém leitura para membros da empresa, inclusão/edição para owner/admin/manager e exclusão para owner/admin.

## O que não faz
- Não cria contas de acesso para funcionários.
- Não envia convites nem define senhas.
- Não altera os registros existentes.
- Não é uma prova de teste funcional real entre duas contas e duas empresas.

## Instalação segura
1. Execute primeiro `supabase/diagnostics/202611110001_employee_integrity_preflight.sql` no SQL Editor do Supabase.
2. Confira o resultado e faça backup antes de qualquer alteração de produção.
3. Só depois de revisar o diagnóstico, aplique `supabase/migrations/202611110001_employee_integrity.sql`.
4. Rode novamente o diagnóstico e confira as políticas e o trigger.

Esta migração ainda não foi aplicada ao projeto Supabase.
