-- G.E.I360 | Hardening consolidado de privilégios da API
-- Revisado a partir do relatório de ACL de 2026-11-11.
-- Remove acesso anon/PUBLIC às tabelas empresariais e privilégios estruturais
-- desnecessários de authenticated. Preserva SELECT/DML já concedidos a
-- authenticated; RLS e políticas continuam sendo a camada de autorização por empresa.
-- NÃO remove dados, tabelas, policies ou memberships.
begin;

do $table_privileges$
declare
  t text;
  tables_to_secure text[] := array[
    'companies','company_members','company_modules','profiles','empresas',
    'employees','customers','suppliers','products','product_categories',
    'stock_movements','sales','sale_items','purchase_orders',
    'purchase_order_items','financial_entries','business_documents',
    'gei_module_catalog','gei_records','company_business_profiles'
  ];
begin
  foreach t in array tables_to_secure loop
    if to_regclass('public.'||t) is not null then
      execute format('revoke all privileges on table public.%I from anon, public',t);
      -- Usuários autenticados não precisam de poderes para esvaziar tabelas,
      -- criar triggers, criar referências ou executar manutenção estrutural.
      execute format(
        'revoke truncate, references, trigger, maintain on table public.%I from authenticated',
        t
      );
    end if;
  end loop;
end
$table_privileges$;

-- Helpers usados por policies: somente usuários autenticados podem invocá-los.
do $helpers$
begin
  if to_regprocedure('public.is_company_member(uuid)') is not null then
    revoke all on function public.is_company_member(uuid) from public, anon;
    grant execute on function public.is_company_member(uuid) to authenticated;
  end if;
  if to_regprocedure('public.has_company_role(uuid,text[])') is not null then
    revoke all on function public.has_company_role(uuid,text[]) from public, anon;
    grant execute on function public.has_company_role(uuid,text[]) to authenticated;
  end if;
end
$helpers$;

-- RPCs operacionais: sem execução anônima; authenticated conserva o acesso
-- necessário ao frontend. A própria função valida auth.uid(), empresa e cargo.
do $rpcs$
begin
  if to_regprocedure('public.record_stock_movement(uuid,uuid,text,numeric,numeric,text)') is not null then
    revoke all on function public.record_stock_movement(uuid,uuid,text,numeric,numeric,text) from public, anon;
    grant execute on function public.record_stock_movement(uuid,uuid,text,numeric,numeric,text) to authenticated;
  end if;
  if to_regprocedure('public.create_sale(uuid,uuid,uuid,numeric,numeric,text)') is not null then
    revoke all on function public.create_sale(uuid,uuid,uuid,numeric,numeric,text) from public, anon;
    grant execute on function public.create_sale(uuid,uuid,uuid,numeric,numeric,text) to authenticated;
  end if;
  if to_regprocedure('public.create_sale_cart(uuid,uuid,jsonb,numeric,text)') is not null then
    revoke all on function public.create_sale_cart(uuid,uuid,jsonb,numeric,text) from public, anon;
    grant execute on function public.create_sale_cart(uuid,uuid,jsonb,numeric,text) to authenticated;
  end if;
  if to_regprocedure('public.receive_purchase(uuid,uuid,uuid,numeric,numeric,text)') is not null then
    revoke all on function public.receive_purchase(uuid,uuid,uuid,numeric,numeric,text) from public, anon;
    grant execute on function public.receive_purchase(uuid,uuid,uuid,numeric,numeric,text) to authenticated;
  end if;
  if to_regprocedure('public.receive_purchase_cart(uuid,uuid,jsonb,text)') is not null then
    revoke all on function public.receive_purchase_cart(uuid,uuid,jsonb,text) from public, anon;
    grant execute on function public.receive_purchase_cart(uuid,uuid,jsonb,text) to authenticated;
  end if;
end
$rpcs$;

-- Funções executadas apenas por triggers. Não são endpoints RPC do aplicativo.
do $trigger_functions$
declare
  signature text;
  signatures text[] := array[
    'public.apply_stock_movement()',
    'public.create_sale_financial_entry()',
    'public.create_purchase_financial_entry()',
    'public.protect_linked_financial_entry()',
    'public.gei360_validate_product_category_company()',
    'public.gei360_sync_product_category_name()',
    'public.gei360_guard_product_category_update()',
    'public.gei360_guard_employee_integrity()',
    'public.gei360_normalize_product_barcode()',
    'public.gei360_set_business_profile_updated_at()',
    'public.handle_new_company_owner()',
    'public.handle_new_user()'
  ];
begin
  foreach signature in array signatures loop
    if to_regprocedure(signature) is not null then
      execute format('revoke all on function %s from public, anon, authenticated',signature);
    end if;
  end loop;
end
$trigger_functions$;

commit;

-- Pós-verificação somente leitura: deve retornar zero linhas.
select grantee,table_name,privilege_type
from information_schema.table_privileges
where table_schema='public'
  and grantee='anon'
  and table_name in (
    'companies','company_members','company_modules','profiles','empresas',
    'employees','customers','suppliers','products','product_categories',
    'stock_movements','sales','sale_items','purchase_orders',
    'purchase_order_items','financial_entries','business_documents',
    'gei_module_catalog','gei_records','company_business_profiles'
  )
order by table_name,privilege_type;

-- authenticated não deve possuir TRUNCATE, REFERENCES, TRIGGER ou MAINTAIN
-- nas tabelas empresariais. O acesso a linhas continua dependendo de RLS.
select grantee,table_name,privilege_type
from information_schema.table_privileges
where table_schema='public'
  and grantee='authenticated'
  and privilege_type in ('TRUNCATE','REFERENCES','TRIGGER','MAINTAIN')
  and table_name in (
    'companies','company_members','company_modules','profiles','empresas',
    'employees','customers','suppliers','products','product_categories',
    'stock_movements','sales','sale_items','purchase_orders',
    'purchase_order_items','financial_entries','business_documents',
    'gei_module_catalog','gei_records','company_business_profiles'
  )
order by table_name,privilege_type;
