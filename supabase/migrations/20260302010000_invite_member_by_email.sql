-- Fix: SECURITY DEFINER function to invite member by email
-- Bypasses RLS on profiles table so admin can look up users by email
-- Also verifies caller is org owner before allowing invite
CREATE OR REPLACE FUNCTION public.invite_member_by_email(
  p_org_id UUID,
  p_email TEXT,
  p_role TEXT DEFAULT 'member'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_caller_id UUID;
  v_caller_role TEXT;
  v_existing RECORD;
BEGIN
  -- 1. Verify caller is authenticated
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  -- 2. Verify caller is owner of the org
  SELECT role INTO v_caller_role
  FROM organization_members
  WHERE organization_id = p_org_id
    AND user_id = v_caller_id;

  IF v_caller_role IS NULL OR v_caller_role != 'owner' THEN
    RAISE EXCEPTION 'NOT_OWNER';
  END IF;

  -- 3. Find user by email in profiles (bypasses RLS via SECURITY DEFINER)
  SELECT id INTO v_user_id
  FROM profiles
  WHERE email = p_email;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;

  -- 4. Check if already a member
  SELECT * INTO v_existing
  FROM organization_members
  WHERE organization_id = p_org_id
    AND user_id = v_user_id;

  IF v_existing IS NOT NULL THEN
    RAISE EXCEPTION 'ALREADY_MEMBER';
  END IF;

  -- 5. Add as member with specified role
  INSERT INTO organization_members (organization_id, user_id, role)
  VALUES (p_org_id, v_user_id, p_role);
END;
$$;
