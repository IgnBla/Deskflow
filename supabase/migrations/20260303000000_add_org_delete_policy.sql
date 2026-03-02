-- Add missing DELETE policy for organizations table.
-- Without this, Supabase PostgREST silently returns 0 rows affected
-- when an owner tries to delete their organization via the app.
-- All FK references already have ON DELETE CASCADE, so child rows
-- (members, orders, customers, products, etc.) will be cleaned up.

CREATE POLICY "Org owner can delete org"
  ON public.organizations
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1
      FROM organization_members m
      WHERE m.organization_id = organizations.id
        AND m.user_id = auth.uid()
        AND m.role = 'owner'
    )
  );
