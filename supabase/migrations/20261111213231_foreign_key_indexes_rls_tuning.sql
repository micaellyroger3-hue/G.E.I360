-- G.E.I360 | Índices de FKs sem cobertura + otimização de RLS
do $$
declare
  r record;
  cols text;
  idx text;
begin
  for r in
    select con.oid,con.conrelid,con.conname,con.conkey
    from pg_constraint con
    join pg_class t on t.oid=con.conrelid
    join pg_namespace n on n.oid=t.relnamespace
    where con.contype='f' and n.nspname='public'
      and not exists (
        select 1
        from pg_index i
        where i.indrelid=con.conrelid
          and i.indisvalid and i.indisready and i.indpred is null
          and i.indnkeyatts >= cardinality(con.conkey)
          and (
            select array_agg(k.attnum::smallint order by k.ord)
            from unnest(i.indkey) with ordinality as k(attnum,ord)
            where k.ord <= cardinality(con.conkey)
          ) = con.conkey
      )
  loop
    select string_agg(format('%I',a.attname),', ' order by k.ord)
      into cols
    from unnest(r.conkey) with ordinality as k(attnum,ord)
    join pg_attribute a on a.attrelid=r.conrelid and a.attnum=k.attnum;
    idx := left('idx_fk_'||r.conname||'_'||substr(md5(r.conname),1,8),63);
    execute format('create index if not exists %I on %s (%s)',
      idx,r.conrelid::regclass,cols);
  end loop;
end $$;

drop policy if exists gei_records_member_insert on public.gei_records;
create policy gei_records_member_insert
on public.gei_records for insert to authenticated
with check (
  public.is_company_member(company_id)
  and created_by = (select auth.uid())
);