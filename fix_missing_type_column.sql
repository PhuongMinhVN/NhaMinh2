-- Bổ sung cột type còn thiếu cho bảng clans
ALTER TABLE public.clans 
ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'clan' CHECK (type IN ('clan', 'family'));

-- Đảm bảo bảng family_members có cột profile_id để liên kết với tài khoản
ALTER TABLE public.family_members 
ADD COLUMN IF NOT EXISTS profile_id UUID REFERENCES public.profiles(id);
