-- ==============================================================================
-- SCRIPT XOÁ TRẮNG DỮ LIỆU THÀNH VIÊN (RESET ACCOUNT)
-- Cảnh báo: Dữ liệu bị xoá sẽ KHÔNG THỂ khôi phục.
-- ==============================================================================

-- 1. Xoá dữ liệu hồ sơ (bảng phụ thuộc)
TRUNCATE TABLE public.profiles CASCADE;

-- 2. Xoá dữ liệu đăng nhập (bảng gốc)
-- Lưu ý: Chỉ xoá user thường, giữ lại user hệ thống nếu có.
DELETE FROM auth.users WHERE email NOT LIKE '%@supabase.io'; -- Giữ lại user service nếu có

-- In thông báo
DO $$ BEGIN
    RAISE NOTICE 'Đã xoá trắng toàn bộ thành viên. Hệ thống đã sẵn sàng cho đăng ký mới từ đầu.';
END $$;
