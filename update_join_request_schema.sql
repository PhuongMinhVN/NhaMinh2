-- CẬP NHẬT SCHEMA V4: HỖ TRỢ YÊU CẦU GIA NHẬP CHI TIẾT

-- 1. Thêm cột type và metadata vào clan_join_requests
ALTER TABLE public.clan_join_requests
ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'claim_existing' CHECK (type IN ('claim_existing', 'create_new')),
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

-- 'metadata' structure examples:
-- claim_existing: { "member_id": 123 }
-- create_new: { 
--    "full_name": "Nguyen Van A", 
--    "gender": "male", 
--    "birth_date": "1990-01-01", 
--    "relation": "child", // child | spouse | parent
--    "relative_id": 456   // ID of the existing member they are related to
-- }

-- 2. Function RPC để duyệt yêu cầu (Approve)
-- Hàm này sẽ tự động thực hiện hành động tương ứng dựa trên type
CREATE OR REPLACE FUNCTION approve_clan_join_request(request_id UUID)
RETURNS VOID AS $$
DECLARE
    req RECORD;
    new_member_id BIGINT;
    r_relative_id BIGINT;
    r_relation TEXT;
    r_full_name TEXT;
    r_gender TEXT;
    r_birth_date DATE;
BEGIN
    -- Lấy thông tin request
    SELECT * INTO req FROM public.clan_join_requests WHERE id = request_id;
    
    IF req IS NULL THEN
        RAISE EXCEPTION 'Request not found';
    END IF;

    IF req.status <> 'pending' AND req.status <> 'approved' THEN 
        -- Nếu đã approve rồi thì thôi, hoặc raise error. Ở đây ta cho phép chạy lại nếu cần fix data lỗi.
        -- Nhưng an toàn nhất là chỉ pending.
        RAISE EXCEPTION 'Request is valid only if pending';
    END IF;

    -- CASE 1: CLAIM EXISTING
    IF req.type = 'claim_existing' THEN
        new_member_id := (req.metadata->>'member_id')::BIGINT;
        
        -- Link profile
        UPDATE public.family_members
        SET profile_id = req.requester_id
        WHERE id = new_member_id;
        
    -- CASE 2: CREATE NEW
    ELSIF req.type = 'create_new' THEN
        r_relation := req.metadata->>'relation';
        r_relative_id := (req.metadata->>'relative_id')::BIGINT;
        r_full_name := req.metadata->>'full_name';
        r_gender := req.metadata->>'gender';
        r_birth_date := (req.metadata->>'birth_date')::DATE;

        -- Insert new member
        INSERT INTO public.family_members (
            full_name, 
            gender, 
            birth_date, 
            clan_id, 
            profile_id,
            father_id,
            mother_id,
            spouse_id,
            is_alive
        )
        VALUES (
            r_full_name,
            r_gender,
            r_birth_date,
            req.target_clan_id,
            req.requester_id,
            -- Logic xác định cha/mẹ/vợ/chồng
            CASE WHEN r_relation = 'child' THEN r_relative_id ELSE NULL END, -- father_id (tạm thời gán vào father, UI chọn kỹ hơn sau)
            NULL, -- mother_id (cần logic phức tạp hơn nếu muốn chọn cả 2)
            CASE WHEN r_relation = 'spouse' THEN r_relative_id ELSE NULL END, -- spouse_id
            true
        );

        -- Nếu là spouse, cần update ngược lại spouse của người kia?
        -- Logic đơn giản tạm thời.
    END IF;

    -- Update request status
    UPDATE public.clan_join_requests
    SET status = 'approved'
    WHERE id = request_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
