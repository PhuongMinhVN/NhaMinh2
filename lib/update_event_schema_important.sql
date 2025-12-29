-- Add is_important column to events table
ALTER TABLE events 
ADD COLUMN IF NOT EXISTS is_important BOOLEAN DEFAULT false;
