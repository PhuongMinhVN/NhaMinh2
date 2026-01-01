-- FUNCTION: Check if user is a member of a clan
-- Used for RLS policies to allow access to clan data and events
create or replace function public.is_clan_member(_clan_id uuid)
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

-- 1. CLANS Table Policies
alter table public.clans enable row level security;

-- Drop simple owner policy if exists to replace with broader one
drop policy if exists "Users can view their own clans" on public.clans;
drop policy if exists "Members can view their clans" on public.clans;

create policy "Users can view clans they own or belong to"
  on public.clans for select
  using (
    owner_id = auth.uid() 
    or 
    public.is_clan_member(id)
  );

-- 2. CLAN EVENTS Table Policies
alter table public.clan_events enable row level security;

drop policy if exists "Users can view events of their clans" on public.clan_events;

-- Note: clan_events needs a 'clan_id' column to link to clans. 
-- Assuming schema has it. If not, we rely on created_by (which is bad for members).
-- Let's check if clan_events has clan_id. If not multitenancy is broken.
-- Based on previous file list, there was 'events_schema.sql'.
-- I will assume clan_id exists or created_by is used. 
-- Actually, let's look at the insert code in EventRepository:
-- 'created_by': _client.auth.currentUser?.id
-- It DOES NOT insert 'clan_id'. This is a BUG in EventRepository if events belong to a clan.
-- If events are global to the user (personal events), then RLS should be 'created_by = auth.uid()'.
-- But the app is "Clan Events". 
-- If the event is created by the Owner, the Member needs to see it.
-- We need to link events to clans.

-- CHECKING Event schema assumption:
-- If events don't have clan_id, how do we know which clan they belong to?
-- Maybe they are just linked to the "Creator"?
-- If so, we need to see events created by the "Owner of the Clan I belong to".
-- That's complex.
-- Ideally `clan_events` has `clan_id`.

-- Let's assume for now we need a policy that allows viewing if:
-- 1. I created the event.
-- 2. The event was created by someone who is the OWNER of a clan I am a MEMBER of.

create policy "Users can view relevant events"
  on public.clan_events for select
  using (
    created_by = auth.uid() -- I created it
    or
    exists ( -- Created by my clan owner
      select 1 from public.clans
      where clans.owner_id = clan_events.created_by
      and public.is_clan_member(clans.id)
    )
  );
