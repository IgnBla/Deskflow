-- ============================================================
-- Migration: Fix auth auto-confirm trigger timing
-- Created: 2026-02-16
-- Matches remote migration history entry
-- `fix_auto_confirm_before_insert`.
-- ============================================================

DROP TRIGGER IF EXISTS on_auth_user_auto_confirm ON auth.users;

CREATE OR REPLACE FUNCTION public.auto_confirm_user()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.email_confirmed_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_auto_confirm
  BEFORE INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_confirm_user();
