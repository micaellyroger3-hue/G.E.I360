-- Remove legacy anonymous access to public business-number sequences.
-- Authenticated users retain USAGE only so normal inserts can use sequence defaults.
BEGIN;

REVOKE ALL ON SEQUENCE
  public.purchase_orders_order_number_seq,
  public.sales_sale_number_seq
FROM PUBLIC, anon, authenticated;

GRANT USAGE ON SEQUENCE
  public.purchase_orders_order_number_seq,
  public.sales_sale_number_seq
TO authenticated;

GRANT ALL ON SEQUENCE
  public.purchase_orders_order_number_seq,
  public.sales_sale_number_seq
TO service_role;

COMMIT;
