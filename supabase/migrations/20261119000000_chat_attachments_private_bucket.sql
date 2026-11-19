-- ============================================================
-- Migration: Make chat attachment storage private and org-scoped
-- Created: 2026-11-19 (cleanup follow-up; applies after all donor migrations)
-- ============================================================
-- chat-attachments previously used a public bucket with a public read policy.
-- This migration makes the bucket private and replaces the permissive
-- storage policies with org-membership checks based on the object path:
--   chat/{order_id}/{message_id}/{file}
-- ============================================================

-- 1. Make the bucket private.
UPDATE storage.buckets
SET public = false
WHERE id = 'chat-attachments';

-- 2. Remove the old permissive policies. Postgres permissive policies are
--    OR-ed together, so leaving them in place would keep the bucket public.
DROP POLICY IF EXISTS "Anyone can view chat attachments"
  ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload chat attachments"
  ON storage.objects;

-- 3. Allow order participants to read attachments in their organization.
CREATE POLICY "Org members can view chat attachments"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'chat-attachments'
    AND EXISTS (
      SELECT 1
      FROM public.orders o
      WHERE o.id::text = split_part(name, '/', 2)
        AND public.is_org_member(o.organization_id)
    )
  );

-- 4. Allow organization members to upload attachments into an order folder.
CREATE POLICY "Org members can upload chat attachments"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'chat-attachments'
    AND auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM public.orders o
      WHERE o.id::text = split_part(name, '/', 2)
        AND public.is_org_member(o.organization_id)
    )
  );

-- Notes:
-- - UPDATE/DELETE policies are intentionally not granted: chat attachments
--   are immutable message content in the current app.
-- - Existing public URLs generated before this migration stop working once
--   the bucket becomes private.
