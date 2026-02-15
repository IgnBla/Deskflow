-- ============================================================
-- Deskflow: Initial Schema Migration
-- Created: 2026-02-16 (retroactive from live schema)
-- Description: Full database schema for Deskflow CRM
-- ============================================================

-- ===========================================
-- 1. HELPER FUNCTIONS
-- ===========================================

-- is_org_member: checks if current auth user is a member of the given org
CREATE OR REPLACE FUNCTION public.is_org_member(org_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM organization_members
    WHERE organization_id = org_id AND user_id = auth.uid()
  );
$$;

-- handle_new_user: auto-create profile on auth.users INSERT
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, avatar_url)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data ->> 'display_name', NEW.raw_user_meta_data ->> 'full_name', ''),
    COALESCE(NEW.raw_user_meta_data ->> 'avatar_url', '')
  );
  RETURN NEW;
END;
$$;

-- update_order_timestamp: auto-update updated_at on orders UPDATE
CREATE OR REPLACE FUNCTION public.update_order_timestamp()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- create_default_pipeline: auto-create default statuses on new organization
CREATE OR REPLACE FUNCTION public.create_default_pipeline()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  INSERT INTO public.order_statuses (organization_id, name, color, sort_order, is_default, is_final) VALUES
    (NEW.id, 'Новый',        '#3B82F6', 0, true,  false),
    (NEW.id, 'В обработке',  '#F59E0B', 1, false, false),
    (NEW.id, 'Собран',       '#8B5CF6', 2, false, false),
    (NEW.id, 'Доставка',     '#06B6D4', 3, false, false),
    (NEW.id, 'Завершён',     '#22C55E', 4, false, true),
    (NEW.id, 'Отменён',      '#EF4444', 5, false, true);
  RETURN NEW;
END;
$$;

-- create_organization: RPC to create org + add caller as owner
CREATE OR REPLACE FUNCTION public.create_organization(p_name text, p_logo_url text DEFAULT NULL)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_org organizations%ROWTYPE;
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 1. Create organization
  INSERT INTO organizations (name, logo_url)
  VALUES (p_name, p_logo_url)
  RETURNING * INTO v_org;

  -- 2. Add creator as owner
  INSERT INTO organization_members (organization_id, user_id, role)
  VALUES (v_org.id, v_user_id, 'owner');

  -- 3. Return full org row as JSON
  RETURN row_to_json(v_org);
END;
$$;

-- ===========================================
-- 2. TABLES
-- ===========================================

-- profiles: mirrors auth.users, created via trigger
CREATE TABLE IF NOT EXISTS public.profiles (
  id         uuid PRIMARY KEY,
  email      text,
  full_name  text,
  avatar_url text,
  created_at timestamptz DEFAULT now(),

  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users (id) ON DELETE CASCADE
);

-- organizations: multi-tenant org container
CREATE TABLE IF NOT EXISTS public.organizations (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  slug        text UNIQUE,
  logo_url    text,
  invite_code text UNIQUE DEFAULT substr(md5(random()::text), 1, 8),
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);

-- organization_members: join table user <-> org with role
CREATE TABLE IF NOT EXISTS public.organization_members (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations (id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  role            text NOT NULL DEFAULT 'member'
                  CHECK (role = ANY (ARRAY['owner', 'admin', 'member'])),
  joined_at       timestamptz DEFAULT now(),

  UNIQUE (organization_id, user_id)
);

-- order_statuses: customizable pipeline per-org
CREATE TABLE IF NOT EXISTS public.order_statuses (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations (id) ON DELETE CASCADE,
  name            text NOT NULL,
  color           text NOT NULL DEFAULT '#6B7280',
  sort_order      integer NOT NULL DEFAULT 0,
  is_default      boolean NOT NULL DEFAULT false,
  is_final        boolean NOT NULL DEFAULT false,
  created_at      timestamptz DEFAULT now()
);

-- customers: CRM contacts per-org
CREATE TABLE IF NOT EXISTS public.customers (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations (id) ON DELETE CASCADE,
  name            text NOT NULL,
  phone           text,
  email           text,
  address         text,
  notes           text,
  created_at      timestamptz DEFAULT now()
);

-- orders: core entity, linked to org, customer, status
CREATE SEQUENCE IF NOT EXISTS public.orders_order_number_seq;

CREATE TABLE IF NOT EXISTS public.orders (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations (id) ON DELETE CASCADE,
  customer_id     uuid REFERENCES public.customers (id) ON DELETE SET NULL,
  status_id       uuid NOT NULL REFERENCES public.order_statuses (id),
  order_number    integer NOT NULL DEFAULT nextval('orders_order_number_seq'),
  total_amount    numeric NOT NULL DEFAULT 0,
  delivery_cost   numeric NOT NULL DEFAULT 0,
  notes           text,
  created_by      uuid NOT NULL REFERENCES public.profiles (id),
  created_at      timestamptz DEFAULT now(),
  updated_at      timestamptz DEFAULT now()
);

-- products: catalog items per-org
CREATE TABLE IF NOT EXISTS public.products (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations (id) ON DELETE CASCADE,
  name            text NOT NULL,
  description     text,
  price           numeric NOT NULL DEFAULT 0,
  image_url       text,
  sku             text,
  is_active       boolean NOT NULL DEFAULT true,
  created_at      timestamptz DEFAULT now()
);

-- order_items: line items in an order
CREATE TABLE IF NOT EXISTS public.order_items (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id     uuid NOT NULL REFERENCES public.orders (id) ON DELETE CASCADE,
  product_id   uuid REFERENCES public.products (id) ON DELETE SET NULL,
  product_name text NOT NULL,
  unit_price   numeric NOT NULL,
  quantity     integer NOT NULL DEFAULT 1 CHECK (quantity >= 1),
  created_at   timestamptz DEFAULT now()
);

-- audit_events: audit log for entity changes
CREATE TABLE IF NOT EXISTS public.audit_events (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations (id) ON DELETE CASCADE,
  entity_type     text NOT NULL,
  entity_id       uuid NOT NULL,
  action          text NOT NULL,
  old_value       jsonb,
  new_value       jsonb,
  user_id         uuid NOT NULL REFERENCES public.profiles (id),
  created_at      timestamptz DEFAULT now()
);

-- chat_messages: order-scoped messages
CREATE TABLE IF NOT EXISTS public.chat_messages (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id      uuid NOT NULL REFERENCES public.orders (id) ON DELETE CASCADE,
  sender_id     uuid NOT NULL REFERENCES public.profiles (id),
  text          text,
  is_system     boolean NOT NULL DEFAULT false,
  system_action text,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- chat_attachments: files attached to chat messages
CREATE TABLE IF NOT EXISTS public.chat_attachments (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid NOT NULL REFERENCES public.chat_messages (id) ON DELETE CASCADE,
  url        text NOT NULL,
  file_name  text NOT NULL,
  mime_type  text NOT NULL DEFAULT 'application/octet-stream',
  size_bytes integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ===========================================
-- 3. INDEXES
-- ===========================================

CREATE INDEX IF NOT EXISTS idx_customers_org          ON public.customers (organization_id);
CREATE INDEX IF NOT EXISTS idx_orders_org             ON public.orders (organization_id);
CREATE INDEX IF NOT EXISTS idx_orders_customer        ON public.orders (customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_status          ON public.orders (status_id);
CREATE INDEX IF NOT EXISTS idx_order_statuses_org     ON public.order_statuses (organization_id);
CREATE INDEX IF NOT EXISTS idx_order_items_order      ON public.order_items (order_id);
CREATE INDEX IF NOT EXISTS idx_products_org           ON public.products (organization_id);
CREATE INDEX IF NOT EXISTS idx_audit_events_entity    ON public.audit_events (entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_order_id ON public.chat_messages (order_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON public.chat_messages (order_id, created_at);
CREATE INDEX IF NOT EXISTS idx_chat_attachments_message_id ON public.chat_attachments (message_id);

-- ===========================================
-- 4. TRIGGERS
-- ===========================================

-- Auto-create profile on auth.users INSERT
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Auto-create default pipeline on new organization
CREATE OR REPLACE TRIGGER trg_create_pipeline
  AFTER INSERT ON public.organizations
  FOR EACH ROW EXECUTE FUNCTION public.create_default_pipeline();

-- Auto-update updated_at on orders UPDATE
CREATE OR REPLACE TRIGGER trg_orders_updated_at
  BEFORE UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.update_order_timestamp();

-- ===========================================
-- 5. ROW LEVEL SECURITY (RLS)
-- ===========================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_statuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_attachments ENABLE ROW LEVEL SECURITY;

-- ---- profiles ----
CREATE POLICY "Users can read own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

-- ---- organizations ----
CREATE POLICY "Anyone can insert org"
  ON public.organizations FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Org members can read org"
  ON public.organizations FOR SELECT
  USING (is_org_member(id));

CREATE POLICY "Org owner can update org"
  ON public.organizations FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM organization_members m
      WHERE m.organization_id = organizations.id
        AND m.user_id = auth.uid()
        AND m.role = 'owner'
    )
  );

-- ---- organization_members ----
CREATE POLICY "Anyone can insert member"
  ON public.organization_members FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Org members can read members"
  ON public.organization_members FOR SELECT
  USING (is_org_member(organization_id));

CREATE POLICY "Org owner can update member"
  ON public.organization_members FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM organization_members m
      WHERE m.organization_id = organization_members.organization_id
        AND m.user_id = auth.uid()
        AND m.role = 'owner'
    )
  );

CREATE POLICY "Org owner can delete member"
  ON public.organization_members FOR DELETE
  USING (
    (EXISTS (
      SELECT 1 FROM organization_members m
      WHERE m.organization_id = organization_members.organization_id
        AND m.user_id = auth.uid()
        AND m.role = 'owner'
    ))
    OR (user_id = auth.uid())
  );

-- ---- order_statuses ----
CREATE POLICY "Org members can read statuses"
  ON public.order_statuses FOR SELECT
  USING (is_org_member(organization_id));

CREATE POLICY "Org members can insert statuses"
  ON public.order_statuses FOR INSERT
  WITH CHECK (is_org_member(organization_id));

CREATE POLICY "Org members can update statuses"
  ON public.order_statuses FOR UPDATE
  USING (is_org_member(organization_id));

-- ---- customers ----
CREATE POLICY "Org members can read customers"
  ON public.customers FOR SELECT
  USING (is_org_member(organization_id));

CREATE POLICY "Org members can insert customers"
  ON public.customers FOR INSERT
  WITH CHECK (is_org_member(organization_id));

CREATE POLICY "Org members can update customers"
  ON public.customers FOR UPDATE
  USING (is_org_member(organization_id));

-- ---- orders ----
CREATE POLICY "Org members can read orders"
  ON public.orders FOR SELECT
  USING (is_org_member(organization_id));

CREATE POLICY "Org members can insert orders"
  ON public.orders FOR INSERT
  WITH CHECK (is_org_member(organization_id));

CREATE POLICY "Org members can update orders"
  ON public.orders FOR UPDATE
  USING (is_org_member(organization_id));

-- ---- products ----
CREATE POLICY "Org members can read products"
  ON public.products FOR SELECT
  USING (is_org_member(organization_id));

CREATE POLICY "Org members can insert products"
  ON public.products FOR INSERT
  WITH CHECK (is_org_member(organization_id));

CREATE POLICY "Org members can update products"
  ON public.products FOR UPDATE
  USING (is_org_member(organization_id));

-- ---- order_items ----
CREATE POLICY "Org members can read order items"
  ON public.order_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = order_items.order_id AND is_org_member(o.organization_id)
    )
  );

CREATE POLICY "Org members can insert order items"
  ON public.order_items FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = order_items.order_id AND is_org_member(o.organization_id)
    )
  );

CREATE POLICY "Org members can update order items"
  ON public.order_items FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = order_items.order_id AND is_org_member(o.organization_id)
    )
  );

CREATE POLICY "Org members can delete order items"
  ON public.order_items FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = order_items.order_id AND is_org_member(o.organization_id)
    )
  );

-- ---- audit_events ----
CREATE POLICY "Org members can read audit events"
  ON public.audit_events FOR SELECT
  USING (is_org_member(organization_id));

CREATE POLICY "Org members can insert audit events"
  ON public.audit_events FOR INSERT
  WITH CHECK (is_org_member(organization_id));

-- ---- chat_messages ----
CREATE POLICY "Members can view order messages"
  ON public.chat_messages FOR SELECT
  USING (
    is_org_member((
      SELECT orders.organization_id FROM orders
      WHERE orders.id = chat_messages.order_id
    ))
  );

CREATE POLICY "Members can send messages"
  ON public.chat_messages FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id
    AND is_org_member((
      SELECT orders.organization_id FROM orders
      WHERE orders.id = chat_messages.order_id
    ))
  );

-- ---- chat_attachments ----
CREATE POLICY "Members can view attachments"
  ON public.chat_attachments FOR SELECT
  USING (
    is_org_member((
      SELECT o.organization_id
      FROM orders o
      JOIN chat_messages cm ON cm.order_id = o.id
      WHERE cm.id = chat_attachments.message_id
    ))
  );

CREATE POLICY "Members can insert attachments"
  ON public.chat_attachments FOR INSERT
  WITH CHECK (
    is_org_member((
      SELECT o.organization_id
      FROM orders o
      JOIN chat_messages cm ON cm.order_id = o.id
      WHERE cm.id = chat_attachments.message_id
    ))
  );

-- ===========================================
-- 6. REALTIME
-- ===========================================

-- Enable Realtime for chat_messages
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;

-- ===========================================
-- 7. STORAGE
-- ===========================================

-- Create chat-attachments bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'chat-attachments',
  'chat-attachments',
  true,
  10485760, -- 10 MB
  ARRAY[
    'image/jpeg', 'image/png', 'image/gif', 'image/webp',
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'text/plain',
    'video/mp4', 'video/quicktime',
    'application/octet-stream'
  ]
) ON CONFLICT (id) DO NOTHING;

-- Storage RLS policies
CREATE POLICY "Anyone can view chat attachments"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'chat-attachments');

CREATE POLICY "Authenticated users can upload chat attachments"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'chat-attachments');
