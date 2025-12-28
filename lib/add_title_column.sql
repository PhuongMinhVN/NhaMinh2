-- Add 'title' column to family_members for role management
-- Allowed values intended: 'Trưởng họ', 'Phó họ', 'Chi trưởng', 'Chi phó'
ALTER TABLE public.family_members 
ADD COLUMN IF NOT EXISTS title TEXT;
