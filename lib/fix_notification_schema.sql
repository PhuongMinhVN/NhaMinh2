-- Fix missing columns in notifications table
-- Run this script in Supabase SQL Editor to patch the database

ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS message text;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS related_id text;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS type text DEFAULT 'general';
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS title text;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS is_read boolean DEFAULT false;
