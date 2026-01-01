-- Consolidated Chat Implementation Fix
-- Run this in Supabase SQL Editor

-- 1. Ensure Tables Exist
create table if not exists public.chat_conversations (
  id uuid default gen_random_uuid() primary key,
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null,
  type text default 'private' check (type in ('private', 'group')),
  last_message_at timestamptz default now()
);

create table if not exists public.chat_participants (
  conversation_id uuid references public.chat_conversations(id) on delete cascade not null,
  user_id uuid references auth.users(id) on delete cascade not null,
  joined_at timestamptz default now() not null,
  primary key (conversation_id, user_id)
);

create table if not exists public.chat_messages (
  id uuid default gen_random_uuid() primary key,
  conversation_id uuid references public.chat_conversations(id) on delete cascade not null,
  sender_id uuid references auth.users(id) on delete set null not null,
  content text not null check (char_length(content) > 0),
  created_at timestamptz default now() not null,
  is_read boolean default false
);

-- 2. Indexes
create index if not exists idx_chat_participants_user on public.chat_participants(user_id);
create index if not exists idx_chat_participants_conv on public.chat_participants(conversation_id);
create index if not exists idx_chat_messages_conv on public.chat_messages(conversation_id);
create index if not exists idx_chat_messages_created on public.chat_messages(created_at desc);

-- 3. RLS Helper Function (Security Definer)
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

-- 4. Enable RLS and Policies
alter table public.chat_conversations enable row level security;
alter table public.chat_participants enable row level security;
alter table public.chat_messages enable row level security;

-- Drop old policies to avoid conflicts
drop policy if exists "Users can view their conversations" on public.chat_conversations;
drop policy if exists "Users can view participants of their conversations" on public.chat_participants;
drop policy if exists "Users can view messages in their conversations" on public.chat_messages;
drop policy if exists "Users can send messages to their conversations" on public.chat_messages;

-- Create new policies
create policy "Users can view their conversations"
  on public.chat_conversations for select
  using (public.is_chat_member(id));

create policy "Users can view participants of their conversations"
  on public.chat_participants for select
  using (public.is_chat_member(conversation_id));

create policy "Users can view messages in their conversations"
  on public.chat_messages for select
  using (public.is_chat_member(conversation_id));

create policy "Users can send messages to their conversations"
  on public.chat_messages for insert
  with check (
    auth.uid() = sender_id and
    public.is_chat_member(conversation_id)
  );

-- 5. Get or Create Conversation Function
create or replace function public.get_or_create_conversation(target_user_id uuid)
returns uuid
language plpgsql
security definer
as $$
declare
  conv_id uuid;
begin
  -- Check for existing private conversation
  select c.id into conv_id
  from public.chat_conversations c
  join public.chat_participants p1 on c.id = p1.conversation_id
  join public.chat_participants p2 on c.id = p2.conversation_id
  where c.type = 'private'
    and p1.user_id = auth.uid()
    and p2.user_id = target_user_id
  limit 1;

  if conv_id is not null then
    return conv_id;
  end if;

  -- Create new
  insert into public.chat_conversations (type)
  values ('private')
  returning id into conv_id;

  insert into public.chat_participants (conversation_id, user_id)
  values 
    (conv_id, auth.uid()),
    (conv_id, target_user_id);

  return conv_id;
end;
$$;
