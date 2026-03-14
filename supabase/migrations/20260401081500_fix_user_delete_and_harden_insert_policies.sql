-- Migration: Fix auth user deletion and remove unsafe direct insert policies

ALTER TABLE public.orders
  ALTER COLUMN created_by DROP NOT NULL;

DROP POLICY IF EXISTS "Anyone can insert org" ON public.organizations;
DROP POLICY IF EXISTS "Anyone can insert member" ON public.organization_members;
