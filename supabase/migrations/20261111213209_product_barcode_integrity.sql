-- G.E.I360 | Integridade de códigos de barras por empresa
-- Protege o catálogo contra códigos duplicados sem alterar os códigos existentes.
begin;

do $preflight$
declare duplicate_groups bigint;
begin
  if to_regclass('public.products') is null then
    raise exception 'G.E.I360: tabela products não encontrada.';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='products' and column_name='company_id'
  ) or not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='products' and column_name='barcode'
  ) then
    raise exception 'G.E.I360: products.company_id ou products.barcode não existe.';
  end if;

  select count(*) into duplicate_groups
  from (
    select company_id,btrim(barcode)
    from public.products
    where barcode is not null and btrim(barcode)<>''
    group by company_id,btrim(barcode)
    having count(*)>1
  ) d;

  if duplicate_groups>0 then
    raise exception 'G.E.I360: existem % grupos de códigos de barras duplicados na mesma empresa. Use o diagnóstico antes de executar.',duplicate_groups;
  end if;
end
$preflight$;

create unique index if not exists products_company_barcode_uidx
  on public.products(company_id,btrim(barcode))
  where barcode is not null and btrim(barcode)<>'';

create or replace function public.gei360_normalize_product_barcode()
returns trigger
language plpgsql
set search_path=''
as $function$
begin
  if new.barcode is not null then
    new.barcode:=nullif(btrim(new.barcode),'');
  end if;
  return new;
end;
$function$;

revoke all on function public.gei360_normalize_product_barcode() from public,anon,authenticated;
drop trigger if exists gei360_products_barcode_normalize on public.products;
create trigger gei360_products_barcode_normalize
before insert or update of barcode on public.products
for each row execute function public.gei360_normalize_product_barcode();

commit;
