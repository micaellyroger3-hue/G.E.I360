-- Datas locais do negócio: manter o banco em UTC e calcular datas de calendário no fuso de Brasília.

ALTER TABLE public.sales
  ALTER COLUMN sale_date
  SET DEFAULT ((now() AT TIME ZONE 'America/Sao_Paulo')::date);

ALTER TABLE public.financial_entries
  ALTER COLUMN due_date
  SET DEFAULT ((now() AT TIME ZONE 'America/Sao_Paulo')::date);

CREATE OR REPLACE FUNCTION public.create_sale_financial_entry()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_customer_name text;
BEGIN
  IF NEW.status = 'confirmed' AND NEW.total > 0 THEN
    SELECT name INTO v_customer_name
    FROM public.customers
    WHERE id = NEW.customer_id
      AND company_id = NEW.company_id;

    INSERT INTO public.financial_entries(
      company_id, entry_type, description, category, amount,
      due_date, status, notes, created_by, source_type, source_id
    )
    VALUES (
      NEW.company_id,
      'income',
      'Venda #' || NEW.sale_number ||
        CASE WHEN v_customer_name IS NOT NULL THEN ' - ' || v_customer_name ELSE '' END,
      'Venda',
      NEW.total,
      NEW.sale_date,
      'pending',
      'Lançamento gerado automaticamente pela venda.',
      NEW.created_by,
      'sale',
      NEW.id
    )
    ON CONFLICT (company_id, source_type, source_id)
      WHERE source_type IS NOT NULL AND source_id IS NOT NULL
      DO NOTHING;
  END IF;

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_purchase_financial_entry()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_supplier_name text;
  v_local_received_date date;
BEGIN
  IF NEW.status = 'received' AND NEW.total > 0 THEN
    SELECT name INTO v_supplier_name
    FROM public.suppliers
    WHERE id = NEW.supplier_id
      AND company_id = NEW.company_id;

    v_local_received_date :=
      (COALESCE(NEW.received_at, NEW.created_at) AT TIME ZONE 'America/Sao_Paulo')::date;

    INSERT INTO public.financial_entries(
      company_id, entry_type, description, category, amount,
      due_date, status, notes, created_by, source_type, source_id
    )
    VALUES (
      NEW.company_id,
      'expense',
      'Compra #' || NEW.order_number ||
        CASE WHEN v_supplier_name IS NOT NULL THEN ' - ' || v_supplier_name ELSE '' END,
      'Compra',
      NEW.total,
      v_local_received_date,
      'pending',
      'Lançamento gerado automaticamente pelo recebimento da compra.',
      NEW.created_by,
      'purchase',
      NEW.id
    )
    ON CONFLICT (company_id, source_type, source_id)
      WHERE source_type IS NOT NULL AND source_id IS NOT NULL
      DO NOTHING;
  END IF;

  RETURN NEW;
END;
$function$;
