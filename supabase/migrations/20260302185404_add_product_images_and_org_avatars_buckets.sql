-- ============================================================
-- Migration: Create product-images and org-avatars storage buckets
-- Created: 2026-03-02
-- Matches remote migration history entry
-- `add_product_images_and_org_avatars_buckets`.
-- ============================================================

-- 1. Buckets
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'product-images',
  'product-images',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'org-avatars',
  'org-avatars',
  true,
  2097152,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- 2. Public read access
CREATE POLICY "Anyone can view product images"
  ON storage.objects
  FOR SELECT
  USING (bucket_id = 'product-images');

CREATE POLICY "Anyone can view org avatars"
  ON storage.objects
  FOR SELECT
  USING (bucket_id = 'org-avatars');

-- 3. Authenticated write access
CREATE POLICY "Authenticated users can upload product images"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'product-images');

CREATE POLICY "Authenticated users can update product images"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (bucket_id = 'product-images');

CREATE POLICY "Authenticated users can delete product images"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (bucket_id = 'product-images');

CREATE POLICY "Authenticated users can upload org avatars"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'org-avatars');

CREATE POLICY "Authenticated users can update org avatars"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (bucket_id = 'org-avatars');

CREATE POLICY "Authenticated users can delete org avatars"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (bucket_id = 'org-avatars');
