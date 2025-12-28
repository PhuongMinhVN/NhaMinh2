-- SCRIPT ĐẢM BẢO TỰ ĐỘNG TẠO PROFILE KHI ĐĂNG KÝ
-- Chạy script này để chắc chắn trigger hoạt động tốt

-- 1. Xóa các policy gây xung đột (nếu có)
drop trigger if exists on_auth_user_created on auth.users;

-- 2. Đảm bảo Function xử lý tồn tại
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, role, phone, vnccid, avatar_url)
  values (
    new.id, 
    -- Ưu tiên lấy từ metadata (lúc đăng ký), nếu không có thì lấy phần đầu email
    COALESCE(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    'member',
    new.raw_user_meta_data->>'phone',
    new.raw_user_meta_data->>'vnccid',
    COALESCE(new.raw_user_meta_data->>'avatar_url', '')
  );
  return new;
end;
$$ language plpgsql security definer;

-- 3. Tạo lại Trigger
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Test thử bằng cách hiển thị notice
DO $$ BEGIN
    RAISE NOTICE 'Đã cài đặt xong Trigger tự động tạo Profile khi đăng ký!';
END $$;
