-- Update child_type constraint to include new grandchild types
ALTER TABLE public.family_members DROP CONSTRAINT IF EXISTS family_members_child_type_check;

ALTER TABLE public.family_members 
ADD CONSTRAINT family_members_child_type_check 
CHECK (child_type IN ('biological', 'adopted', 'step', 'grandchild', 'grandchild_paternal', 'grandchild_maternal'));

COMMENT ON COLUMN public.family_members.child_type IS 'Type of child relationship: biological, adopted, step, grandchild, grandchild_paternal, grandchild_maternal';
