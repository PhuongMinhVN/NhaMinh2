-- IMPLEMENT CLAN ROLES (Chủ Nhà, Phó Nhà)

-- 1. Add 'clan_role' column
-- Values: 'owner' (Chủ Nhà), 'admin' (Phó Nhà), 'member' (Thành viên)
alter table public.family_members add column if not exists clan_role text default 'member';

-- 2. Migrate existing Owners to 'owner' role
-- Update family_members where profile_id matches the clan's owner_id
update public.family_members
set clan_role = 'owner'
where exists (
  select 1 from public.clans
  where clans.id = family_members.clan_id
  and clans.owner_id = family_members.profile_id
);

-- 3. Update RLS for Permissions
-- Allow 'owner' and 'admin' to DELETE and UPDATE members

-- Helper function to check if user is Admin/Owner in the clan
create or replace function public.is_clan_admin(_clan_id uuid)
returns boolean
language plpgsql
security definer
as $$
begin
  return exists (
    select 1 from public.family_members
    where clan_id = _clan_id
    and profile_id = auth.uid()
    and clan_role in ('owner', 'admin')
  );
end;
$$;

-- Policy for Deleting (Owner + Admin)
drop policy if exists "Owners can delete members" on public.family_members;
create policy "Admins can delete members"
  on public.family_members for delete
  using (
    public.is_clan_admin(clan_id)
  );

-- Policy for Updating (Owner + Admin)
drop policy if exists "Owners can update members" on public.family_members;
create policy "Admins can update members"
  on public.family_members for update
  using (
    public.is_clan_admin(clan_id)
  );

-- Policy for Inserting (Owner + Admin)
drop policy if exists "Owners can insert members" on public.family_members;
create policy "Admins can insert members"
  on public.family_members for insert
  with check (
    public.is_clan_admin(clan_id)
  );
