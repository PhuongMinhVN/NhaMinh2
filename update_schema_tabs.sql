-- CẬP NHẬT DATABASE ĐỂ HỖ TRỢ 2 TAB: VIỆC NHÀ & VIỆC HỌ

-- 1. Sửa bảng clan_events: Thêm phân loại phạm vi (Scope)
-- scope: 'CLAN' (Dòng họ - ai cũng thấy), 'FAMILY' (Gia đình - chỉ gia đình thấy)
alter table public.clan_events 
add column if not exists scope text default 'CLAN' check (scope in ('CLAN', 'FAMILY'));

-- 2. Cập nhật Policy bảo mật cho sự kiện
drop policy if exists "Mọi người xem được sự kiện" on public.clan_events;

create policy "Xem sự kiện" on public.clan_events 
for select using (
  -- Ai cũng xem được việc họ (CLAN)
  scope = 'CLAN' 
  OR 
  -- Việc nhà (FAMILY) thì chỉ xem của chính mình tạo ra (hoặc mở rộng logic sau này)
  (scope = 'FAMILY' AND created_by = auth.uid())
);

-- 3. Tạo dữ liệu mẫu cho Việc Nhà
insert into public.clan_events (title, event_date, is_lunar, description, location, scope, created_by)
values 
('Sinh nhật Bé Bông', '2025-06-01', false, 'Tổ chức sinh nhật 5 tuổi cho con gái', 'Tại nhà riêng', 'FAMILY', auth.uid()),
('Giỗ Cha (Phạm vi gia đình)', '2025-02-20', true, 'Giỗ đầu của cụ ông (làm cơm nội bộ)', 'Nhà trưởng nam', 'FAMILY', auth.uid());

-- 4. View tiện ích (Optional): Giúp lấy danh sách người thân ruột thịt dễ dàng
-- Logic: Lấy Vợ/Chồng hoặc Con cái hoặc Bố mẹ của user đang login
-- (Phần này xử lý ở App Logic bằng Dart sẽ linh động hơn Relational View, nên ta chỉ cần bảng cơ bản).
