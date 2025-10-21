-- Fix flights table RLS - Option B: Add permissive SELECT policy
-- This keeps RLS enabled but allows public read access

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "public_select" ON public.flights;
DROP POLICY IF EXISTS "Public flights are viewable by everyone." ON public.flights;

-- Add explicit permissive SELECT policy
CREATE POLICY "public_select" ON public.flights 
FOR SELECT 
TO PUBLIC 
USING (true);

-- Verify the policy was created correctly
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE schemaname = 'public' 
    AND tablename = 'flights'
ORDER BY policyname;

-- Test that public read works
SELECT 'flights RLS fix completed - testing public read access' as status;
SELECT COUNT(*) as flight_count FROM public.flights;
