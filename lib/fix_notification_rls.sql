-- Fix RLS (Security) Policy for Notifications table
-- currently, users are blocked from creating notifications for OTHERS.
-- This script permits authenticated users to insert notifications.

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- 1. Allow Users to SEE their own notifications
DROP POLICY IF EXISTS "Xem thông báo của mình" ON public.notifications;
CREATE POLICY "Xem thông báo của mình" ON public.notifications 
    FOR SELECT 
    USING (auth.uid() = user_id);

-- 2. Allow Users to INSERT notifications (Fixes the Error 42501)
-- Allows any logged-in user to create a notification record 
DROP POLICY IF EXISTS "Gửi thông báo" ON public.notifications;
CREATE POLICY "Gửi thông báo" ON public.notifications 
    FOR INSERT 
    WITH CHECK (auth.role() = 'authenticated');

-- 3. Allow Users to UPDATE (mark as read) their own notifications
DROP POLICY IF EXISTS "Sửa thông báo của mình" ON public.notifications;
CREATE POLICY "Sửa thông báo của mình" ON public.notifications 
    FOR UPDATE 
    USING (auth.uid() = user_id);
