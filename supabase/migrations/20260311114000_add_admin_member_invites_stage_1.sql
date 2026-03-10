-- ============================================================
-- Migration: Add admin member invites stage 1
-- Created: 2026-03-11
-- Adds pending email invites with code/link acceptance.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.organization_invites (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations (id) ON DELETE CASCADE,
  email           text NOT NULL,
  role            text NOT NULL DEFAULT 'member'
    CHECK (role = ANY (ARRAY['owner'::text, 'admin'::text, 'member'::text])),
  invite_code     text NOT NULL UNIQUE,
  invite_token    text NOT NULL UNIQUE,
  status          text NOT NULL DEFAULT 'pending'
    CHECK (status = ANY (ARRAY['pending'::text, 'accepted'::text, 'revoked'::text, 'expired'::text])),
  invited_by      uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  accepted_by     uuid REFERENCES public.profiles (id) ON DELETE SET NULL,
  accepted_at     timestamptz,
  expires_at      timestamptz NOT NULL DEFAULT (now() + interval '14 days'),
  last_sent_at    timestamptz NOT NULL DEFAULT now(),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),

  CHECK (length(trim(email)) > 3)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_org_invites_pending_email
  ON public.organization_invites (organization_id, lower(email))
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_org_invites_org_status_created
  ON public.organization_invites (organization_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_org_invites_email_status
  ON public.organization_invites (lower(email), status, created_at DESC);

ALTER TABLE public.organization_invites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Org admins can read organization invites"
  ON public.organization_invites FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.organization_members m
      WHERE m.organization_id = organization_invites.organization_id
        AND m.user_id = auth.uid()
        AND m.role IN ('owner', 'admin')
    )
  );

CREATE OR REPLACE FUNCTION public.invite_member_by_email_v2(
  p_org_id uuid,
  p_email text,
  p_role text DEFAULT 'member'
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid;
  v_caller_role text;
  v_existing_member organization_members%ROWTYPE;
  v_existing_invite organization_invites%ROWTYPE;
  v_invite organization_invites%ROWTYPE;
  v_target_user_id uuid;
  v_email text;
  v_invite_code text;
  v_invite_token text;
BEGIN
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  v_email := lower(trim(p_email));
  IF v_email = '' THEN
    RAISE EXCEPTION 'INVALID_EMAIL';
  END IF;

  IF position('@' in v_email) <= 1 THEN
    RAISE EXCEPTION 'INVALID_EMAIL';
  END IF;

  IF p_role NOT IN ('owner', 'admin', 'member') THEN
    RAISE EXCEPTION 'INVALID_ROLE';
  END IF;

  SELECT role INTO v_caller_role
  FROM public.organization_members
  WHERE organization_id = p_org_id
    AND user_id = v_caller_id;

  IF v_caller_role IS NULL OR v_caller_role NOT IN ('owner', 'admin') THEN
    RAISE EXCEPTION 'NOT_ALLOWED';
  END IF;

  IF v_caller_role = 'admin' AND p_role = 'owner' THEN
    RAISE EXCEPTION 'NOT_ALLOWED_ROLE';
  END IF;

  SELECT id INTO v_target_user_id
  FROM public.profiles
  WHERE lower(email) = v_email;

  IF v_target_user_id IS NOT NULL THEN
    SELECT * INTO v_existing_member
    FROM public.organization_members
    WHERE organization_id = p_org_id
      AND user_id = v_target_user_id;

    IF v_existing_member IS NOT NULL THEN
      RAISE EXCEPTION 'ALREADY_MEMBER';
    END IF;
  END IF;

  LOOP
    v_invite_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    EXIT WHEN NOT EXISTS (
      SELECT 1
      FROM public.organization_invites
      WHERE invite_code = v_invite_code
    );
  END LOOP;

  LOOP
    v_invite_token := encode(gen_random_bytes(24), 'hex');
    EXIT WHEN NOT EXISTS (
      SELECT 1
      FROM public.organization_invites
      WHERE invite_token = v_invite_token
    );
  END LOOP;

  SELECT * INTO v_existing_invite
  FROM public.organization_invites
  WHERE organization_id = p_org_id
    AND lower(email) = v_email
    AND status = 'pending';

  IF v_existing_invite IS NULL THEN
    INSERT INTO public.organization_invites (
      organization_id,
      email,
      role,
      invite_code,
      invite_token,
      status,
      invited_by,
      expires_at,
      last_sent_at,
      updated_at
    )
    VALUES (
      p_org_id,
      v_email,
      p_role,
      v_invite_code,
      v_invite_token,
      'pending',
      v_caller_id,
      now() + interval '14 days',
      now(),
      now()
    )
    RETURNING * INTO v_invite;
  ELSE
    UPDATE public.organization_invites
    SET role = p_role,
        invite_code = v_invite_code,
        invite_token = v_invite_token,
        invited_by = v_caller_id,
        expires_at = now() + interval '14 days',
        last_sent_at = now(),
        updated_at = now()
    WHERE id = v_existing_invite.id
    RETURNING * INTO v_invite;
  END IF;

  RETURN json_build_object(
    'id', v_invite.id,
    'organization_id', v_invite.organization_id,
    'email', v_invite.email,
    'role', v_invite.role,
    'invite_code', v_invite.invite_code,
    'invite_token', v_invite.invite_token,
    'status', v_invite.status,
    'expires_at', v_invite.expires_at,
    'last_sent_at', v_invite.last_sent_at
  );
END;
$$;

CREATE OR REPLACE FUNCTION public._accept_org_invite(
  p_invite_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid;
  v_caller_email text;
  v_invite organization_invites%ROWTYPE;
  v_existing_member organization_members%ROWTYPE;
  v_org organizations%ROWTYPE;
BEGIN
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT email INTO v_caller_email
  FROM public.profiles
  WHERE id = v_caller_id;

  IF v_caller_email IS NULL OR trim(v_caller_email) = '' THEN
    RAISE EXCEPTION 'EMAIL_NOT_AVAILABLE';
  END IF;

  SELECT * INTO v_invite
  FROM public.organization_invites
  WHERE id = p_invite_id;

  IF v_invite IS NULL THEN
    RAISE EXCEPTION 'INVITE_NOT_FOUND';
  END IF;

  IF lower(v_invite.email) <> lower(v_caller_email) THEN
    RAISE EXCEPTION 'EMAIL_MISMATCH';
  END IF;

  IF v_invite.status = 'revoked' THEN
    RAISE EXCEPTION 'INVITE_REVOKED';
  END IF;

  IF v_invite.status = 'expired' OR v_invite.expires_at < now() THEN
    IF v_invite.status = 'pending' THEN
      UPDATE public.organization_invites
      SET status = 'expired',
          updated_at = now()
      WHERE id = v_invite.id;
    END IF;
    RAISE EXCEPTION 'INVITE_EXPIRED';
  END IF;

  SELECT * INTO v_existing_member
  FROM public.organization_members
  WHERE organization_id = v_invite.organization_id
    AND user_id = v_caller_id;

  IF v_invite.status = 'accepted' THEN
    IF v_existing_member IS NULL THEN
      RAISE EXCEPTION 'INVITE_ALREADY_ACCEPTED';
    END IF;
  ELSE
    INSERT INTO public.organization_members (organization_id, user_id, role)
    VALUES (v_invite.organization_id, v_caller_id, v_invite.role)
    ON CONFLICT (organization_id, user_id) DO NOTHING;

    UPDATE public.organization_invites
    SET status = 'accepted',
        accepted_by = v_caller_id,
        accepted_at = COALESCE(accepted_at, now()),
        updated_at = now()
    WHERE id = v_invite.id;
  END IF;

  SELECT * INTO v_org
  FROM public.organizations
  WHERE id = v_invite.organization_id;

  RETURN json_build_object(
    'id', v_org.id,
    'name', v_org.name,
    'slug', v_org.slug,
    'logo_url', v_org.logo_url,
    'invite_code', v_org.invite_code,
    'created_at', v_org.created_at
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.accept_org_invite_by_token(
  p_invite_token text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invite_id uuid;
BEGIN
  SELECT id INTO v_invite_id
  FROM public.organization_invites
  WHERE invite_token = p_invite_token;

  IF v_invite_id IS NULL THEN
    RAISE EXCEPTION 'INVALID_INVITE_TOKEN';
  END IF;

  RETURN public._accept_org_invite(v_invite_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.accept_org_invite_by_code(
  p_invite_code text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invite_id uuid;
BEGIN
  SELECT id INTO v_invite_id
  FROM public.organization_invites
  WHERE invite_code = upper(trim(p_invite_code));

  IF v_invite_id IS NULL THEN
    RAISE EXCEPTION 'INVALID_INVITE_CODE';
  END IF;

  RETURN public._accept_org_invite(v_invite_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.claim_pending_org_invites()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id uuid;
  v_caller_email text;
  v_invite record;
  v_result jsonb := '[]'::jsonb;
BEGIN
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT email INTO v_caller_email
  FROM public.profiles
  WHERE id = v_caller_id;

  IF v_caller_email IS NULL OR trim(v_caller_email) = '' THEN
    RETURN v_result;
  END IF;

  UPDATE public.organization_invites
  SET status = 'expired',
      updated_at = now()
  WHERE status = 'pending'
    AND lower(email) = lower(v_caller_email)
    AND expires_at < now();

  FOR v_invite IN
    SELECT id
    FROM public.organization_invites
    WHERE status = 'pending'
      AND lower(email) = lower(v_caller_email)
      AND expires_at >= now()
    ORDER BY created_at DESC
  LOOP
    v_result := v_result || jsonb_build_array(public._accept_org_invite(v_invite.id)::jsonb);
  END LOOP;

  RETURN v_result;
END;
$$;
