-- ==============================================================================
-- CẬP NHẬT DATABASE: THÊM TRƯỜNG 'NƠI Ở' VÀ UPDATE TRIGGER
-- ==============================================================================

-- 1. Thêm cột 'current_address' (nơi ở) vào bảng profiles
alter table public.profiles add column if not exists current_address text;

-- 2. Cập nhật Trigger để lưu thêm Nơi ở từ form đăng ký
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (
    id, full_name, role, phone, vnccid, avatar_url, birthday, current_address
  )
  values (
    new.id,
    COALESCE(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1), 'Thành viên mới'),
    'member',
    new.raw_user_meta_data->>'phone',
    new.raw_user_meta_data->>'vnccid',
    COALESCE(new.raw_user_meta_data->>'avatar_url', ''),
    -- Birthday để NULL vì giờ user sẽ cập nhật sau
    NULL,
    -- Lưu nơi ở
    new.raw_user_meta_data->>'current_address'
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    phone = EXCLUDED.phone,
    vnccid = EXCLUDED.vnccid,
    current_address = EXCLUDED.current_address;
    
  return new;
end;
$$ language plpgsql security definer;
