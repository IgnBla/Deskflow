-- ============================================================
-- Migration: Atomic order creation RPC
-- Created: 2026-11-19 (cleanup follow-up; applies after all donor migrations)
-- ============================================================
-- The app previously performed three separate inserts (order, items, audit).
-- This SECURITY INVOKER RPC inserts all related rows in one statement so a
-- failure cannot leave an order without items or audit history. RLS policies
-- for orders, order_items and audit_events remain enforced for the caller.
-- ============================================================

CREATE OR REPLACE FUNCTION public.create_order_with_items(
  p_organization_id uuid,
  p_customer_id uuid,
  p_status_id uuid,
  p_total_amount numeric,
  p_delivery_cost numeric,
  p_notes text,
  p_created_by uuid,
  p_items jsonb DEFAULT '[]'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'public'
AS $function$
DECLARE
  v_order public.orders%ROWTYPE;
  v_item jsonb;
BEGIN
  IF p_organization_id IS NULL THEN
    RAISE EXCEPTION 'ORG_ID_REQUIRED';
  END IF;
  IF p_status_id IS NULL THEN
    RAISE EXCEPTION 'STATUS_ID_REQUIRED';
  END IF;
  IF p_created_by IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'CREATED_BY_MISMATCH';
  END IF;
  IF p_items IS NULL THEN
    p_items := '[]'::jsonb;
  END IF;
  IF jsonb_typeof(p_items) <> 'array' THEN
    RAISE EXCEPTION 'ITEMS_MUST_BE_ARRAY';
  END IF;

  INSERT INTO public.orders (
    organization_id,
    customer_id,
    status_id,
    total_amount,
    delivery_cost,
    notes,
    created_by
  )
  VALUES (
    p_organization_id,
    p_customer_id,
    p_status_id,
    p_total_amount,
    p_delivery_cost,
    p_notes,
    p_created_by
  )
  RETURNING * INTO v_order;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    INSERT INTO public.order_items (
      order_id,
      product_id,
      product_name,
      unit_price,
      quantity
    )
    VALUES (
      v_order.id,
      NULLIF(v_item->>'product_id', '')::uuid,
      v_item->>'product_name',
      (v_item->>'unit_price')::numeric,
      COALESCE((v_item->>'quantity')::integer, 1)
    );
  END LOOP;

  INSERT INTO public.audit_events (
    organization_id,
    entity_type,
    entity_id,
    action,
    user_id,
    new_value
  )
  VALUES (
    p_organization_id,
    'order',
    v_order.id,
    'order_created',
    p_created_by,
    jsonb_build_object('order_number', v_order.order_number)
  );

  RETURN v_order.id;
END;
$function$;

REVOKE ALL ON FUNCTION public.create_order_with_items(
  uuid, uuid, uuid, numeric, numeric, text, uuid, jsonb
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_order_with_items(
  uuid, uuid, uuid, numeric, numeric, text, uuid, jsonb
) TO authenticated;
