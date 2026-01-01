-- FIX CHAT MESSAGES CONSTRAINT
-- The 'receiver_id' column is from the old design and is set to NOT NULL.
-- Since we moved to 'conversation_id', we need to make 'receiver_id' optional (nullable) 
-- so we can insert messages without it.

ALTER TABLE public.chat_messages ALTER COLUMN receiver_id DROP NOT NULL;

-- Also force cache reload again just in case
NOTIFY pgrst, 'reload schema';
