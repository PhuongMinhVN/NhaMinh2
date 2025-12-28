ALTER TABLE family_members 
ADD COLUMN birth_order INTEGER;

COMMENT ON COLUMN family_members.birth_order IS 'The order of birth among siblings (1 = Firstborn, etc.)';
