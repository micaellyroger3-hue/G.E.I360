-- G.E.I360 | Libera registros operacionais específicos por ramo.
-- Não altera registros existentes; apenas amplia os códigos aceitos em gei_records.
begin;
alter table public.gei_records
  drop constraint if exists gei_records_module_code_check;
alter table public.gei_records
  add constraint gei_records_module_code_check
  check (module_code = any (array[
    'customers','suppliers','products','stock','purchases','sales','pos',
    'finance','services','production','employees','fiscal','branches','sector_ops'
  ]::text[]));
commit;
