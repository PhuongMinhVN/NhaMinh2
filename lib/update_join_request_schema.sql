-- Add target_parent_id to clan_join_requests for linking parent/child relationships
ALTER TABLE clan_join_requests 
ADD COLUMN IF NOT EXISTS target_parent_id bigint REFERENCES family_members(id);

-- Update the approve_clan_join_request function to handle this new field
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
BEGIN
    SELECT * INTO v_req FROM clan_join_requests WHERE id = request_id;
    
        IF v_req.status <> 'pending' THEN
            RAISE EXCEPTION 'Request is handled';
        END IF;
    
        -- Update Request Status
        UPDATE clan_join_requests SET status = 'approved' WHERE id = request_id;
    
        IF v_req.request_type = 'claim_existing' THEN
            -- Link Profile to Member
            UPDATE family_members 
            SET profile_id = v_req.user_id 
            WHERE id = (v_req.metadata->>'member_id')::bigint;
        ELSE
            -- Create New Member
            INSERT INTO family_members (clan_id, full_name, gender, birth_date, is_alive, profile_id)
            VALUES (
                v_req.clan_id,
                v_req.metadata->>'full_name',
                v_req.metadata->>'gender',
                (v_req.metadata->>'birth_date')::date,
                true, -- Assume alive
                v_req.user_id
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
                
            -- Deprecated fallback to JSON metadata logic (for old requests)
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
