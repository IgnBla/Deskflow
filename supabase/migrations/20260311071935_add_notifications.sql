-- ============================================================
-- Migration: Add notifications table + trigger for in-app notifications
-- Created: 2026-03-09
-- Description: In-app notification system via Supabase Realtime.
--   Triggers auto-create notifications on:
--   - New order INSERT
--   - Order status change UPDATE
--   - New chat message INSERT
--   Respects user_preferences toggles.
-- ============================================================

-- ===========================================
-- 1. NOTIFICATION TYPE ENUM
-- ===========================================
DO $$ BEGIN
  CREATE TYPE public.notification_type AS ENUM (
    'new_order',
    'status_change',
    'chat_message'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- ===========================================
-- 2. NOTIFICATIONS TABLE
-- ===========================================
CREATE TABLE IF NOT EXISTS public.notifications (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id          uuid NOT NULL REFERENCES public.organizations (id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  type            public.notification_type NOT NULL,
  title           text NOT NULL,
  body            text,
  -- Reference to the source entity
  order_id        uuid REFERENCES public.orders (id) ON DELETE CASCADE,
  is_read         boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- Indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_notifications_user_id
  ON public.notifications (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON public.notifications (user_id)
  WHERE NOT is_read;

CREATE INDEX IF NOT EXISTS idx_notifications_org_id
  ON public.notifications (org_id);

-- ===========================================
-- 3. RLS POLICIES
-- ===========================================
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Users can only read their own notifications
CREATE POLICY "Users can read own notifications"
  ON public.notifications FOR SELECT
  USING (auth.uid() = user_id);

-- Users can update (mark as read) only their own notifications
CREATE POLICY "Users can update own notifications"
  ON public.notifications FOR UPDATE
  USING (auth.uid() = user_id);

-- Users can delete their own notifications
CREATE POLICY "Users can delete own notifications"
  ON public.notifications FOR DELETE
  USING (auth.uid() = user_id);

-- System (triggers) insert via SECURITY DEFINER functions
-- No direct INSERT policy for users — only triggers can insert

-- ===========================================
-- 4. ENABLE REALTIME
-- ===========================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- ===========================================
-- 5. TRIGGER FUNCTION: New Order → Notify org members
-- ===========================================
CREATE OR REPLACE FUNCTION public.notify_new_order()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_member RECORD;
  v_order_number text;
  v_customer_name text;
BEGIN
  -- Build order display number
  v_order_number := '#' || LPAD(
    (SELECT COUNT(*) FROM orders WHERE organization_id = NEW.organization_id)::text,
    3, '0'
  );

  -- Get customer name if available
  SELECT name INTO v_customer_name
  FROM customers
  WHERE id = NEW.customer_id;

  -- Notify all org members except the order creator
  FOR v_member IN
    SELECT om.user_id
    FROM organization_members om
    LEFT JOIN user_preferences up
      ON up.user_id = om.user_id AND up.organization_id = NEW.organization_id
    WHERE om.organization_id = NEW.organization_id
      AND om.user_id != NEW.created_by
      -- Respect user preferences (default: notify = true)
      AND COALESCE(up.notify_new_orders, true) = true
  LOOP
    INSERT INTO notifications (org_id, user_id, type, title, body, order_id)
    VALUES (
      NEW.organization_id,
      v_member.user_id,
      'new_order',
      'Новый заказ ' || v_order_number,
      CASE
        WHEN v_customer_name IS NOT NULL THEN 'Клиент: ' || v_customer_name
        ELSE 'Без клиента'
      END,
      NEW.id
    );
  END LOOP;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_new_order
  AFTER INSERT ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_new_order();

-- ===========================================
-- 6. TRIGGER FUNCTION: Order Status Change → Notify org members
-- ===========================================
CREATE OR REPLACE FUNCTION public.notify_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_member RECORD;
  v_order_number text;
  v_new_status_name text;
  v_actor_id uuid;
BEGIN
  -- Only fire when status actually changes
  IF OLD.status_id = NEW.status_id THEN
    RETURN NEW;
  END IF;

  -- Build order display number
  v_order_number := '#' || LPAD(
    (SELECT row_number FROM (
      SELECT id, ROW_NUMBER() OVER (ORDER BY created_at) as row_number
      FROM orders WHERE organization_id = NEW.organization_id
    ) sub WHERE sub.id = NEW.id)::text,
    3, '0'
  );

  -- Get new status name
  SELECT name INTO v_new_status_name
  FROM order_statuses
  WHERE id = NEW.status_id;

  -- Determine who made the change (use created_by as approximation)
  v_actor_id := auth.uid();

  -- Notify all org members except the actor
  FOR v_member IN
    SELECT om.user_id
    FROM organization_members om
    LEFT JOIN user_preferences up
      ON up.user_id = om.user_id AND up.organization_id = NEW.organization_id
    WHERE om.organization_id = NEW.organization_id
      AND om.user_id != COALESCE(v_actor_id, NEW.created_by)
      AND COALESCE(up.notify_status_changes, true) = true
  LOOP
    INSERT INTO notifications (org_id, user_id, type, title, body, order_id)
    VALUES (
      NEW.organization_id,
      v_member.user_id,
      'status_change',
      'Заказ ' || v_order_number || ' → ' || COALESCE(v_new_status_name, 'Неизвестный'),
      'Статус изменён на "' || COALESCE(v_new_status_name, '?') || '"',
      NEW.id
    );
  END LOOP;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_status_change
  AFTER UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_status_change();

-- ===========================================
-- 7. TRIGGER FUNCTION: New Chat Message → Notify org members
-- ===========================================
CREATE OR REPLACE FUNCTION public.notify_chat_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_member RECORD;
  v_order_org_id uuid;
  v_order_number text;
  v_sender_name text;
BEGIN
  -- Get order's organization
  SELECT organization_id INTO v_order_org_id
  FROM orders
  WHERE id = NEW.order_id;

  IF v_order_org_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Build order display number
  v_order_number := '#' || LPAD(
    (SELECT row_number FROM (
      SELECT id, ROW_NUMBER() OVER (ORDER BY created_at) as row_number
      FROM orders WHERE organization_id = v_order_org_id
    ) sub WHERE sub.id = NEW.order_id)::text,
    3, '0'
  );

  -- Get sender name (FIX: column is sender_id, not user_id)
  SELECT full_name INTO v_sender_name
  FROM profiles
  WHERE id = NEW.sender_id;

  -- Notify all org members except the message sender (FIX: sender_id)
  FOR v_member IN
    SELECT om.user_id
    FROM organization_members om
    LEFT JOIN user_preferences up
      ON up.user_id = om.user_id AND up.organization_id = v_order_org_id
    WHERE om.organization_id = v_order_org_id
      AND om.user_id != NEW.sender_id
      AND COALESCE(up.notify_chat_messages, true) = true
  LOOP
    INSERT INTO notifications (org_id, user_id, type, title, body, order_id)
    VALUES (
      v_order_org_id,
      v_member.user_id,
      'chat_message',
      'Сообщение в заказе ' || v_order_number,
      COALESCE(v_sender_name, 'Участник') || ': ' ||
        LEFT(COALESCE(NEW.text, '[вложение]'), 100),
      NEW.order_id
    );
  END LOOP;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_chat_message
  AFTER INSERT ON public.chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_chat_message();
