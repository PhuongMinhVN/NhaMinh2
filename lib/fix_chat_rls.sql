-- 1. Create a SECURITY DEFINER function to check membership
-- This bypasses RLS to avoid infinite recursion when querying chat_participants
create or replace function public.is_chat_member(conversation_id uuid)
returns boolean
language plpgsql
security definer
as $$
begin
  return exists (
    select 1 from public.chat_participants
    where conversation_id = $1
    and user_id = auth.uid()
  );
end;
$$;

-- 2. Drop existing problematic policies
drop policy if exists "Users can view their conversations" on public.chat_conversations;
drop policy if exists "Users can view participants of their conversations" on public.chat_participants;
drop policy if exists "Users can view messages in their conversations" on public.chat_messages;
drop policy if exists "Users can send messages to their conversations" on public.chat_messages;

-- 3. Re-create policies using the helper function

-- chat_conversations
create policy "Users can view their conversations"
  on public.chat_conversations for select
  using (
    public.is_chat_member(id)
  );

-- chat_participants
-- Now safe to call is_chat_member because it's security definer
create policy "Users can view participants of their conversations"
  on public.chat_participants for select
  using (
    public.is_chat_member(conversation_id)
  );

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
