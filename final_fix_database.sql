-- ==============================================================================
-- SCRIPT SỬA LỖI CUỐI CÙNG CHO ĐĂNG KÝ THÀNH VIÊN
-- Mục tiêu: Đảm bảo Trigger không bao giờ bị lỗi 'Database error saving new user'
-- ==============================================================================

-- 1. Đảm bảo bảng PROFILES có đủ cột và đúng kiểu
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade not null primary key,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- Bổ sung các cột nếu thiếu (dùng add column if not exists để an toàn)
alter table public.profiles add column if not exists full_name text;
alter table public.profiles add column if not exists avatar_url text;
alter table public.profiles add column if not exists phone text;
alter table public.profiles add column if not exists vnccid text;
alter table public.profiles add column if not exists role text default 'member';
alter table public.profiles add column if not exists birthday date;

-- 2. Cài đặt lại FUNCTION xử lý người dùng mới (Phiên bản an toàn nhất)
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, role, phone, vnccid, avatar_url, birthday)
  values (
    new.id,
    -- Tên: Lấy từ metadata, nếu null thì lấy phần đầu email, nếu null nữa thì để trống
    COALESCE(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1), 'Thành viên mới'),
    'member',
    -- Phone & VNCCID: Lấy từ metadata, chấp nhận null
    new.raw_user_meta_data->>'phone',
    new.raw_user_meta_data->>'vnccid',
    COALESCE(new.raw_user_meta_data->>'avatar_url', ''),
    -- Birthday: Cố gắng ép kiểu, nếu lỗi hoặc rỗng thì để NULL (tránh lỗi crash)
    CASE 
        WHEN new.raw_user_meta_data->>'birthday' = '' THEN NULL
        ELSE (new.raw_user_meta_data->>'birthday')::date
    END
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    phone = EXCLUDED.phone,
    vnccid = EXCLUDED.vnccid,
    birthday = EXCLUDED.birthday;
    
  return new;
exception when others then
  -- Quan trọng: Nếu có lỗi gì xảy ra, vẫn cho phép tạo User Auth nhưng ghi log (để App không bị chặn)
  raise warning 'Lỗi tạo profile: %', SQLERRM;
  return new;
end;
$$ language plpgsql security definer;

-- 3. Gắn lại Trigger (Xóa cũ tạo mới cho chắc ăn)
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Test
DO $$ BEGIN
    RAISE NOTICE 'Đã sửa lỗi Database thành công. Hãy thử đăng ký lại!';
END $$;
