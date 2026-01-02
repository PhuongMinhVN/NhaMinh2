-- Resolves PGRST203 (Ambiguous Function) by unifying signatures
-- Dropping both potential variants
DROP FUNCTION IF EXISTS public.approve_clan_join_request(bigint);
DROP FUNCTION IF EXISTS public.approve_clan_join_request(uuid);
DROP FUNCTION IF EXISTS public.approve_clan_join_request(text);

-- Create Unified Function accepting TEXT (Safe for both UUID and BigInt IDs)
CREATE OR REPLACE FUNCTION approve_clan_join_request(request_id TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_req record;
    v_new_member_id bigint;
    v_parent_id bigint;
    v_parent_gender text;
    v_custom_title text;
    v_custom_name text;
BEGIN
    -- 1. Fetch Request (Using Cast to TEXT for ID compatibility)
    SELECT * INTO v_req FROM clan_join_requests WHERE id::text = request_id;
    
    IF v_req IS NULL THEN
        RAISE EXCEPTION 'Request not found';
    END IF;

    IF v_req.status <> 'pending' THEN
        RAISE EXCEPTION 'Request is already processed';
    END IF;

    -- Extract Custom Name/Title from Metadata
    v_custom_name := v_req.metadata->>'full_name';
    v_custom_title := v_req.metadata->>'title';

    -- Update Request Status
    UPDATE clan_join_requests SET status = 'approved' WHERE id::text = request_id;

    -- FIX: Use 'type' column instead of 'request_type' based on schema confirmation
    IF v_req.type = 'claim_existing' THEN
        -- Link Profile to Member
        UPDATE family_members 
        SET 
            profile_id = v_req.requester_id, -- Use requester_id (UUID)
            full_name = COALESCE(v_custom_name, full_name),
            title = COALESCE(v_custom_title, title)
        WHERE id = (v_req.metadata->>'member_id')::bigint;
    ELSE
        -- Create New Member
        INSERT INTO family_members (clan_id, full_name, gender, birth_date, is_alive, profile_id, title)
        VALUES (
            v_req.target_clan_id, -- metadata key? Or column? Usually column target_clan_id
            v_custom_name,
            v_req.metadata->>'gender',
            (v_req.metadata->>'birth_date')::date,
            true, 
            v_req.requester_id,
            v_custom_title
        ) RETURNING id INTO v_new_member_id;
        
        -- Prepare Parent ID
        -- Logic: Prefer 'target_parent_id' column if exists, else metadata
        -- BUT: v_req is strict record. We need to check if column exists? 
        -- Standard record access: v_req.target_parent_id
        -- We assume the column exists as per 'update_join_request_schema.sql'
        
        -- Safe check if field is null
        v_parent_id := v_req.target_parent_id;

        -- If No Existing Parent Selected, Check for "Create New Parent" Request
        IF v_parent_id IS NULL AND (v_req.metadata->>'new_parent_name') IS NOT NULL THEN
             INSERT INTO family_members (clan_id, full_name, gender, is_alive, title)
             VALUES (
                 v_req.target_clan_id,
                 v_req.metadata->>'new_parent_name',
                 COALESCE(v_req.metadata->>'new_parent_gender', 'male'),
                 false, 
                 CASE WHEN (v_req.metadata->>'new_parent_gender') = 'female' THEN 'Bà' ELSE 'Ông' END
             ) RETURNING id INTO v_parent_id;
        END IF;

        -- Link to Parent
        IF v_parent_id IS NOT NULL THEN
            SELECT gender INTO v_parent_gender FROM family_members WHERE id = v_parent_id;
            
            IF v_parent_gender = 'male' THEN
                UPDATE family_members SET father_id = v_parent_id WHERE id = v_new_member_id;
            ELSE
                UPDATE family_members SET mother_id = v_parent_id WHERE id = v_new_member_id;
            END IF;
            
        -- Deprecated fallback (relative_id)
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
