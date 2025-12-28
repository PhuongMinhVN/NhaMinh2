-- ==============================================================================
-- GIẢI PHÁP TỰ ĐỘNG ĐỒNG BỘ: PROFILE THAY ĐỔI -> LOGIN TỰ CẬP NHẬT
-- ==============================================================================

-- 1. Tạo hàm xử lý (Chạy với quyền Admin - Security Definer)
CREATE OR REPLACE FUNCTION public.sync_profile_phone_to_auth()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  clean_phone text;
  new_fake_email text;
BEGIN
  -- Chỉ chạy nếu SĐT có thay đổi và không null
  IF NEW.phone IS DISTINCT FROM OLD.phone AND NEW.phone IS NOT NULL THEN
    
    -- 1. Làm sạch SĐT (chỉ giữ số)
    clean_phone := regexp_replace(NEW.phone, '\D', '', 'g');
    
    -- 2. Kiểm tra độ dài (đảm bảo hợp lệ trước khi update)
    IF length(clean_phone) >= 9 THEN
        new_fake_email := 'vn' || clean_phone || '@gmail.com';
        
        -- 3. Cập nhật thẳng vào bảng auth.users (Bỏ qua các check rườm rà của API)
        UPDATE auth.users
        SET 
            email = new_fake_email,
            email_confirmed_at = now(), -- Xác nhận luôn
            updated_at = now(),
            raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('phone', NEW.phone)
        WHERE id = NEW.id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- 2. Gắn Trigger vào bảng profiles
DROP TRIGGER IF EXISTS on_profile_phone_change ON public.profiles;
CREATE TRIGGER on_profile_phone_change
AFTER UPDATE OF phone ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.sync_profile_phone_to_auth();

-- 3. CHẠY NGAY LẬP TỨC: SỬA LỖI CHO CÁC TÀI KHOẢN ĐANG BỊ LỆCH
UPDATE auth.users u
SET 
  email = 'vn' || regexp_replace(p.phone, '\D', '', 'g') || '@gmail.com'
FROM public.profiles p
WHERE u.id = p.id
AND p.phone IS NOT NULL
-- Chỉ update những ai đang bị lệch
AND (u.email IS NULL OR u.email != 'vn' || regexp_replace(p.phone, '\D', '', 'g') || '@gmail.com');

SELECT 'Đã cài đặt Trigger tự động và Đồng bộ lại dữ liệu thành công!' as Ket_Qua;
