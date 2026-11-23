-- G.E.I360 | Enforce company module switches and role-based business data reads.
-- Disabled modules remain stored; RLS blocks access until the module is re-enabled.
BEGIN;

CREATE OR REPLACE FUNCTION private.is_company_module_enabled(
  p_company_id uuid,
  p_module_code text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT
    EXISTS (
      SELECT 1
      FROM public.company_members cm
      WHERE cm.company_id = p_company_id
        AND cm.user_id = (SELECT auth.uid())
        AND cm.status = 'active'
    )
    AND EXISTS (
      SELECT 1
      FROM public.gei_module_catalog c
      LEFT JOIN public.company_modules m
        ON m.company_id = p_company_id
       AND m.module_code = c.code
      WHERE c.code = p_module_code
        AND c.is_available = true
        AND (c.is_core = true OR COALESCE(m.is_enabled, true) = true)
    );
$function$;

REVOKE ALL ON FUNCTION private.is_company_module_enabled(uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.is_company_module_enabled(uuid, text) TO authenticated, service_role;

-- Employees can work with their own time/operational data, but not browse
-- company-wide customer, sales, purchase, finance or business-document data.
ALTER POLICY business_documents_member_read ON public.business_documents
USING (private.has_company_role(company_id, ARRAY['owner','admin','manager','viewer']::text[]));
ALTER POLICY customers_member_read ON public.customers
USING (private.has_company_role(company_id, ARRAY['owner','admin','manager','viewer']::text[]));
ALTER POLICY financial_entries_member_read ON public.financial_entries
USING (private.has_company_role(company_id, ARRAY['owner','admin','manager','viewer']::text[]));
ALTER POLICY products_member_read ON public.products
USING (private.has_company_role(company_id, ARRAY['owner','admin','manager','viewer']::text[]));
ALTER POLICY purchase_items_member_select ON public.purchase_order_items
USING (private.has_company_role(company_id, ARRAY['owner','admin','manager','viewer']::text[]));
ALTER POLICY purchase_orders_member_select ON public.purchase_orders
USING (private.has_company_role(company_id, ARRAY['owner','admin','manager','viewer']::text[]));
ALTER POLICY sale_items_member_read ON public.sale_items
USING (private.has_company_role(company_id, ARRAY['owner','admin','manager','viewer']::text[]));
ALTER POLICY sales_member_read ON public.sales
USING (private.has_company_role(company_id, ARRAY['owner','admin','manager','viewer']::text[]));
ALTER POLICY stock_movements_member_read ON public.stock_movements
USING (private.has_company_role(company_id, ARRAY['owner','admin','manager','viewer']::text[]));
ALTER POLICY suppliers_member_read ON public.suppliers
USING (private.has_company_role(company_id, ARRAY['owner','admin','manager','viewer']::text[]));
ALTER POLICY gei360_categories_member_read ON public.product_categories
USING (private.has_company_role(company_id, ARRAY['owner','admin','manager','viewer']::text[]));

DROP POLICY IF EXISTS company_documents_member_read ON storage.objects;
CREATE POLICY company_documents_member_read
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'company-documents'
  AND EXISTS (
    SELECT 1
    FROM public.company_members cm
    WHERE cm.company_id::text = (storage.foldername(objects.name))[1]
      AND cm.user_id = (SELECT auth.uid())
      AND cm.status = 'active'
      AND cm.role = ANY (ARRAY['owner','admin','manager','viewer']::text[])
  )
);

-- A restrictive policy ANDs with all existing role policies, so the module
-- switch is enforced for direct REST calls as well as for the app navigation.
DO $module_gates$
DECLARE
  item record;
  policy_name text;
BEGIN
  FOR item IN
    SELECT * FROM (VALUES
      ('business_documents','fiscal'),
      ('customers','cadastros'),
      ('financial_entries','financeiro'),
      ('product_categories','cadastros'),
      ('products','produtos_servicos'),
      ('purchase_order_items','compras'),
      ('purchase_orders','compras'),
      ('sale_items','vendas'),
      ('sales','vendas'),
      ('stock_movements','estoque'),
      ('suppliers','cadastros'),
      ('employees','rh'),
      ('employee_compensation','rh'),
      ('hr_company_settings','rh'),
      ('hr_cost_postings','rh'),
      ('hr_events','rh'),
      ('hr_holidays','rh'),
      ('hr_schedule_exceptions','rh'),
      ('hr_time_adjustments','rh'),
      ('hr_time_bank_entries','rh'),
      ('hr_time_occurrences','rh'),
      ('hr_time_periods','rh'),
      ('hr_time_punches','rh'),
      ('hr_time_rules','rh'),
      ('hr_work_schedules','rh')
    ) AS v(table_name,module_code)
  LOOP
    policy_name := 'gei_module_gate_' || item.table_name;
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', policy_name, item.table_name);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I AS RESTRICTIVE FOR ALL TO authenticated USING (private.is_company_module_enabled(company_id, %L)) WITH CHECK (private.is_company_module_enabled(company_id, %L))',
      policy_name, item.table_name, item.module_code, item.module_code
    );
  END LOOP;
END;
$module_gates$;

DROP POLICY IF EXISTS gei_module_gate_gei_records ON public.gei_records;
CREATE POLICY gei_module_gate_gei_records
ON public.gei_records
AS RESTRICTIVE
FOR ALL
TO authenticated
USING (
  private.is_company_module_enabled(company_id, 'servicos')
  OR private.is_company_module_enabled(company_id, 'industria')
)
WITH CHECK (
  private.is_company_module_enabled(company_id, 'servicos')
  OR private.is_company_module_enabled(company_id, 'industria')
);

DROP POLICY IF EXISTS gei_module_gate_company_documents ON storage.objects;
CREATE POLICY gei_module_gate_company_documents
ON storage.objects
AS RESTRICTIVE
FOR ALL
TO authenticated
USING (
  bucket_id <> 'company-documents'
  OR EXISTS (
    SELECT 1
    FROM public.company_members cm
    JOIN public.gei_module_catalog c
      ON c.code = 'fiscal' AND c.is_available = true
    LEFT JOIN public.company_modules m
      ON m.company_id = cm.company_id AND m.module_code = c.code
    WHERE cm.company_id::text = (storage.foldername(objects.name))[1]
      AND cm.user_id = (SELECT auth.uid())
      AND cm.status = 'active'
      AND (c.is_core = true OR COALESCE(m.is_enabled, true) = true)
  )
)
WITH CHECK (
  bucket_id <> 'company-documents'
  OR EXISTS (
    SELECT 1
    FROM public.company_members cm
    JOIN public.gei_module_catalog c
      ON c.code = 'fiscal' AND c.is_available = true
    LEFT JOIN public.company_modules m
      ON m.company_id = cm.company_id AND m.module_code = c.code
    WHERE cm.company_id::text = (storage.foldername(objects.name))[1]
      AND cm.user_id = (SELECT auth.uid())
      AND cm.status = 'active'
      AND (c.is_core = true OR COALESCE(m.is_enabled, true) = true)
  )
);

COMMENT ON FUNCTION private.is_company_module_enabled(uuid, text)
IS 'Checks active company membership and the company-specific module switch; used by RLS restrictive policies';


-- SECURITY DEFINER RPCs bypass table RLS, so they enforce module switches directly.
CREATE OR REPLACE FUNCTION public.create_sale_cart(p_company_id uuid, p_customer_id uuid, p_items jsonb, p_discount numeric DEFAULT 0, p_notes text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user uuid := auth.uid();
  v_sale public.sales%rowtype;
  v_item jsonb;
  v_product public.products%rowtype;
  v_product_id uuid;
  v_quantity numeric(14,3);
  v_subtotal numeric(14,2) := 0;
  v_total numeric(14,2);
  v_seen uuid[] := array[]::uuid[];
  v_items_count integer := 0;
begin
  if v_user is null then
    raise exception 'Faça login novamente.';
  end if;

  if not public.has_company_role(
    p_company_id,
    array['owner','admin','manager']::text[]
  ) then
    raise exception 'Você não tem permissão para registrar vendas.';
  end if;

  if not private.is_company_module_enabled(p_company_id, 'vendas')
     or not private.is_company_module_enabled(p_company_id, 'produtos_servicos')
     or not private.is_company_module_enabled(p_company_id, 'estoque') then
    raise exception 'Os módulos Vendas, Produtos e Serviços e Estoque precisam estar habilitados.';
  end if;

  if jsonb_typeof(p_items) is distinct from 'array'
     or jsonb_array_length(p_items) = 0 then
    raise exception 'Adicione pelo menos um produto ao carrinho.';
  end if;

  if p_discount is null or p_discount < 0 then
    raise exception 'Desconto inválido.';
  end if;

  if p_customer_id is not null and not exists (
    select 1
    from public.customers
    where id = p_customer_id
      and company_id = p_company_id
  ) then
    raise exception 'Cliente não pertence a esta empresa.';
  end if;

  -- Bloqueia produtos em ordem determinística.
  for v_item in
    select value
    from jsonb_array_elements(p_items)
    order by (value->>'product_id')
  loop
    begin
      v_product_id := (v_item->>'product_id')::uuid;
      v_quantity := (v_item->>'quantity')::numeric;
    exception when others then
      raise exception 'Produto ou quantidade inválida no carrinho.';
    end;

    if v_product_id = any(v_seen) then
      raise exception 'Há produto repetido no carrinho.';
    end if;

    v_seen := array_append(v_seen,v_product_id);

    if v_quantity is null or v_quantity <= 0 then
      raise exception 'Quantidade inválida no carrinho.';
    end if;

    select *
    into v_product
    from public.products
    where id = v_product_id
      and company_id = p_company_id
      and active = true
    for update;

    if not found then
      raise exception 'Produto não encontrado ou inativo nesta empresa.';
    end if;

    if v_product.stock_quantity < v_quantity then
      raise exception 'Estoque insuficiente para %. Saldo atual: %',
        v_product.name,
        v_product.stock_quantity;
    end if;

    v_subtotal := v_subtotal
      + round(v_quantity * v_product.sale_price,2);

    v_items_count := v_items_count + 1;
  end loop;

  v_total := v_subtotal - p_discount;

  if v_total < 0 then
    raise exception 'O desconto não pode superar o subtotal.';
  end if;

  insert into public.sales(
    company_id,
    customer_id,
    status,
    subtotal,
    discount,
    total,
    notes,
    created_by
  )
  values (
    p_company_id,
    p_customer_id,
    'confirmed',
    v_subtotal,
    p_discount,
    v_total,
    p_notes,
    v_user
  )
  returning * into v_sale;

  for v_item in
    select value
    from jsonb_array_elements(p_items)
    order by (value->>'product_id')
  loop
    v_product_id := (v_item->>'product_id')::uuid;
    v_quantity := (v_item->>'quantity')::numeric;

    select *
    into v_product
    from public.products
    where id = v_product_id
      and company_id = p_company_id;

    insert into public.sale_items(
      company_id,
      sale_id,
      product_id,
      description,
      quantity,
      unit_price,
      created_by
    )
    values (
      p_company_id,
      v_sale.id,
      v_product.id,
      v_product.name,
      v_quantity,
      v_product.sale_price,
      v_user
    );

    insert into public.stock_movements(
      company_id,
      product_id,
      movement_type,
      quantity,
      note,
      created_by
    )
    values (
      p_company_id,
      v_product.id,
      'out',
      v_quantity,
      'Venda #' || v_sale.sale_number,
      v_user
    );
  end loop;

  return jsonb_build_object(
    'id',v_sale.id,
    'sale_number',v_sale.sale_number,
    'items_count',v_items_count,
    'subtotal',v_subtotal,
    'discount',p_discount,
    'total',v_total
  );
end;
$function$


CREATE OR REPLACE FUNCTION public.receive_purchase_cart(p_company_id uuid, p_supplier_id uuid, p_items jsonb, p_notes text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user uuid := auth.uid();
  v_order public.purchase_orders%rowtype;
  v_item jsonb;
  v_product public.products%rowtype;
  v_product_id uuid;
  v_quantity numeric(14,3);
  v_unit_cost numeric(14,2);
  v_total numeric(14,2) := 0;
  v_seen uuid[] := array[]::uuid[];
  v_items_count integer := 0;
begin
  if v_user is null then
    raise exception 'Faça login novamente.';
  end if;

  if not public.has_company_role(
    p_company_id,
    array['owner','admin','manager']::text[]
  ) then
    raise exception 'Sem permissão para registrar compras.';
  end if;

  if not private.is_company_module_enabled(p_company_id, 'compras')
     or not private.is_company_module_enabled(p_company_id, 'produtos_servicos')
     or not private.is_company_module_enabled(p_company_id, 'estoque') then
    raise exception 'Os módulos Compras, Produtos e Serviços e Estoque precisam estar habilitados.';
  end if;

  if jsonb_typeof(p_items) is distinct from 'array'
     or jsonb_array_length(p_items) = 0 then
    raise exception 'Adicione pelo menos um produto ao recebimento.';
  end if;

  if p_supplier_id is not null and not exists (
    select 1
    from public.suppliers
    where id = p_supplier_id
      and company_id = p_company_id
  ) then
    raise exception 'Fornecedor não pertence a esta empresa.';
  end if;

  for v_item in
    select value
    from jsonb_array_elements(p_items)
    order by (value->>'product_id')
  loop
    begin
      v_product_id := (v_item->>'product_id')::uuid;
      v_quantity := (v_item->>'quantity')::numeric;
      v_unit_cost := (v_item->>'unit_cost')::numeric;
    exception when others then
      raise exception 'Produto, quantidade ou custo inválido no recebimento.';
    end;

    if v_product_id = any(v_seen) then
      raise exception 'Há produto repetido no recebimento.';
    end if;

    v_seen := array_append(v_seen,v_product_id);

    if v_quantity is null
       or v_quantity <= 0
       or v_unit_cost is null
       or v_unit_cost < 0 then
      raise exception 'Quantidade ou custo inválido.';
    end if;

    select *
    into v_product
    from public.products
    where id = v_product_id
      and company_id = p_company_id
      and active = true
    for update;

    if not found then
      raise exception 'Produto não encontrado ou inativo nesta empresa.';
    end if;

    v_total := v_total + round(v_quantity * v_unit_cost,2);
    v_items_count := v_items_count + 1;
  end loop;

  insert into public.purchase_orders(
    company_id,
    supplier_id,
    status,
    total,
    notes,
    received_at,
    created_by
  )
  values (
    p_company_id,
    p_supplier_id,
    'received',
    v_total,
    p_notes,
    now(),
    v_user
  )
  returning * into v_order;

  for v_item in
    select value
    from jsonb_array_elements(p_items)
    order by (value->>'product_id')
  loop
    v_product_id := (v_item->>'product_id')::uuid;
    v_quantity := (v_item->>'quantity')::numeric;
    v_unit_cost := (v_item->>'unit_cost')::numeric;

    select *
    into v_product
    from public.products
    where id = v_product_id
      and company_id = p_company_id;

    insert into public.purchase_order_items(
      company_id,
      purchase_order_id,
      product_id,
      quantity,
      unit_cost,
      created_by
    )
    values (
      p_company_id,
      v_order.id,
      v_product_id,
      v_quantity,
      v_unit_cost,
      v_user
    );

    insert into public.stock_movements(
      company_id,
      product_id,
      movement_type,
      quantity,
      unit_cost,
      note,
      created_by
    )
    values (
      p_company_id,
      v_product_id,
      'in',
      v_quantity,
      v_unit_cost,
      'Recebimento da compra #' || v_order.order_number,
      v_user
    );
  end loop;

  return jsonb_build_object(
    'id',v_order.id,
    'order_number',v_order.order_number,
    'items_count',v_items_count,
    'total',v_total
  );
end;
$function$


CREATE OR REPLACE FUNCTION public.record_stock_movement(p_company_id uuid, p_product_id uuid, p_movement_type text, p_quantity numeric, p_unit_cost numeric DEFAULT 0, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user uuid := auth.uid();
  v_product public.products%rowtype;
  v_movement public.stock_movements%rowtype;
begin
  if v_user is null then
    raise exception 'Faça login novamente.';
  end if;

  if not public.has_company_role(
    p_company_id,
    array['owner','admin','manager']::text[]
  ) then
    raise exception 'Você não tem permissão para movimentar o estoque.';
  end if;

  if not private.is_company_module_enabled(p_company_id, 'estoque')
     or not private.is_company_module_enabled(p_company_id, 'produtos_servicos') then
    raise exception 'Os módulos Estoque e Produtos e Serviços precisam estar habilitados.';
  end if;

  if p_movement_type not in ('in','out','adjustment') then
    raise exception 'Tipo de movimentação inválido.';
  end if;

  if p_quantity is null
     or p_quantity < 0
     or (p_movement_type <> 'adjustment' and p_quantity = 0) then
    raise exception 'Quantidade inválida.';
  end if;

  if p_unit_cost is null or p_unit_cost < 0 then
    raise exception 'Custo unitário inválido.';
  end if;

  select *
  into v_product
  from public.products
  where id = p_product_id
    and company_id = p_company_id
  for update;

  if not found then
    raise exception 'Produto não encontrado nesta empresa.';
  end if;

  if p_movement_type = 'out'
     and v_product.stock_quantity < p_quantity then
    raise exception 'Estoque insuficiente. Saldo atual: %',
      v_product.stock_quantity;
  end if;

  insert into public.stock_movements(
    company_id,
    product_id,
    movement_type,
    quantity,
    unit_cost,
    note,
    created_by
  )
  values (
    p_company_id,
    p_product_id,
    p_movement_type,
    p_quantity,
    p_unit_cost,
    p_note,
    v_user
  )
  returning * into v_movement;

  return jsonb_build_object(
    'id',v_movement.id,
    'stock_quantity',
    (
      select stock_quantity
      from public.products
      where id = p_product_id
        and company_id = p_company_id
    )
  );
end;
$function$


CREATE OR REPLACE FUNCTION public.hr_register_time_punch(p_employee_id uuid, p_punch_type text)
 RETURNS hr_time_punches
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_employee public.employees%rowtype;
  v_last public.hr_time_punches%rowtype;
  v_source text;
  v_result public.hr_time_punches%rowtype;
begin
  if p_punch_type is null or p_punch_type not in ('entrada','inicio_intervalo','fim_intervalo','saida') then
    raise exception 'Tipo de marcação inválido.';
  end if;

  select * into v_employee
  from public.employees e
  where e.id = p_employee_id
    and e.employment_status <> 'inativo'
    and e.status = 'active';

  if not found then raise exception 'Funcionário não encontrado ou inativo.'; end if;

  if not private.is_company_module_enabled(v_employee.company_id, 'rh') then
    raise exception 'O módulo de RH está desativado para esta empresa.';
  end if;

  if v_employee.auth_user_id = (select auth.uid()) and exists (
    select 1 from public.company_members cm
    where cm.company_id = v_employee.company_id
      and cm.user_id = (select auth.uid())
      and cm.status = 'active'
      and cm.role = 'employee'
  ) then
    v_source := 'app_funcionario';
  elsif public.has_company_role(v_employee.company_id, array['owner','admin','manager']) then
    v_source := 'registro_gestor';
  else
    raise exception 'Você não tem autorização para registrar o ponto deste funcionário.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_employee_id::text, 0));

  select * into v_last
  from public.hr_time_punches p
  where p.employee_id = p_employee_id
  order by p.punched_at desc, p.created_at desc
  limit 1;

  if not found or v_last.punch_type = 'saida' then
    if p_punch_type <> 'entrada' then raise exception 'A primeira marcação da jornada deve ser Entrada.'; end if;
  elsif v_last.punch_type = 'entrada' then
    if p_punch_type not in ('inicio_intervalo','saida') then raise exception 'Após a entrada, registre início do intervalo ou saída.'; end if;
    if clock_timestamp() - v_last.punched_at > interval '18 hours' then raise exception 'Jornada aberta há mais de 18 horas. Solicite correção ao responsável.'; end if;
  elsif v_last.punch_type = 'inicio_intervalo' then
    if p_punch_type <> 'fim_intervalo' then raise exception 'Registre o retorno do intervalo.'; end if;
  elsif v_last.punch_type = 'fim_intervalo' then
    if p_punch_type not in ('inicio_intervalo','saida') then raise exception 'Registre outro intervalo ou a saída.'; end if;
  end if;

  insert into public.hr_time_punches(company_id, employee_id, punch_type, punched_at, source, created_by)
  values (v_employee.company_id, v_employee.id, p_punch_type, clock_timestamp(), v_source, (select auth.uid()))
  returning * into v_result;

  return v_result;
end;
$function$


CREATE OR REPLACE FUNCTION public.hr_claim_employee_account()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_email text;
  v_count integer;
begin
  select lower(u.email) into v_email
  from auth.users u
  where u.id = (select auth.uid()) and u.email_confirmed_at is not null;

  if v_email is null then
    raise exception 'Não foi possível identificar o e-mail confirmado da conta.';
  end if;

  update public.employees e
     set auth_user_id = (select auth.uid()), updated_at = now()
   where lower(e.email) = v_email
     and e.auth_user_id is null
     and e.status = 'active'
     and e.employment_status <> 'inativo'
     and private.is_company_module_enabled(e.company_id, 'rh')
     and exists (
       select 1 from public.company_members cm
       where cm.company_id = e.company_id
         and cm.user_id = (select auth.uid())
         and cm.status = 'active'
         and cm.role = 'employee'
     );

  get diagnostics v_count = row_count;
  return v_count;
end;
$function$


COMMIT;
