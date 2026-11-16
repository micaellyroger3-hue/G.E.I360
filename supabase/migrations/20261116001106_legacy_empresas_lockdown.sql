-- G.E.I360 | Bloqueio explícito da tabela legada public.empresas.
-- A aplicação usa public.companies; public.empresas está vazia e sem dependências.
-- Nenhum dado é removido. O acesso pela API fica revogado e RLS permanece fail-closed.
begin;
revoke all privileges on table public.empresas from public, anon, authenticated;
drop policy if exists gei360_legacy_empresas_deny_all on public.empresas;
create policy gei360_legacy_empresas_deny_all
on public.empresas
as restrictive
for all
to authenticated
using (false)
with check (false);
commit;
