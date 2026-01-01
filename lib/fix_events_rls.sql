-- Enable RLS on events table
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to ensure clean slate
DROP POLICY IF EXISTS "Users can view their own events" ON events;
DROP POLICY IF EXISTS "Users can view clan events" ON events;
DROP POLICY IF EXISTS "Users can insert their own events" ON events;
DROP POLICY IF EXISTS "Users can update their own events" ON events;
DROP POLICY IF EXISTS "Users can delete their own events" ON events;
DROP POLICY IF EXISTS "View visible events" ON events;

-- PROPOSED POLICY:
-- Users can see events if:
-- 1. They created it (created_by = auth.uid())
-- 2. OR It is a CLAN event (scope = 'CLAN') AND they are a member of that clan (check family_members)
-- 3. OR It is a FAMILY event (scope = 'FAMILY') AND (created_by = auth.uid()) -- For now, Family events are personal/private to creator unless we have a Family Group concept. 
--    (Assuming Family Scope is currently effectively Personal or strictly limited)

CREATE POLICY "View visible events" ON events
FOR SELECT
USING (
  created_by = auth.uid() 
  OR 
  (
    scope = 'CLAN' 
    AND 
    clan_id IN (
      SELECT clan_id FROM family_members WHERE profile_id = auth.uid()
    )
  )
);

-- Insert: Users can insert events for themselves
CREATE POLICY "Insert events" ON events
FOR INSERT
WITH CHECK (
  created_by = auth.uid()
);

-- Update/Delete: Users can manage their own events
CREATE POLICY "Manage own events" ON events
FOR ALL
USING (
  created_by = auth.uid()
);
