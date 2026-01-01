-- COMPREHENSIVE FIX SCRIPT V4
-- (Includes DROP statements to prevent errors)

-- 1. Fix Foreign Keys (Cascade Delete)
ALTER TABLE public.clan_join_requests DROP CONSTRAINT IF EXISTS clan_join_requests_target_clan_id_fkey;
ALTER TABLE public.clan_join_requests DROP CONSTRAINT IF EXISTS clan_join_requests_target_parent_id_fkey;
ALTER TABLE public.family_members DROP CONSTRAINT IF EXISTS family_members_clan_id_fkey;

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

-- 2. Fix Event Visibility (RLS)
ALTER TABLE public.clan_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "View Events" ON public.clan_events;
DROP POLICY IF EXISTS "Manage Events" ON public.clan_events;
DROP POLICY IF EXISTS "View Events: My Clan Events" ON public.clan_events;
DROP POLICY IF EXISTS "Manage Events: Creator" ON public.clan_events;

CREATE POLICY "View Events" ON public.clan_events FOR SELECT USING (
  created_by = auth.uid() 
  OR 
  EXISTS (
    SELECT 1 FROM public.clans 
    JOIN public.family_members ON clans.id = family_members.clan_id
    WHERE clans.owner_id = clan_events.created_by
    AND family_members.profile_id = auth.uid()
  )
);

CREATE POLICY "Manage Events" ON public.clan_events FOR ALL USING (
  created_by = auth.uid()
);

-- 3. Fix Join Request Permissions
ALTER TABLE public.clan_join_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "View Requests" ON public.clan_join_requests;
DROP POLICY IF EXISTS "Manage Requests" ON public.clan_join_requests;
DROP POLICY IF EXISTS "Create Requests" ON public.clan_join_requests; -- ADDED THIS DROP

CREATE POLICY "View Requests" ON public.clan_join_requests FOR SELECT USING (
  requester_id = auth.uid()
  OR
  EXISTS (
    SELECT 1 FROM public.clans
    WHERE clans.id = clan_join_requests.target_clan_id
    AND clans.owner_id = auth.uid()
  )
);

CREATE POLICY "Manage Requests" ON public.clan_join_requests FOR ALL USING (
  requester_id = auth.uid()
  OR
  EXISTS (
    SELECT 1 FROM public.clans
    WHERE clans.id = clan_join_requests.target_clan_id
    AND clans.owner_id = auth.uid()
  )
);

CREATE POLICY "Create Requests" ON public.clan_join_requests FOR INSERT WITH CHECK (auth.role() = 'authenticated');
