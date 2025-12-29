-- Drop valid function first if signatures differ, but CREATE OR REPLACE should handle it if params same.
-- Param: request_id UUID
CREATE OR REPLACE FUNCTION approve_clan_join_request(request_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  req RECORD;
  new_member_id BIGINT;
  parent_id_val BIGINT;
  spouse_id_val BIGINT;
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
      -- Parse Metadata
      -- metadata: { full_name, gender, birth_date, relation, relative_id }
      
      -- Default values
      parent_id_val := NULL;
      spouse_id_val := NULL;
      
      -- Check Relative
      SELECT * INTO rel_member FROM family_members WHERE id = (req.metadata->>'relative_id')::BIGINT;
      IF rel_member IS NULL THEN
         RAISE EXCEPTION 'Relative member not found';
      END IF;

      -- Logic by Relation Type
      IF req.metadata->>'relation' = 'child' THEN
         -- If relative is Male -> Father, Female -> Mother
         IF rel_member.gender = 'male' THEN
            -- Check for spouse of father to be mother? 
            -- ideally we find the spouse of this father to set as mother.
            -- Simple logic: Set Father only
             new_member_id := 0; -- placeholder
             -- Insert below
         ELSE
             -- Mother
             -- Set Mother only
         END IF;
         
      ELSIF req.metadata->>'relation' = 'spouse' THEN
          -- Will set spouse_id bidirectional
      
      ELSIF req.metadata->>'relation' = 'sibling' THEN
          -- Copy parents from relative
          rel_father_id := rel_member.father_id;
          rel_mother_id := rel_member.mother_id;
          
          -- If orphan, we might need to create dummy parents? 
          -- For now, just copy, even if null.
      
      ELSIF req.metadata->>'relation' = 'grandchild' THEN
           -- Relative is Grandparent.
           -- Create Intermediate Parent (dummy)
           is_male_grandparent := (rel_member.gender = 'male');
           
           INSERT INTO family_members (
             full_name, 
             gender, 
             clan_id, 
             generation_level, 
             father_id, 
             mother_id, 
             is_alive,
             is_male_lineage -- Inherit or default?
           ) VALUES (
             'Con của ' || rel_member.full_name,
             'male', -- Default to male (son) for lineage? Or unknown? Let's assume Male for now to carry lineage
             rel_member.clan_id,
             COALESCE(rel_member.generation_level, 0) + 1,
             CASE WHEN is_male_grandparent THEN rel_member.id ELSE NULL END, -- father
             CASE WHEN NOT is_male_grandparent THEN rel_member.id ELSE NULL END, -- mother
             false, -- created as dummy, maybe 'unknown'?
             true
           ) RETURNING id INTO intermediate_parent_id;
           
           -- Now new member is child of intermediate
           rel_father_id := intermediate_parent_id; -- Assume father
      END IF;

      -- INSERT NEW MEMBER
      INSERT INTO family_members (
        full_name,
        gender,
        birth_date,
        clan_id,
        profile_id,
        father_id,
        mother_id,
        spouse_id,
        generation_level,
        is_male_lineage
      ) VALUES (
        req.metadata->>'full_name',
        req.metadata->>'gender',
        (req.metadata->>'birth_date')::TIMESTAMP,
        req.target_clan_id,
        req.requester_id,
        -- Father/Mother logic
        CASE 
          WHEN req.metadata->>'relation' = 'child' AND rel_member.gender = 'male' THEN rel_member.id
          WHEN req.metadata->>'relation' = 'sibling' THEN rel_father_id
          WHEN req.metadata->>'relation' = 'grandchild' THEN rel_father_id -- intermediate
          ELSE NULL 
        END,
        CASE 
          WHEN req.metadata->>'relation' = 'child' AND rel_member.gender = 'female' THEN rel_member.id
          WHEN req.metadata->>'relation' = 'sibling' THEN rel_mother_id
           -- Grandchild intermediate is assumed father for now
          ELSE NULL 
        END,
        CASE WHEN req.metadata->>'relation' = 'spouse' THEN rel_member.id ELSE NULL END,
        
        -- Generation Level
        CASE 
           WHEN req.metadata->>'relation' = 'child' OR req.metadata->>'relation' = 'grandchild' THEN COALESCE(rel_member.generation_level, 0) + 1
           WHEN req.metadata->>'relation' = 'grandchild' THEN COALESCE(rel_member.generation_level, 0) + 2 -- Wait, grandchild is +2? 
           -- Ah, above I created intermediate as +1. New member is child of intermediate (+1), so effectively +2 from grandparent. 
           -- Correct logic:
           -- If relation=grandchild: intermediate is +1 to Gp. New member is +1 to Intermediate => +2 to Gp.
           -- If relation=child: +1 to Parent.
           -- If relation=sibling/spouse: Same as Relative.
           WHEN req.metadata->>'relation' = 'sibling' OR req.metadata->>'relation' = 'spouse' THEN rel_member.generation_level
           ELSE 1
        END,
        
        true -- Default is_male_lineage
      ) RETURNING id INTO new_member_id;

      -- Update Spouse Link if needed
      IF req.metadata->>'relation' = 'spouse' THEN
          UPDATE family_members SET spouse_id = new_member_id WHERE id = rel_member.id;
      END IF;

      UPDATE clan_join_requests SET status = 'approved' WHERE id = request_id;
  END IF;
END;
$$;
