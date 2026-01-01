-- MASTER FIX: RLS & PERMISSIONS
-- This script resets and fixes all permissions for Clans, Members, Events, and Chat.
-- Run this ENTIRE script in Supabase SQL Editor.

-- ==========================================
-- 1. CLEANUP (Drop existing functions/policies)
-- ==========================================

-- Drop recursive functions (cascade drops dependent policies)
drop function if exists public.is_clan_member(uuid) cascade;
drop function if exists public.is_member_of_clan(uuid) cascade;
drop function if exists public.is_chat_member(uuid) cascade;
drop function if exists public.is_clan_owner(uuid) cascade;

-- Explicitly drop any lingering policies just in case
drop policy if exists "Users can view clans they own or belong to" on public.clans;
drop policy if exists "Users can view members of their clans" on public.family_members;
drop policy if exists "Individuals can view their own record" on public.family_members;
drop policy if exists "Owners can manage members" on public.family_members;
drop policy if exists "Users can update their own record" on public.family_members;
drop policy if exists "Users can view relevant events" on public.clan_events;

-- ==========================================
-- 2. HELPER FUNCTIONS (Security Definer)
-- ==========================================

-- Check if User is Member of Clan
create or replace function public.check_is_clan_member(_clan_id uuid)
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

-- Check if User is Owner of Clan
create or replace function public.check_is_clan_owner(_clan_id uuid)
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

-- Check if User is in Chat Conversation
create or replace function public.check_is_chat_participant(_conversation_id uuid)
returns boolean
language plpgsql
security definer
as $$
begin
  return exists (
    select 1 from public.chat_participants
    where conversation_id = _conversation_id
    and user_id = auth.uid()
  );
end;
$$;

-- ==========================================
-- 3. ENABLE RLS
-- ==========================================
alter table public.clans enable row level security;
alter table public.family_members enable row level security;
alter table public.clan_events enable row level security;
alter table public.chat_conversations enable row level security;
alter table public.chat_participants enable row level security;
alter table public.chat_messages enable row level security;

-- ==========================================
-- 4. APPLY POLICIES
-- ==========================================

-- --- CLANS ---
create policy "View Clans: Owner or Member"
  on public.clans for select
  using (
    owner_id = auth.uid() 
    or 
    public.check_is_clan_member(id)
  );

create policy "Manage Clans: Owner only"
  on public.clans for all
  using (owner_id = auth.uid());

-- --- FAMILY MEMBERS ---
-- View: If I am in the clan, OR if it's my own record
create policy "View Members: Clanmates and Self"
  on public.family_members for select
  using (
    profile_id = auth.uid()
    or
    public.check_is_clan_member(clan_id)
  );

-- Modify: Owner permissions
create policy "Manage Members: Clan Owner"
  on public.family_members for all
  using (
    public.check_is_clan_owner(clan_id)
  );

-- Update Self: Allow user to update their own profile link/info
create policy "Update Self: My Record"
  on public.family_members for update
  using (profile_id = auth.uid());
  
-- --- CLAN EVENTS ---
-- View: Created by me, OR created by my clan's owner
-- (Assumption: Events created by Owner are for the Clan)
create policy "View Events: My Clan Events"
  on public.clan_events for select
  using (
    created_by = auth.uid()
    or
    exists (
      select 1 from public.clans
      where clans.owner_id = clan_events.created_by
      and public.check_is_clan_member(clans.id)
    )
  );

create policy "Manage Events: Creator"
  on public.clan_events for all
  using (created_by = auth.uid());

-- --- CHAT ---
-- Conversations
create policy "View Conversations: Participant"
  on public.chat_conversations for select
  using (public.check_is_chat_participant(id));

-- Participants
create policy "View Participants: Chat Member"
  on public.chat_participants for select
  using (public.check_is_chat_participant(conversation_id));

create policy "Insert Participants: Self or Chat Member"
  on public.chat_participants for insert
  with check (
     auth.uid() = user_id -- Self join
     or 
     public.check_is_chat_participant(conversation_id) -- Adding others
  );

-- Messages
create policy "View Messages: Chat Member"
  on public.chat_messages for select
  using (public.check_is_chat_participant(conversation_id));

create policy "Send Messages: Chat Member"
  on public.chat_messages for insert
  with check (
    auth.uid() = sender_id 
    and
    public.check_is_chat_participant(conversation_id)
  );

-- ==========================================
-- 5. GRANTS (Ensure authenticated role works)
-- ==========================================
grant usage on schema public to authenticated;
grant all on all tables in schema public to authenticated;
grant all on all sequences in schema public to authenticated;
grant all on all functions in schema public to authenticated;

