-- FIX MISSING MEMBER ISSUE (RLS & Column Ambiguity)

-- 1. Ensure 'generation_level' exists (Standardizing on this name)
alter table public.family_members add column if not exists generation_level int default 1;

-- 2. Sync data from 'generation_number' if it exists and 'generation_level' is null
do $$ 
begin
  if exists (select 1 from information_schema.columns where table_name='family_members' and column_name='generation_number') then
      update public.family_members
      set generation_level = generation_number
      where generation_level is null and generation_number is not null;
  end if;
end $$;

-- 3. Fix RLS: Ensure Owners can ALWAYS view/edit their clan members
drop policy if exists "Owners can manage members" on public.family_members;
drop policy if exists "Owners can view all members" on public.family_members;
drop policy if exists "Owners can update members" on public.family_members;
drop policy if exists "Owners can insert members" on public.family_members;
drop policy if exists "Owners can delete members" on public.family_members;

create policy "Owners can view all members"
  on public.family_members for select
  using (
    exists (
      select 1 from public.clans
      where clans.id = family_members.clan_id
      and clans.owner_id = auth.uid()
    )
  );

create policy "Owners can update members"
  on public.family_members for update
  using (
    exists (
      select 1 from public.clans
      where clans.id = family_members.clan_id
      and clans.owner_id = auth.uid()
    )
  );

create policy "Owners can insert members"
  on public.family_members for insert
  with check (
    exists (
      select 1 from public.clans
      where clans.id = family_members.clan_id
      and clans.owner_id = auth.uid()
    )
  );

create policy "Owners can delete members"
  on public.family_members for delete
  using (
    exists (
      select 1 from public.clans
      where clans.id = family_members.clan_id
      and clans.owner_id = auth.uid()
    )
  );

-- 4. Ensure "Users can see themselves" (Redundant but safe)
drop policy if exists "Individuals can view their own record" on public.family_members;
create policy "Individuals can view their own record"
  on public.family_members for select
  using (
    profile_id = auth.uid()
  );

-- 5. Helper function for "Users can view members of their clans" (Recursive check fix)
create or replace function public.is_clan_member_safe(_clan_id uuid)
returns boolean
language plpgsql
security definer -- BYPASS RLS to avoid recursion
as $$
begin
  return exists (
    select 1 from public.family_members
    where clan_id = _clan_id
    and profile_id = auth.uid()
  );
end;
$$;

drop policy if exists "Users can view members of their clans" on public.family_members;
create policy "Users can view members of their clans"
  on public.family_members for select
  using (
    public.is_clan_member_safe(clan_id)
  );

-- 6. Trigger to auto-fill search vectors or defaults (Optional cleanup)
-- Ensure is_alive defaults to true
alter table public.family_members alter column is_alive set default true;
