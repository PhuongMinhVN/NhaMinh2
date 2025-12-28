-- Add 'is_maternal' column to family_members for Small Family features
-- Distinguishes members from the Maternal side (Bên ngoại).
ALTER TABLE public.family_members 
ADD COLUMN IF NOT EXISTS is_maternal BOOLEAN DEFAULT false;
