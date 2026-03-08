-- ============================================================
-- Migration: Extend notifications payload
-- Created: 2026-03-09
-- Matches remote migration history entry `notification_title_key`.
-- ============================================================

ALTER TABLE IF EXISTS public.notifications
  ADD COLUMN IF NOT EXISTS title_key text,
  ADD COLUMN IF NOT EXISTS payload jsonb;
