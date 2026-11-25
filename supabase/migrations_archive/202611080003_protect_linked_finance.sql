-- Protege no banco os lancamentos financeiros originados por vendas e compras.
-- Permite alterar somente a situacao e a data de pagamento; bloqueia exclusao.
create or replace function public.protect_linked_financial_entry()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.source_type is not null and old.source_id is not null then
    if tg_op = 'DELETE' then
      raise exception 'Este lancamento esta vinculado a uma venda ou compra e nao pode ser excluido.';
    end if;

    if new.status not in ('pending', 'paid') then
      raise exception 'Lancamentos vinculados so podem ficar pendentes ou pagos.';
    end if;

    if new.id is distinct from old.id
      or new.company_id is distinct from old.company_id
      or new.entry_type is distinct from old.entry_type
      or new.description is distinct from old.description
      or new.category is distinct from old.category
      or new.amount is distinct from old.amount
      or new.due_date is distinct from old.due_date
      or new.payment_method is distinct from old.payment_method
      or new.notes is distinct from old.notes
      or new.created_by is distinct from old.created_by
      or new.source_type is distinct from old.source_type
      or new.source_id is distinct from old.source_id then
      raise exception 'Os dados deste lancamento sao controlados pela venda ou compra de origem.';
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

revoke all on function public.protect_linked_financial_entry() from public;

drop trigger if exists protect_linked_financial_entry on public.financial_entries;
create trigger protect_linked_financial_entry
before update or delete on public.financial_entries
for each row execute function public.protect_linked_financial_entry();
