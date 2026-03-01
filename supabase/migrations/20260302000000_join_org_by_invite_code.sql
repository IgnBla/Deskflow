-- Fix: SECURITY DEFINER function to join org by invite code
-- Bypasses RLS on organizations table so non-members can look up by invite_code
CREATE OR REPLACE FUNCTION public.join_org_by_invite_code(p_invite_code TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org RECORD;
  v_user_id UUID;
  v_existing RECORD;
BEGIN
  -- Get current user
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  -- Find org by invite code (bypasses RLS via SECURITY DEFINER)
  SELECT * INTO v_org
  FROM organizations
  WHERE invite_code = p_invite_code;

  IF v_org IS NULL THEN
    RAISE EXCEPTION 'INVALID_INVITE_CODE';
  END IF;

  -- Check if already a member
  SELECT * INTO v_existing
  FROM organization_members
  WHERE organization_id = v_org.id
    AND user_id = v_user_id;

  IF v_existing IS NOT NULL THEN
    RAISE EXCEPTION 'ALREADY_MEMBER';
  END IF;

  -- Add as member
  INSERT INTO organization_members (organization_id, user_id, role)
  VALUES (v_org.id, v_user_id, 'member');

  -- Return org data as JSON matching Organization.fromJson() fields
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
