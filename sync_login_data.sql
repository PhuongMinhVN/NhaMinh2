-- ==============================================================================
-- SCRIPT ĐỒNG BỘ: ÉP LOGIN THEO PROFILE
-- Tác dụng: Lấy SĐT từ bảng profiles và cập nhật vào bảng login (auth.users)
-- Giúp giải quyết trường hợp đã đổi SĐT trong Profile nhưng Login chưa nhận.
-- ==============================================================================

-- 1. Cập nhật Login Email dựa trên Phone trong Profile
UPDATE auth.users u
SET 
  email = 'vn' || regexp_replace(p.phone, '\D', '', 'g') || '@gmail.com',
  email_confirmed_at = now(), -- Xác nhận luôn
  updated_at = now()
FROM public.profiles p
WHERE u.id = p.id
AND p.phone IS NOT NULL
AND length(regexp_replace(p.phone, '\D', '', 'g')) >= 10 -- Chỉ xử lý số hợp lệ
AND (u.email IS NULL OR u.email != 'vn' || regexp_replace(p.phone, '\D', '', 'g') || '@gmail.com');

-- 2. Đồng bộ luôn metadata cho chắc chắn
UPDATE auth.users u
SET raw_user_meta_data = 
  COALESCE(u.raw_user_meta_data, '{}'::jsonb) || 
  jsonb_build_object(
    'phone', p.phone,
    'full_name', p.full_name,
    'vnccid', p.vnccid
  )
FROM public.profiles p
WHERE u.id = p.id;

-- In kết quả
DO $$ BEGIN
    RAISE NOTICE 'Đã đồng bộ dữ liệu đăng nhập thành công! Hãy thử đăng nhập bằng SĐT mới.';
END $$;
