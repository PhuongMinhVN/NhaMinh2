-- FORCE FIX CHAT SCHEMA
-- Run this in Supabase SQL Editor

-- 1. Add missing columns if they don't exist
alter table public.chat_messages 
add column if not exists conversation_id uuid references public.chat_conversations(id) on delete cascade;

-- If we are switching from receiver_id to conversation_id, we might need to make receiver_id nullable or drop it?
-- For now, let's just make sure conversation_id exists.

-- 2. Ensure Conversations table exists
create table if not exists public.chat_conversations (
  id uuid default gen_random_uuid() primary key,
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null,
  type text default 'private' check (type in ('private', 'group')),
  last_message_at timestamptz default now()
);

-- 3. Ensure Participants table exists
create table if not exists public.chat_participants (
  conversation_id uuid references public.chat_conversations(id) on delete cascade not null,
  user_id uuid references auth.users(id) on delete cascade not null,
  joined_at timestamptz default now() not null,
  primary key (conversation_id, user_id)
);

-- 4. Re-run the function definition (it relies on these tables)
create or replace function public.get_or_create_conversation(target_user_id uuid)
returns uuid
language plpgsql
security definer
as $$
declare
  conv_id uuid;
begin
  -- Search for existing private conversation
  select c.id into conv_id
  from public.chat_conversations c
  join public.chat_participants p on c.id = p.conversation_id
  where c.type = 'private'
  group by c.id
  having 
      count(*) = (case when auth.uid() = target_user_id then 1 else 2 end)
      and bool_or(p.user_id = auth.uid()) 
      and bool_or(p.user_id = target_user_id)
  limit 1;

  if conv_id is not null then
    return conv_id;
  end if;

  -- Create new
  insert into public.chat_conversations (type)
  values ('private')
  returning id into conv_id;

  -- Insert participants
  if auth.uid() = target_user_id then
      insert into public.chat_participants (conversation_id, user_id)
      values (conv_id, auth.uid());
  else
      insert into public.chat_participants (conversation_id, user_id)
      values 
        (conv_id, auth.uid()),
        (conv_id, target_user_id);
  end if;

  return conv_id;
end;
$$;
