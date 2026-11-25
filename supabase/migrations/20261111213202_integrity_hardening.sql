-- G.E.I360 — hardening de integridade operacional
-- Permite zerar o estoque em ajustes e impede alterações diretas em campos controlados.

-- Entrada/saída exigem quantidade positiva; ajuste pode definir saldo zero.
alter table public.stock_movements
  drop constraint if exists stock_movements_quantity_check;

alter table public.stock_movements
  drop constraint if exists stock_movements_quantity_valid_check;

alter table public.stock_movements
  add constraint stock_movements_quantity_valid_check
  check (
    (movement_type = 'adjustment' and quantity >= 0)
    or (movement_type in ('in','out') and quantity > 0)
  );

-- O saldo nasce em zero e só pode mudar por meio de movimentações validadas e seus triggers.
revoke insert, update on table public.products from authenticated;
grant insert (
  company_id, name, sku, barcode, category, unit,
  cost_price, sale_price, min_stock, active, created_by
) on table public.products to authenticated;
grant update (
  name, sku, barcode, category, unit,
  cost_price, sale_price, min_stock, active
) on table public.products to authenticated;

-- Vínculos de origem do financeiro são preenchidos exclusivamente pelos triggers.
revoke insert, update on table public.financial_entries from authenticated;
grant insert (
  company_id, entry_type, description, category, amount,
  due_date, status, payment_method, notes, created_by
) on table public.financial_entries to authenticated;
grant update (
  entry_type, description, category, amount, due_date,
  status, payment_method, notes, paid_at
) on table public.financial_entries to authenticated;

-- Funções internas de trigger não precisam ser invocáveis via API.
revoke all on function public.apply_stock_movement() from public, anon, authenticated;
revoke all on function public.create_sale_financial_entry() from public, anon, authenticated;
revoke all on function public.create_purchase_financial_entry() from public, anon, authenticated;
revoke all on function public.protect_linked_financial_entry() from public, anon, authenticated;
