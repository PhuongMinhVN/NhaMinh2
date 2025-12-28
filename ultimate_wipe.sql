-- ==============================================================================
-- SCRIPT "HỦY DIỆT" (PHIÊN BẢN ĐƠN GIẢN HOÁ)
-- ==============================================================================

-- 1. Xoá sạch bảng profiles và TẤT CẢ bảng liên quan (Cascade)
-- Đây là lệnh quan trọng nhất để làm trắng dữ liệu
TRUNCATE TABLE public.profiles CASCADE;

-- 2. Xoá các user trong bảng auth (trừ user hệ thống)
DELETE FROM auth.users 
WHERE instance_id = '00000000-0000-0000-0000-000000000000';

-- 3. Hiển thị số lượng còn lại để kiểm tra (Kết quả phải là 0)
SELECT count(*) as "SO_LUONG_CON_LAI" FROM public.profiles;
