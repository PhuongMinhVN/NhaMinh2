-- FIX: Drop overloaded functions to resolve "Multiple Choices" error (PGRST203)
DROP FUNCTION IF EXISTS public.approve_clan_join_request(bigint);


-- Recreate function with BIGINT signature (Assuming clan_join_requests.id is BIGINT/SERIAL)
CREATE OR REPLACE FUNCTION approve_clan_join_request(request_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  req RECORD;
  new_member_id BIGINT;
  rel_member RECORD;
  rel_father_id BIGINT;
  rel_mother_id BIGINT;
  intermediate_parent_id BIGINT;
  is_male_grandparent BOOLEAN;
BEGIN
  -- 1. Fetch Request
  SELECT * INTO req FROM clan_join_requests WHERE id = request_id;
  
  IF req IS NULL THEN
    RAISE EXCEPTION 'Request not found';
  END IF;

  IF req.status != 'pending' THEN
    RAISE EXCEPTION 'Request is already processed';
  END IF;

  -- 2. Handle Claim Existing
  IF req.type = 'claim_existing' THEN
      UPDATE family_members
      SET profile_id = req.requester_id
      WHERE id = (req.metadata->>'member_id')::BIGINT;
      
      UPDATE clan_join_requests SET status = 'approved' WHERE id = request_id;
      RETURN;
  END IF;

  -- 3. Handle Create New
  IF req.type = 'create_new' THEN
      SELECT * INTO rel_member FROM family_members WHERE id = (req.metadata->>'relative_id')::BIGINT;
      
      IF rel_member IS NULL THEN
          RAISE EXCEPTION 'Relative member not found';
      END IF;

      -- Logic by Relation Type
      IF req.metadata->>'relation' = 'sibling' THEN
          rel_father_id := rel_member.father_id;
          rel_mother_id := rel_member.mother_id;
      
      ELSIF req.metadata->>'relation' = 'grandchild' THEN
           is_male_grandparent := (rel_member.gender = 'male');
           
           INSERT INTO family_members (
             full_name,gender,clan_id,generation_level,father_id,mother_id,is_alive,is_male_lineage 
           ) VALUES (
             'Con của ' || rel_member.full_name, 'male', rel_member.clan_id,
             COALESCE(rel_member.generation_level, 0) + 1,
             CASE WHEN is_male_grandparent THEN rel_member.id ELSE NULL END,
             CASE WHEN NOT is_male_grandparent THEN rel_member.id ELSE NULL END, 
             false, true
           ) RETURNING id INTO intermediate_parent_id;
           
           rel_father_id := intermediate_parent_id; 
      END IF;

      -- INSERT NEW MEMBER
      INSERT INTO family_members (
        full_name, gender, birth_date, clan_id, profile_id, father_id, mother_id, spouse_id, generation_level, is_male_lineage
      ) VALUES (
        req.metadata->>'full_name',
        req.metadata->>'gender',
        (req.metadata->>'birth_date')::TIMESTAMP,
        req.target_clan_id,
        req.requester_id,
        CASE 
          WHEN req.metadata->>'relation' = 'child' AND rel_member.gender = 'male' THEN rel_member.id
          WHEN req.metadata->>'relation' = 'sibling' THEN rel_father_id
          WHEN req.metadata->>'relation' = 'grandchild' THEN rel_father_id
          ELSE NULL 
        END,
        CASE 
          WHEN req.metadata->>'relation' = 'child' AND rel_member.gender = 'female' THEN rel_member.id
          WHEN req.metadata->>'relation' = 'sibling' THEN rel_mother_id
          ELSE NULL 
        END,
        CASE WHEN req.metadata->>'relation' = 'spouse' THEN rel_member.id ELSE NULL END,
        
        CASE 
           WHEN req.metadata->>'relation' = 'child' THEN COALESCE(rel_member.generation_level, 0) + 1
           WHEN req.metadata->>'relation' = 'grandchild' THEN COALESCE(rel_member.generation_level, 0) + 2
           WHEN req.metadata->>'relation' = 'sibling' OR req.metadata->>'relation' = 'spouse' THEN rel_member.generation_level
           ELSE 1
        END,
        true 
      ) RETURNING id INTO new_member_id;

      IF req.metadata->>'relation' = 'spouse' THEN
          UPDATE family_members SET spouse_id = new_member_id WHERE id = rel_member.id;
      END IF;

      UPDATE clan_join_requests SET status = 'approved' WHERE id = request_id;
  END IF;
END;
$$;
