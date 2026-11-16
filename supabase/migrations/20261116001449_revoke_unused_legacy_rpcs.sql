-- G.E.I360 | Remove RPCs legadas sem chamadas no frontend atual.
-- A interface usa create_sale_cart, receive_purchase_cart e create_company.
begin;
revoke execute on function public.create_sale(uuid,uuid,uuid,numeric,numeric,text)
  from public, anon, authenticated;
revoke execute on function public.receive_purchase(uuid,uuid,uuid,numeric,numeric,text)
  from public, anon, authenticated;
revoke execute on function public.get_my_companies()
  from public, anon, authenticated;
commit;
