-- Add ON DELETE CASCADE to clan_join_requests constraints to prevent deletion errors

-- 1. Drop existing constraints
ALTER TABLE public.clan_join_requests DROP CONSTRAINT IF EXISTS clan_join_requests_target_clan_id_fkey;
ALTER TABLE public.clan_join_requests DROP CONSTRAINT IF EXISTS clan_join_requests_target_parent_id_fkey;

-- 2. Re-add constraints with CASCADE
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

-- 3. Also ensure family_members cascade when clan is deleted (creates cleaner deletion flow)
ALTER TABLE public.family_members DROP CONSTRAINT IF EXISTS family_members_clan_id_fkey;

ALTER TABLE public.family_members
ADD CONSTRAINT family_members_clan_id_fkey
FOREIGN KEY (clan_id)
REFERENCES public.clans(id)
ON DELETE CASCADE;
