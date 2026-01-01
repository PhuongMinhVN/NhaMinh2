-- Fixed Chat Implementation V2
-- Run this in Supabase SQL Editor to update the function

-- Update the function to handle self-chat (where user_id = target_user_id)
create or replace function public.get_or_create_conversation(target_user_id uuid)
returns uuid
language plpgsql
security definer
as $$
declare
  conv_id uuid;
begin
  -- Check for existing private conversation
  -- For self-chat, we look for a private conversation with just 1 participant (or 2 same participants depending on insertion)
  -- But simpler: Just look for a conversation where I am a participant and the target is a participant.
  -- Limitation: If I chat with myself, and I chat with B, both are private.
  -- My self-chat has participants {Me}.
  -- My chat with B has participants {Me, B}.
  
  -- Logic: Find a private conversation where the set of participants is EXACTLY {Me, Target}.
  -- This is tricky in SQL.
  
  -- Simplified Logic:
  -- Find a conversation `c` where:
  --   c.type = 'private'
  --   AND exist participant Me
  --   AND exist participant Target
  --   AND (participant_count = 1 IF Me=Target, ELSE 2)
  
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

  -- Create new conversation
  insert into public.chat_conversations (type)
  values ('private')
  returning id into conv_id;

  -- Insert participants safely
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
