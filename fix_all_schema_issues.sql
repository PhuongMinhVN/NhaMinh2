-- SCRIPT SỬA CHỮA TOÀN DIỆN CHO TÍNH NĂNG GIA NHẬP (Run this script)

-- 1. Đảm bảo bảng `clan_join_requests` có đủ cột
ALTER TABLE public.clan_join_requests
ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'claim_existing' CHECK (type IN ('claim_existing', 'create_new')),
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

-- 2. Cấp quyền INSERT cho người dùng (quan trọng cho bước "Tạo mới")
DROP POLICY IF EXISTS "Users can create requests" ON public.clan_join_requests;
CREATE POLICY "Users can create requests" ON public.clan_join_requests FOR INSERT WITH CHECK (auth.uid() = requester_id);

-- 3. Cấp quyền XEM cho chính người gửi (để kiểm tra trùng lặp)
DROP POLICY IF EXISTS "User can view own requests" ON public.clan_join_requests;
CREATE POLICY "User can view own requests" ON public.clan_join_requests FOR SELECT USING (auth.uid() = requester_id);

-- 4. Cấp quyền XEM và DUYỆT cho thành viên trong gia đình (Tính năng phân quyền mới)
DROP POLICY IF EXISTS "Clan members can view requests" ON public.clan_join_requests;
CREATE POLICY "Clan members can view requests" ON public.clan_join_requests 
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.family_members 
        WHERE clan_id = target_clan_id 
        AND profile_id = auth.uid()
    )
    OR auth.uid() = requester_id -- Bao gồm cả người gửi
);

DROP POLICY IF EXISTS "Clan members can update status" ON public.clan_join_requests;
CREATE POLICY "Clan members can update status" ON public.clan_join_requests 
FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM public.family_members 
        WHERE clan_id = target_clan_id 
        AND profile_id = auth.uid()
    )
);

-- 5. Cập nhật hàm RPC Duyệt yêu cầu (Logic tạo mới/claim)
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
    SELECT * INTO req FROM public.clan_join_requests WHERE id = request_id;
    
    IF req IS NULL THEN RAISE EXCEPTION 'Request not found'; END IF;
    IF req.status <> 'pending' THEN RETURN; END IF; -- Idempotent check

    -- CASE 1: CLAIM EXISTING
    IF req.type = 'claim_existing' THEN
        new_member_id := (req.metadata->>'member_id')::BIGINT;
        UPDATE public.family_members
        SET profile_id = req.requester_id
        WHERE id = new_member_id;
        
    -- CASE 2: CREATE NEW
    ELSIF req.type = 'create_new' THEN
        r_relation := req.metadata->>'relation';
        r_relative_id := (req.metadata->>'relative_id')::BIGINT;
        r_full_name := req.metadata->>'full_name';
        r_gender := req.metadata->>'gender';
        -- Safe date parsing
        BEGIN
            r_birth_date := (req.metadata->>'birth_date')::DATE;
        EXCEPTION WHEN others THEN
            r_birth_date := NULL;
        END;

        INSERT INTO public.family_members (
            full_name, gender, birth_date, clan_id, profile_id, is_alive,
            father_id, spouse_id
        )
        VALUES (
            r_full_name,
            r_gender,
            r_birth_date,
            req.target_clan_id,
            req.requester_id,
            true,
            CASE WHEN r_relation = 'child' THEN r_relative_id ELSE NULL END, -- father_id context
            CASE WHEN r_relation = 'spouse' THEN r_relative_id ELSE NULL END -- spouse_id context
        );
    END IF;

    -- Update request status
    UPDATE public.clan_join_requests
    SET status = 'approved'
    WHERE id = request_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
