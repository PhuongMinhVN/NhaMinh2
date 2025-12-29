-- Add ON DELETE CASCADE to clan_join_requests foreign key
ALTER TABLE clan_join_requests
DROP CONSTRAINT IF EXISTS clan_join_requests_target_clan_id_fkey;

ALTER TABLE clan_join_requests
ADD CONSTRAINT clan_join_requests_target_clan_id_fkey
FOREIGN KEY (target_clan_id)
REFERENCES clans(id)
ON DELETE CASCADE;
