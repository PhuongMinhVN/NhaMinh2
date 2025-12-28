-- Add 'address' column to family_members 
-- This stores the current living address for members who are NOT linked to a User Profile.
ALTER TABLE public.family_members 
ADD COLUMN IF NOT EXISTS address TEXT;
