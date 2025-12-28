-- ==============================================================================
-- SCRIPT SỬA LỖI: XÁC THỰC THỦ CÔNG CHO TẤT CẢ TÀI KHOẢN
-- Chạy lệnh này sẽ biến tất cả user đang bị kẹt ở trạng thái 'chưa xác thực' thành 'đã xác thực'
-- ==============================================================================

UPDATE auth.users
SET email_confirmed_at = now()
WHERE email_confirmed_at IS NULL;

-- In ra thông báo
DO $$ BEGIN
    RAISE NOTICE 'Đã xác thực thành công cho tất cả tài khoản cũ!';
END $$;
