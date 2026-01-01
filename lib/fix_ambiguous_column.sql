-- Comprehensive Fix (Updated for Policy Conflict)

-- 1. Drop the function and all dependent policies
drop function if exists public.is_chat_member(uuid) cascade;

-- 2. Explicitly drop policies that might NOT have been dependent but collide
-- (Just to be safe and avoid "policy already exists" errors)
drop policy if exists "Users can view their conversations" on public.chat_conversations;
drop policy if exists "Users can view participants of their conversations" on public.chat_participants;
drop policy if exists "Users can insert participants" on public.chat_participants;
drop policy if exists "Users can view messages in their conversations" on public.chat_messages;
drop policy if exists "Users can send messages to their conversations" on public.chat_messages;

-- 3. Recreate the function with the corrected parameter name (_conversation_id)
create or replace function public.is_chat_member(_conversation_id uuid)
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

-- 4. Re-create the policies

-- chat_conversations
create policy "Users can view their conversations"
  on public.chat_conversations for select
  using (
    public.is_chat_member(id)
  );

-- chat_participants
create policy "Users can view participants of their conversations"
  on public.chat_participants for select
  using (
    public.is_chat_member(conversation_id)
  );

create policy "Users can insert participants"
  on public.chat_participants for insert
  with check (auth.uid() = user_id or exists (
      select 1 from public.chat_participants as cp
      where cp.conversation_id = chat_participants.conversation_id
      and cp.user_id = auth.uid()
  ));

-- chat_messages
create policy "Users can view messages in their conversations"
  on public.chat_messages for select
  using (
    public.is_chat_member(conversation_id)
  );

create policy "Users can send messages to their conversations"
  on public.chat_messages for insert
  with check (
    auth.uid() = sender_id and
    public.is_chat_member(conversation_id)
  );
