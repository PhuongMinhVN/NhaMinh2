-- CẬP NHẬT QUYỀN DUYỆT YÊU CẦU: CHO PHÉP MỌI THÀNH VIÊN TRONG GIA ĐÌNH DUYỆT

-- 1. Xóa các Policy cũ giới hạn
DROP POLICY IF EXISTS "Clan owner can view requests to their clan" ON public.clan_join_requests;
DROP POLICY IF EXISTS "Clan owner can update status" ON public.clan_join_requests;
DROP POLICY IF EXISTS "Clan members can view requests" ON public.clan_join_requests;
DROP POLICY IF EXISTS "Clan members can update status" ON public.clan_join_requests;


-- 2. Tạo Policy mới: Bất cứ thành viên nào trong Clan đều có thể xem
CREATE POLICY "Clan members can view requests" ON public.clan_join_requests 
FOR SELECT USING (
    -- Người xem là người gửi yêu cầu (để xem trạng thái của mình)
    auth.uid() = requester_id
    OR
    -- HOẶC Người xem có thông tin trong bảng family_members với clan_id = target_clan_id
    EXISTS (
        SELECT 1 FROM public.family_members 
        WHERE clan_id = target_clan_id 
        AND profile_id = auth.uid()
        -- Có thể thêm điều kiện: AND title IS NOT NULL nếu muốn giới hạn
    )
);

-- 3. Tạo Policy mới: Bất cứ thành viên nào cũng có thể duyệt
CREATE POLICY "Clan members can update status" ON public.clan_join_requests 
FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM public.family_members 
        WHERE clan_id = target_clan_id 
        AND profile_id = auth.uid()
    )
);

-- Note: Lỗi PostgrestException PGRST200 "Could not find a relationship" xảy ra trong `fetchPendingRequests`
-- do Supabase không tự detect relationship khi ta join `requester_id` với `profiles` hoặc `auth.users` mà không khai báo rõ FK.
-- Trong code Dart ta query: .select('*, requester:requester_id (email, raw_user_meta_data)')
-- Điều này yêu cầu cột `requester_id` phải là FK trỏ tới bảng nào đó.
-- Trong schema hiện tại, `requester_id` đang REFERENCES auth.users(id).
-- Tuy nhiên, Supabase JS client/Flutter client khi query quan hệ thì nó dựa vào tên constraint.

-- ĐỂ FIX LỖI PGRST200, ta cần chắc chắn relationship.
-- Vì auth.users là bảng system, ta không thể query trực tiếp dễ dàng qua postgrest public.
-- Giải pháp: JOIN với bảng `public.profiles` (nếu đã tạo trigger copy user sang profiles) HOẶC bỏ qua join và query 2 bước.

-- GIẢI PHÁP TỐT NHẤT: Sửa code Dart không join `requester` nữa mà lấy list request về rồi fetch user info sau.
-- Tuy nhiên, để tiện, ta nên trỏ requester_id sang bảng public.profiles thì tốt hơn (nếu bảng đó tồn tại và đồng bộ).
-- Kiểm tra lại bảng `profiles`. Nếu APP đã có logic tạo profile thì nên reference tới profiles.

-- Tạm thời, tôi sẽ KHUYẾN NGHỊ sửa code Dart để không join phức tạp nếu chưa setup FK chuẩn tới profiles,
-- HOẶC sửa constraint. Nhưng sửa code Dart là an toàn nhất để tránh lỗi "Could not find a relationship".
