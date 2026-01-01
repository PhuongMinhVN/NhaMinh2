-- Fix missing 'type' in clans table
-- Assign 'clan' or 'family' based on clues, default to 'clan' for legacy data.

UPDATE public.clans
SET type = 
  CASE 
    WHEN lower(name) LIKE '%gia đình%' THEN 'family'
    WHEN lower(name) LIKE '%nhà%' THEN 'family'
    ELSE 'clan'
  END
WHERE type IS NULL OR type = '';

-- Also ensure future inserts default to something if not provided (though code handles it now)
ALTER TABLE public.clans ALTER COLUMN type SET DEFAULT 'clan';
