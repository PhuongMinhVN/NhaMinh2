-- ENABLE REALTIME FOR CHAT
-- By default, new tables might not be added to the realtime publication.
-- We must explicitly add them to the 'supabase_realtime' publication to make .stream() work in Flutter.

-- 1. Add chat_messages and chat_conversations to publication
alter publication supabase_realtime add table public.chat_messages;
alter publication supabase_realtime add table public.chat_conversations;

-- 2. Verify Replica Identity (Required for updates/deletes to work correctly in streams)
-- Default is usually fine (uses Primary Key), but good to ensure.
alter table public.chat_messages replica identity full;

-- 3. Reload schema cache just in case
NOTIFY pgrst, 'reload schema';
