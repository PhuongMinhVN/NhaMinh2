-- 1. ENABLE REALTIME FOR CHAT (Robustly)
DO $$
BEGIN
  -- Add chat_messages if not exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'chat_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
  END IF;

  -- Add chat_conversations if not exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'chat_conversations'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE chat_conversations;
  END IF;

    -- Add chat_participants if not exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'chat_participants'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE chat_participants;
  END IF;
END $$;

-- Set Replica Identity to FULL (Safe to run multiple times)
ALTER TABLE chat_messages REPLICA IDENTITY FULL;
ALTER TABLE chat_conversations REPLICA IDENTITY FULL;

-- 2. UPDATE APPROVE_CLAN_JOIN_REQUEST to handle Title and Name changes
CREATE OR REPLACE FUNCTION approve_clan_join_request(request_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_req record;
    v_new_member_id bigint;
    v_parent_gender text;
    v_parent_id bigint;
    v_custom_title text;
    v_custom_name text;
BEGIN
    SELECT * INTO v_req FROM clan_join_requests WHERE id = request_id;
    
    IF v_req.status <> 'pending' THEN
        RAISE EXCEPTION 'Request is handled';
    END IF;

    -- Extract Custom Name/Title from Metadata
    v_custom_name := v_req.metadata->>'full_name';
    v_custom_title := v_req.metadata->>'title';

    -- Update Request Status
    UPDATE clan_join_requests SET status = 'approved' WHERE id = request_id;

    IF v_req.request_type = 'claim_existing' THEN
        -- Link Profile to Member
        -- Also update Name/Title if provided
        UPDATE family_members 
        SET 
            profile_id = v_req.user_id,
            full_name = COALESCE(v_custom_name, full_name),
            title = COALESCE(v_custom_title, title)
        WHERE id = (v_req.metadata->>'member_id')::bigint;
    ELSE
        -- Create New Member
        INSERT INTO family_members (clan_id, full_name, gender, birth_date, is_alive, profile_id, title)
        VALUES (
            v_req.clan_id,
            v_custom_name,
            v_req.metadata->>'gender',
            (v_req.metadata->>'birth_date')::date,
            true, -- Assume alive
            v_req.user_id,
            v_custom_title -- Insert Title
        ) RETURNING id INTO v_new_member_id;
        
        -- Prepare Parent ID
        v_parent_id := v_req.target_parent_id;
        
        -- If No Existing Parent Selected, Check for "Create New Parent" Request
        IF v_parent_id IS NULL AND (v_req.metadata->>'new_parent_name') IS NOT NULL THEN
                INSERT INTO family_members (clan_id, full_name, gender, is_alive, title)
                VALUES (
                    v_req.clan_id,
                    v_req.metadata->>'new_parent_name',
                    COALESCE(v_req.metadata->>'new_parent_gender', 'male'),
                    false, -- Assume ancestor is deceased/older generation
                    CASE WHEN (v_req.metadata->>'new_parent_gender') = 'female' THEN 'Bà' ELSE 'Ông' END
                ) RETURNING id INTO v_parent_id;
        END IF;

        -- Handle Parent Linking if provided (Existing or Newly Created)
        IF v_parent_id IS NOT NULL THEN
            SELECT gender INTO v_parent_gender FROM family_members WHERE id = v_parent_id;
            
            IF v_parent_gender = 'male' THEN
                UPDATE family_members SET father_id = v_parent_id WHERE id = v_new_member_id;
            ELSE
                UPDATE family_members SET mother_id = v_parent_id WHERE id = v_new_member_id;
            END IF;
            
        -- Deprecated fallback to JSON metadata logic
        ELSIF v_req.metadata->>'relative_id' IS NOT NULL THEN
            IF (v_req.metadata->>'relation') = 'child' THEN
                    SELECT gender INTO v_parent_gender FROM family_members WHERE id = (v_req.metadata->>'relative_id')::bigint;
                    IF v_parent_gender = 'male' THEN
                    UPDATE family_members SET father_id = (v_req.metadata->>'relative_id')::bigint WHERE id = v_new_member_id;
                    ELSE
                    UPDATE family_members SET mother_id = (v_req.metadata->>'relative_id')::bigint WHERE id = v_new_member_id;
                    END IF;
            ELSIF (v_req.metadata->>'relation') = 'spouse' THEN
                    UPDATE family_members SET spouse_id = (v_req.metadata->>'relative_id')::bigint WHERE id = v_new_member_id;
            END IF;
        END IF;

    END IF;
END;
$$;

NOTIFY pgrst, 'reload schema';
