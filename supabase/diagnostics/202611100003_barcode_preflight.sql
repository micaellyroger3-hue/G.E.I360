-- G.E.I360 | Diagnóstico de códigos de barras
-- SOMENTE LEITURA: não altera produtos, índices ou permissões.
-- Funciona mesmo se a tabela products ainda não existir.

select to_regclass('public.products') is not null as products_existe;

select column_name,data_type,is_nullable
from information_schema.columns
where table_schema='public' and table_name='products'
  and column_name in ('company_id','barcode')
order by column_name;

select indexname,indexdef
from pg_indexes
where schemaname='public' and tablename='products'
  and indexname='products_company_barcode_uidx';

do $diagnostic$
declare
  v_count bigint;
  v_duplicates bigint;
  v_has_company boolean;
  v_has_barcode boolean;
begin
  if to_regclass('public.products') is null then
    raise notice 'public.products ainda não existe; aplique/revise primeiro a migration-base do ERP.';
    return;
  end if;

  select
    exists(select 1 from information_schema.columns where table_schema='public' and table_name='products' and column_name='company_id'),
    exists(select 1 from information_schema.columns where table_schema='public' and table_name='products' and column_name='barcode')
  into v_has_company,v_has_barcode;

  if not v_has_company or not v_has_barcode then
    raise notice 'Schema incompleto: company_id ausente=%, barcode ausente=%',
      not v_has_company,not v_has_barcode;
    return;
  end if;

  execute 'select count(*) from public.products where barcode is not null and btrim(barcode)<>'''' '
    into v_count;
  execute 'select count(*) from (select company_id,btrim(barcode) from public.products where barcode is not null and btrim(barcode)<>'''' group by company_id,btrim(barcode) having count(*)>1) d'
    into v_duplicates;
  raise notice 'Produtos com código: %; grupos duplicados na mesma empresa: %',
    v_count,v_duplicates;
end
$diagnostic$;
