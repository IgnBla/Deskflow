-- Allow organization members to read profiles of their co-members.
-- Without this policy, the admin user management screen shows "Без имени"
-- because RLS on profiles only allows reading own profile (auth.uid() = id).
--
-- This adds a SELECT policy: if the target profile's user (profiles.id) shares
-- at least one organization with the authenticated user, reading is allowed.

CREATE POLICY "Members can read org co-member profiles"
ON profiles FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM organization_members AS my
    JOIN organization_members AS their
      ON my.organization_id = their.organization_id
    WHERE my.user_id = (SELECT auth.uid())
      AND their.user_id = profiles.id
  )
);
