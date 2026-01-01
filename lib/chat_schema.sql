-- Enable UUID extension if not enabled (usually enabled by default in Supabase)
-- create extension if not exists "uuid-ossp";

-- 1. Create Conversations Table
create table if not exists public.chat_conversations (
  id uuid default gen_random_uuid() primary key,
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null,
  type text default 'private' check (type in ('private', 'group')),
  last_message_at timestamptz default now()
);

-- 2. Create Conversation Participants Table
-- This links auth.users to conversations
create table if not exists public.chat_participants (
  conversation_id uuid references public.chat_conversations(id) on delete cascade not null,
  user_id uuid references auth.users(id) on delete cascade not null,
  joined_at timestamptz default now() not null,
  primary key (conversation_id, user_id)
);

-- 3. Create Messages Table
create table if not exists public.chat_messages (
  id uuid default gen_random_uuid() primary key,
  conversation_id uuid references public.chat_conversations(id) on delete cascade not null,
  sender_id uuid references auth.users(id) on delete set null not null,
  content text not null check (char_length(content) > 0),
  created_at timestamptz default now() not null,
  is_read boolean default false
);

-- Indexes for performance
create index if not exists idx_chat_participants_user on public.chat_participants(user_id);
create index if not exists idx_chat_messages_conversation on public.chat_messages(conversation_id);
create index if not exists idx_chat_messages_created_at on public.chat_messages(created_at desc);

-- 4. Row Level Security (RLS)

-- Enable RLS
alter table public.chat_conversations enable row level security;
alter table public.chat_participants enable row level security;
alter table public.chat_messages enable row level security;

-- Policies for chat_conversations
-- User can view conversations they are participating in
create policy "Users can view their conversations"
  on public.chat_conversations for select
  using (
    exists (
      select 1 from public.chat_participants
      where conversation_id = chat_conversations.id
      and user_id = auth.uid()
    )
  );

-- Users can insert conversations (usually done via backend function or trigger, but for direct access:)
-- We'll allow creation, but validity depends on participants
create policy "Users can create conversations"
  on public.chat_conversations for insert
  with check (true);

-- Policies for chat_participants
-- User can view participants of conversations they are in
create policy "Users can view participants of their conversations"
  on public.chat_participants for select
  using (
    exists (
      select 1 from public.chat_participants as cp
      where cp.conversation_id = chat_participants.conversation_id
      and cp.user_id = auth.uid()
    )
  );

-- User can insert themselves or others into a conversation they created?
-- Simplified: User can insert participants if they are part of the conversation OR creating a new one.
-- Effectively, we just check if the user is authenticated for now, simpler validation logic in app or trigger is better.
-- But strictly:
create policy "Users can insert participants"
  on public.chat_participants for insert
  with check (auth.uid() = user_id or exists (
      select 1 from public.chat_participants as cp
      where cp.conversation_id = chat_participants.conversation_id
      and cp.user_id = auth.uid()
  ));

-- Policies for chat_messages
-- User can view messages of conversations they are in
create policy "Users can view messages in their conversations"
  on public.chat_messages for select
  using (
    exists (
      select 1 from public.chat_participants
      where conversation_id = chat_messages.conversation_id
      and user_id = auth.uid()
    )
  );

-- User can insert messages into conversations they are in
create policy "Users can send messages to their conversations"
  on public.chat_messages for insert
  with check (
    auth.uid() = sender_id and
    exists (
      select 1 from public.chat_participants
      where conversation_id = chat_messages.conversation_id
      and user_id = auth.uid()
    )
  );

-- Trigger to update updated_at and last_message_at on new message
create or replace function public.handle_new_message()
returns trigger as $$
begin
  update public.chat_conversations
  set updated_at = now(),
      last_message_at = now()
  where id = new.conversation_id;
  return new;
end;
$$ language plpgsql security definer;

create trigger on_new_message
  after insert on public.chat_messages
  for each row execute procedure public.handle_new_message();

-- Function to get or create a private conversation
-- This helps direct "Chat with X" logic
create or replace function public.get_or_create_conversation(target_user_id uuid)
returns uuid
language plpgsql
security definer
as $$
declare
  conv_id uuid;
begin
  -- Check if a private conversation already exists between auth.uid() and target_user_id
  select c.id into conv_id
  from public.chat_conversations c
  join public.chat_participants p1 on c.id = p1.conversation_id
  join public.chat_participants p2 on c.id = p2.conversation_id
  where c.type = 'private'
    and p1.user_id = auth.uid()
    and p2.user_id = target_user_id
  limit 1;

  -- If exists, return it
  if conv_id is not null then
    return conv_id;
  end if;

  -- If not, create new conversation
  insert into public.chat_conversations (type)
  values ('private')
  returning id into conv_id;

  -- Add participants
  insert into public.chat_participants (conversation_id, user_id)
  values 
    (conv_id, auth.uid()),
    (conv_id, target_user_id);

  return conv_id;
end;
$$;
