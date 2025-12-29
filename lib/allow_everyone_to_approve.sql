-- SCRIPT CẤP QUYỀN DUYỆT YÊU CẦU CHO TẤT CẢ THÀNH VIÊN
-- Mục đích: Bất kỳ ai có tài khoản và đã có trong gia phả đều thấy và duyệt được yêu cầu.

ALTER TABLE clan_join_requests ENABLE ROW LEVEL SECURITY;

-- 1. Thành viên ĐƯỢC XEM yêu cầu (SELECT)
DROP POLICY IF EXISTS "Members can view requests" ON clan_join_requests;
CREATE POLICY "Members can view requests" ON clan_join_requests
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM family_members 
    WHERE family_members.clan_id = clan_join_requests.target_clan_id 
    AND family_members.profile_id = auth.uid()
  )
);

-- 2. Thành viên ĐƯỢC XỬ LÝ yêu cầu (UPDATE)
DROP POLICY IF EXISTS "Members can update requests" ON clan_join_requests;
CREATE POLICY "Members can update requests" ON clan_join_requests
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM family_members 
    WHERE family_members.clan_id = clan_join_requests.target_clan_id 
    AND family_members.profile_id = auth.uid()
  )
);

-- 3. Người gửi ĐƯỢC XEM yêu cầu của chính mình
DROP POLICY IF EXISTS "Requesters can view own requests" ON clan_join_requests;
CREATE POLICY "Requesters can view own requests" ON clan_join_requests
FOR SELECT
USING (auth.uid() = requester_id);

-- 4. Bất kỳ ai đã đăng nhập ĐƯỢC TẠO yêu cầu
DROP POLICY IF EXISTS "Authenticated can create requests" ON clan_join_requests;
CREATE POLICY "Authenticated can create requests" ON clan_join_requests
FOR INSERT
WITH CHECK (auth.role() = 'authenticated');
