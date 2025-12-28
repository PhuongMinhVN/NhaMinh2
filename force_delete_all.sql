-- ==============================================================================
-- SCRIPT XOÁ SẠCH TOÀN BỘ DỮ LIỆU (FORCE DELETE)
-- ==============================================================================

-- 1. Xoá bảng profiles (dùng DELETE để đảm bảo kích hoạt mọi ràng buộc xoá)
DELETE FROM public.profiles;

-- 2. Xoá bảng auth.users (nguồn gốc tài khoản)
-- Lưu ý: Lệnh này sẽ xoá toàn bộ user trừ các user hệ thống của Supabase/Realtime
DELETE FROM auth.users 
WHERE instance_id = '00000000-0000-0000-0000-000000000000'; 
-- (Mặc định user tạo ra đều thuộc instance mặc định này)

-- Kiểm tra lại xem còn không
SELECT count(*) as "Số profile còn lại" FROM public.profiles;
