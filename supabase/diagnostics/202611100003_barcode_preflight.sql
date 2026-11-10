-- G.E.I360 | Diagnóstico de códigos de barras
-- SOMENTE LEITURA: não altera produtos, índices ou permissões.

select to_regclass('public.products') is not null as products_existe;

select column_name,data_type,is_nullable
from information_schema.columns
where table_schema='public' and table_name='products'
  and column_name in ('company_id','barcode')
order by column_name;

select count(*) as produtos_com_codigo
from public.products
where barcode is not null and btrim(barcode)<>'';

select company_id,btrim(barcode) as codigo,count(*) as quantidade
from public.products
where barcode is not null and btrim(barcode)<>''
group by company_id,btrim(barcode)
having count(*)>1
order by quantidade desc,codigo;

select indexname,indexdef
from pg_indexes
where schemaname='public' and tablename='products'
  and indexname='products_company_barcode_uidx';
