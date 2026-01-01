-- Fix for family_members RLS
-- Users need to see their own member records to know which clans they joined.
-- They also need to see other members in the same clan to view the tree.

alter table public.family_members enable row level security;

-- 1. Helper function (reused/ensured)
-- This checks if the current user is a member of the given clan_id
create or replace function public.is_member_of_clan(_clan_id uuid)
returns boolean
language plpgsql
security definer
as $$
begin
  return exists (
    select 1 from public.family_members
    where clan_id = _clan_id
    and profile_id = auth.uid()
  );
end;
$$;

-- 2. Drop restrictive policies
drop policy if exists "Users can view members of their clans" on public.family_members;
drop policy if exists "Individuals can view their own record" on public.family_members;

-- 3. Create permissive policies for visibility

-- Policy A: You can see ANY record in a clan that you are a member of.
-- This allows seeing all your relatives.
create policy "Users can view members of their clans"
  on public.family_members for select
  using (
    public.is_member_of_clan(clan_id)
  );

-- Policy B: You can see your OWN record (e.g. to find out which clans you are in)
-- This is critical for the 'joinedRes' query in ClanListPage
create policy "Individuals can view their own record"
  on public.family_members for select
  using (
    profile_id = auth.uid()
  );

-- 4. Grant access to 'clans' table via join
-- (Previously fixed in fix_visibility_policies.sql, but ensuring here)
-- public.is_clan_member(id) was used there. It's similar to is_member_of_clan.
-- We'll just stick to the previous fix for 'clans' table, assuming it was run.

-- 5. Fix for creating/editing members
-- Owners need full access.
-- We need to know who owns the clan to allow insert/update/delete.
-- This requires joining 'clans' table.

create or replace function public.is_clan_owner(_clan_id uuid)
returns boolean
language plpgsql
security definer
as $$
begin
  return exists (
    select 1 from public.clans
    where id = _clan_id
    and owner_id = auth.uid()
  );
end;
$$;

create policy "Owners can manage members"
  on public.family_members for all
  using (
    public.is_clan_owner(clan_id)
  );
  
-- Allow users to update THEIR OWN record (e.g. profile-sync)?
-- Maybe restricted to specific fields, but for now allow update.
create policy "Users can update their own record"
  on public.family_members for update
  using (
    profile_id = auth.uid()
  );
