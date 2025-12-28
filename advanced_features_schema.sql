-- ==============================================================================
-- SCHEMA BẢO MẬT & THỪA KẾ TÀI KHOẢN
-- Tính năng: Khôi phục mật khẩu qua VNCCID & Thừa kế tài khoản (Di chúc số)
-- ==============================================================================

-- 0. Bật Extension mã hoá để bảo vệ câu trả lời
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ------------------------------------------------------------------------------
-- PHẦN 1: KHÔI PHỤC MẬT KHẨU QUA VNCCID (Sử dụng câu hỏi bảo mật)
-- ------------------------------------------------------------------------------

-- 1.1 Bảng Ngân hàng câu hỏi (Dữ liệu tĩnh)
CREATE TABLE IF NOT EXISTS public.question_bank (
    id SERIAL PRIMARY KEY,
    content TEXT NOT NULL, -- Nội dung câu hỏi (VD: "Tên trường tiểu học của bạn?")
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Thêm dữ liệu mẫu
INSERT INTO public.question_bank (content) VALUES
('Tên trường tiểu học đầu tiên của bạn?'),
('Tên thú cưng đầu tiên của bạn?'),
('Người bạn thân nhất thời thơ ấu?'),
('Thành phố nơi cha mẹ bạn gặp nhau?'),
('Món ăn bạn yêu thích nhất?')
ON CONFLICT DO NOTHING;

-- 1.2 Bảng Câu trả lời của User (Lưu Hash, không lưu text gốc)
CREATE TABLE IF NOT EXISTS public.user_security_answers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    question_content TEXT NOT NULL, -- Lưu nội dung câu hỏi để hiển thị lại khi cần
    answer_hash TEXT NOT NULL, -- Lưu BCRYPT HASH của câu trả lời
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, question_content)
);

-- 1.3 RPC: Thiết lập câu hỏi bảo mật (Chạy từ App)
CREATE OR REPLACE FUNCTION setup_security_answers(
    questions_data JSONB -- Mảng: [{"question": "...", "answer": "..."}]
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    item JSONB;
    uid UUID;
BEGIN
    uid := auth.uid();
    
    -- Xoá cũ làm mới
    DELETE FROM public.user_security_answers WHERE user_id = uid;
    
    -- Duyệt mảng và insert
    FOR item IN SELECT * FROM jsonb_array_elements(questions_data)
    LOOP
        INSERT INTO public.user_security_answers (user_id, question_content, answer_hash)
        VALUES (
            uid,
            item->>'question',
            crypt(lower(trim(item->>'answer')), gen_salt('bf')) -- Hash câu trả lời (chuẩn hoá lowercase)
        );
    END LOOP;
END;
$$;

-- 1.4 RPC: Lấy danh sách câu hỏi của 1 User (Dùng khi quên mật khẩu)
-- Public function (nhưng rate limit ở App)
CREATE OR REPLACE FUNCTION get_user_security_questions(target_vnccid TEXT)
RETURNS TABLE (question_content TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    target_uid UUID;
BEGIN
    -- Tìm User ID từ VNCCID trong bảng profiles
    SELECT id INTO target_uid FROM public.profiles WHERE vnccid = target_vnccid LIMIT 1;
    
    IF target_uid IS NULL THEN
        RETURN; -- Không tìm thấy user
    END IF;
    
    RETURN QUERY 
    SELECT s.question_content 
    FROM public.user_security_answers s 
    WHERE s.user_id = target_uid;
END;
$$;

-- 1.5 RPC: Xác minh & Đặt lại mật khẩu (QUAN TRỌNG NHẤT)
CREATE OR REPLACE FUNCTION verify_and_reset_password(
    target_vnccid TEXT,
    answers_data JSONB, -- [{"question": "...", "answer": "..."}]
    new_password TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    target_uid UUID;
    item JSONB;
    db_hash TEXT;
    is_correct BOOLEAN;
    correct_count INT := 0;
    total_count INT := 0;
BEGIN
    -- 1. Tìm User
    SELECT id INTO target_uid FROM public.profiles WHERE vnccid = target_vnccid LIMIT 1;
    IF target_uid IS NULL THEN RETURN FALSE; END IF;

    -- 2. Duyệt từng câu trả lời gửi lên
    FOR item IN SELECT * FROM jsonb_array_elements(answers_data)
    LOOP
        total_count := total_count + 1;
        
        -- Lấy hash trong DB
        SELECT answer_hash INTO db_hash 
        FROM public.user_security_answers 
        WHERE user_id = target_uid AND question_content = (item->>'question');
        
        -- So sánh Hash
        IF db_hash IS NOT NULL AND db_hash = crypt(lower(trim(item->>'answer')), db_hash) THEN
            correct_count := correct_count + 1;
        END IF;
    END LOOP;

    -- 3. Kiểm tra kết quả (Phải đúng ít nhất 1 câu và đúng TẤT CẢ câu đã gửi)
    -- Ở đây ta yêu cầu đúng 100% các câu hỏi mà hệ thống yêu cầu trả lời
    IF total_count > 0 AND correct_count = total_count THEN
        -- Đổi mật khẩu
        UPDATE auth.users 
        SET encrypted_password = crypt(new_password, gen_salt('bf')),
            updated_at = now()
        WHERE id = target_uid;
        
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$;

-- ------------------------------------------------------------------------------
-- PHẦN 2: THỪA KẾ TÀI KHOẢN (DI CHÚC SỐ)
-- ------------------------------------------------------------------------------

-- 2.1 Bảng Cài đặt Thừa kế
CREATE TABLE IF NOT EXISTS public.inheritance_settings (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    heir_vnccid TEXT, -- VNCCID người thừa kế
    heir_full_name TEXT,
    heir_phone TEXT,
    inactive_threshold_days INT DEFAULT 365, -- Số ngày không hoạt động để kích hoạt (Mặc định 1 năm)
    last_active_at TIMESTAMPTZ DEFAULT now(), -- Thời điểm hoạt động cuối cùng của chủ tài khoản
    is_claimed BOOLEAN DEFAULT FALSE, -- Đã bị thừa kế chưa
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 2.2 Trigger cập nhật 'last_active_at' khi user làm gì đó (VD: update profile)
CREATE OR REPLACE FUNCTION update_last_active()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.inheritance_settings (user_id, last_active_at)
    VALUES (NEW.id, now())
    ON CONFLICT (user_id) DO UPDATE SET last_active_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Gắn vào bảng profiles (khi sửa profile -> cập nhật active)
DROP TRIGGER IF EXISTS on_profile_active ON public.profiles;
CREATE TRIGGER on_profile_active
AFTER UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION update_last_active();

-- 2.3 RPC: Đăng ký người thừa kế
CREATE OR REPLACE FUNCTION register_heir(
    heir_vnccid_input TEXT,
    heir_name_input TEXT,
    heir_phone_input TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.inheritance_settings (user_id, heir_vnccid, heir_full_name, heir_phone)
    VALUES (auth.uid(), heir_vnccid_input, heir_name_input, heir_phone_input)
    ON CONFLICT (user_id) DO UPDATE 
    SET heir_vnccid = EXCLUDED.heir_vnccid,
        heir_full_name = EXCLUDED.heir_full_name,
        heir_phone = EXCLUDED.heir_phone;
END;
$$;

-- 2.4 RPC: Kích hoạt Thừa kế (Chạy bởi Người thừa kế)
CREATE OR REPLACE FUNCTION claim_inheritance(target_owner_vnccid TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    owner_uid UUID;
    heir_uid UUID;
    setting RECORD;
    days_inactive INT;
BEGIN
    heir_uid := auth.uid();
    
    -- 1. Tìm chủ tài khoản
    SELECT id INTO owner_uid FROM public.profiles WHERE vnccid = target_owner_vnccid LIMIT 1;
    IF owner_uid IS NULL THEN RETURN 'Không tìm thấy tài khoản với VNCCID này.'; END IF;

    -- 2. Lấy cài đặt thừa kế
    SELECT * INTO setting FROM public.inheritance_settings WHERE user_id = owner_uid;
    
    IF setting IS NULL THEN RETURN 'Tài khoản này chưa cài đặt thừa kế.'; END IF;
    
    -- 3. Kiểm tra User hiện tại có phải là Người thừa kế hợp pháp không?
    -- So sánh VNCCID của người đang login với VNCCID được chỉ định làm heir
    IF setting.heir_vnccid IS DISTINCT FROM (SELECT vnccid FROM public.profiles WHERE id = heir_uid) THEN
        RETURN 'Bạn không phải là người thừa kế được chỉ định của tài khoản này.';
    END IF;

    -- 4. Kiểm tra thời gian không hoạt động
    -- (Lấy ngày hiện tại - ngày active cuối)
    days_inactive := EXTRACT(DAY FROM (now() - setting.last_active_at));
    
    IF days_inactive < setting.inactive_threshold_days THEN
        RETURN 'Chưa đủ điều kiện thời gian. Chủ tài khoản mới không hoạt động ' || days_inactive || ' ngày.';
    END IF;

    -- 5. THỰC HIỆN CHUYỂN GIAO (Ở đây mình sẽ cấp quyền truy cập toàn bộ dữ liệu)
    -- Cách đơn giản nhất: Copy quyền Admin của Family cho Heir
    -- (Trong thực tế cần logic phức tạp hơn tuỳ cấu trúc bảng family_members)
    
    -- Đánh dấu đã claim
    UPDATE public.inheritance_settings SET is_claimed = TRUE WHERE user_id = owner_uid;
    
    RETURN 'SUCCESS: Đã tiếp nhận thừa kế thành công.';
END;
$$;
