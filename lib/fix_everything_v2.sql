-- COMPREHENSIVE FIX SCRIPT
-- 1. Fix Foreign Key Constraints (Enable Cascade Delete)
-- 2. Enable RLS and Policies for Join Requests
-- 3. Fix Missing Clan Types

-- ==========================================
-- 1. FIX CONSTRAINTS (CASCADE DELETE)
-- ==========================================

-- Drop existing constraints
ALTER TABLE public.clan_join_requests DROP CONSTRAINT IF EXISTS clan_join_requests_target_clan_id_fkey;
ALTER TABLE public.clan_join_requests DROP CONSTRAINT IF EXISTS clan_join_requests_target_parent_id_fkey;
ALTER TABLE public.family_members DROP CONSTRAINT IF EXISTS family_members_clan_id_fkey;

-- Re-add with CASCADE
ALTER TABLE public.clan_join_requests
ADD CONSTRAINT clan_join_requests_target_clan_id_fkey
FOREIGN KEY (target_clan_id)
REFERENCES public.clans(id)
ON DELETE CASCADE;

ALTER TABLE public.clan_join_requests
ADD CONSTRAINT clan_join_requests_target_parent_id_fkey
FOREIGN KEY (target_parent_id)
REFERENCES public.family_members(id)
ON DELETE CASCADE;

ALTER TABLE public.family_members
ADD CONSTRAINT family_members_clan_id_fkey
FOREIGN KEY (clan_id)
REFERENCES public.clans(id)
ON DELETE CASCADE;

-- ==========================================
-- 2. RLS FOR JOIN REQUESTS
-- ==========================================

ALTER TABLE public.clan_join_requests ENABLE ROW LEVEL SECURITY;

-- Drop old policies if any
DROP POLICY IF EXISTS "View Requests" ON public.clan_join_requests;
DROP POLICY IF EXISTS "Manage Requests" ON public.clan_join_requests;
DROP POLICY IF EXISTS "Create Requests" ON public.clan_join_requests;

-- Policy: View (Requester OR Target Clan Owner)
CREATE POLICY "View Requests"
ON public.clan_join_requests FOR SELECT
USING (
  requester_id = auth.uid()
  OR
  EXISTS (
    SELECT 1 FROM public.clans
    WHERE clans.id = clan_join_requests.target_clan_id
    AND clans.owner_id = auth.uid()
  )
);

-- Policy: Insert (Anyone authenticated)
CREATE POLICY "Create Requests"
ON public.clan_join_requests FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

-- Policy: Update/Delete (Requester OR Target Clan Owner)
CREATE POLICY "Manage Requests"
ON public.clan_join_requests FOR ALL
USING (
  requester_id = auth.uid()
  OR
  EXISTS (
    SELECT 1 FROM public.clans
    WHERE clans.id = clan_join_requests.target_clan_id
    AND clans.owner_id = auth.uid()
  )
);

-- ==========================================
-- 3. FIX CLAN TYPES
-- ==========================================

UPDATE public.clans
SET type = 
  CASE 
    WHEN lower(name) LIKE '%gia đình%' THEN 'family'
    WHEN lower(name) LIKE '%nhà%' THEN 'family'
    ELSE 'clan'
  END
WHERE type IS NULL OR type = '';

ALTER TABLE public.clans ALTER COLUMN type SET DEFAULT 'clan';
