-- Migration: Fix DB advisor findings that can be addressed in SQL
-- Leaves Auth leaked-password protection for manual enablement in Supabase dashboard.

CREATE OR REPLACE FUNCTION public.update_order_timestamp()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_user_preferences_timestamp()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$function$;

CREATE INDEX IF NOT EXISTS idx_audit_events_organization_id
  ON public.audit_events (organization_id);

CREATE INDEX IF NOT EXISTS idx_audit_events_user_id
  ON public.audit_events (user_id);

CREATE INDEX IF NOT EXISTS idx_chat_messages_sender_id
  ON public.chat_messages (sender_id);

CREATE INDEX IF NOT EXISTS idx_notifications_order_id
  ON public.notifications (order_id);

CREATE INDEX IF NOT EXISTS idx_order_items_product_id
  ON public.order_items (product_id);

CREATE INDEX IF NOT EXISTS idx_orders_created_by
  ON public.orders (created_by);

CREATE INDEX IF NOT EXISTS idx_organization_invites_accepted_by
  ON public.organization_invites (accepted_by);

CREATE INDEX IF NOT EXISTS idx_organization_invites_invited_by
  ON public.organization_invites (invited_by);

CREATE INDEX IF NOT EXISTS idx_organization_members_user_id
  ON public.organization_members (user_id);

CREATE INDEX IF NOT EXISTS idx_user_preferences_organization_id
  ON public.user_preferences (organization_id);

DROP POLICY IF EXISTS "Users can read own profile" ON public.profiles;
DROP POLICY IF EXISTS "Members can read org co-member profiles" ON public.profiles;
CREATE POLICY "Users can read accessible profiles"
  ON public.profiles FOR SELECT
  TO public
  USING (
    ((SELECT auth.uid()) = id)
    OR EXISTS (
      SELECT 1
      FROM public.organization_members my
      JOIN public.organization_members their
        ON my.organization_id = their.organization_id
      WHERE my.user_id = (SELECT auth.uid())
        AND their.user_id = profiles.id
    )
  );

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  TO public
  USING ((SELECT auth.uid()) = id);

DROP POLICY IF EXISTS "Org owner can update member" ON public.organization_members;
CREATE POLICY "Org owner can update member"
  ON public.organization_members FOR UPDATE
  TO public
  USING (
    EXISTS (
      SELECT 1
      FROM public.organization_members m
      WHERE m.organization_id = organization_members.organization_id
        AND m.user_id = (SELECT auth.uid())
        AND m.role = 'owner'
    )
  );

DROP POLICY IF EXISTS "Org owner can delete member" ON public.organization_members;
CREATE POLICY "Org owner can delete member"
  ON public.organization_members FOR DELETE
  TO public
  USING (
    EXISTS (
      SELECT 1
      FROM public.organization_members m
      WHERE m.organization_id = organization_members.organization_id
        AND m.user_id = (SELECT auth.uid())
        AND m.role = 'owner'
    )
    OR user_id = (SELECT auth.uid())
  );

DROP POLICY IF EXISTS "Org owner can update org" ON public.organizations;
CREATE POLICY "Org owner can update org"
  ON public.organizations FOR UPDATE
  TO public
  USING (
    EXISTS (
      SELECT 1
      FROM public.organization_members m
      WHERE m.organization_id = organizations.id
        AND m.user_id = (SELECT auth.uid())
        AND m.role = 'owner'
    )
  );

DROP POLICY IF EXISTS "Org owner can delete org" ON public.organizations;
CREATE POLICY "Org owner can delete org"
  ON public.organizations FOR DELETE
  TO public
  USING (
    EXISTS (
      SELECT 1
      FROM public.organization_members m
      WHERE m.organization_id = organizations.id
        AND m.user_id = (SELECT auth.uid())
        AND m.role = 'owner'
    )
  );

DROP POLICY IF EXISTS "Members can send messages" ON public.chat_messages;
CREATE POLICY "Members can send messages"
  ON public.chat_messages FOR INSERT
  TO public
  WITH CHECK (
    (SELECT auth.uid()) = sender_id
    AND is_org_member((
      SELECT orders.organization_id
      FROM public.orders
      WHERE orders.id = chat_messages.order_id
    ))
  );

DROP POLICY IF EXISTS "Users can read own preferences" ON public.user_preferences;
CREATE POLICY "Users can read own preferences"
  ON public.user_preferences FOR SELECT
  TO public
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can insert own preferences" ON public.user_preferences;
CREATE POLICY "Users can insert own preferences"
  ON public.user_preferences FOR INSERT
  TO public
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update own preferences" ON public.user_preferences;
CREATE POLICY "Users can update own preferences"
  ON public.user_preferences FOR UPDATE
  TO public
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can read own notifications" ON public.notifications;
CREATE POLICY "Users can read own notifications"
  ON public.notifications FOR SELECT
  TO public
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications"
  ON public.notifications FOR UPDATE
  TO public
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can delete own notifications" ON public.notifications;
CREATE POLICY "Users can delete own notifications"
  ON public.notifications FOR DELETE
  TO public
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Org admins can read organization invites" ON public.organization_invites;
CREATE POLICY "Org admins can read organization invites"
  ON public.organization_invites FOR SELECT
  TO public
  USING (
    EXISTS (
      SELECT 1
      FROM public.organization_members m
      WHERE m.organization_id = organization_invites.organization_id
        AND m.user_id = (SELECT auth.uid())
        AND m.role = ANY (ARRAY['owner'::text, 'admin'::text])
    )
  );
