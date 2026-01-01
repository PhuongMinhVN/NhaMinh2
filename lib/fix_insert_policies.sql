-- FIX INSERT POLICIES FOR CLANS AND MEMBERS

-- 1. Policies for CLANS
-- Allow all authenticated users to create a new clan/family
DROP POLICY IF EXISTS "Users can insert clans" ON clans;
CREATE POLICY "Users can insert clans" ON clans FOR INSERT TO authenticated WITH CHECK (auth.uid() = owner_id);

-- Allow owners to update their clan
DROP POLICY IF EXISTS "Owners can update clan" ON clans;
CREATE POLICY "Owners can update clan" ON clans FOR UPDATE USING (auth.uid() = owner_id);


-- 2. Policies for FAMILY_MEMBERS
-- Allow owners to insert members (This is CRITICAL for creating the first root member)
DROP POLICY IF EXISTS "Owners can insert members" ON family_members;
CREATE POLICY "Owners can insert members" ON family_members FOR INSERT TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM clans 
        WHERE clans.id = family_members.clan_id 
        AND clans.owner_id = auth.uid()
    )
);

-- Allow owners to update members
DROP POLICY IF EXISTS "Owners can update members" ON family_members;
CREATE POLICY "Owners can update members" ON family_members FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM clans
        WHERE clans.id = family_members.clan_id
        AND clans.owner_id = auth.uid()
    )
);

-- Allow owners to delete members
DROP POLICY IF EXISTS "Owners can delete members" ON family_members;
CREATE POLICY "Owners can delete members" ON family_members FOR DELETE USING (
    EXISTS (
        SELECT 1 FROM clans
        WHERE clans.id = family_members.clan_id
        AND clans.owner_id = auth.uid()
    )
);


-- 3. Ensure Chat Policies are also loose (just in case)
DROP POLICY IF EXISTS "Users can insert chat messages" ON chat_messages;
CREATE POLICY "Users can insert chat messages" ON chat_messages FOR INSERT TO authenticated WITH CHECK (auth.uid() = sender_id);

NOTIFY pgrst, 'reload schema';
