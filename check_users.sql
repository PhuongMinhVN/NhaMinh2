-- LƯU Ý QUAN TRỌNG:
-- Bạn KHÔNG THỂ xem mật khẩu gốc (plaintext) vì Supabase mã hóa một chiều (bcrypt).
-- Bạn chỉ có thể xem chuỗi mã hóa (encrypted_password).

-- Xem danh sách user và mật khẩu đã mã hóa
SELECT id, email, phone, encrypted_password, raw_user_meta_data, created_at
FROM auth.users;

-- Nếu bạn muốn đổi mật khẩu cho một user cụ thể (chỉ định ID hoặc Email) để test:
-- UPDATE auth.users
-- SET encrypted_password = crypt('MatKhauMoi123', gen_salt('bf'))
-- WHERE email = 'email_user@example.com';
