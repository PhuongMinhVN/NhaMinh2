
-- RESET TOÀN BỘ QUYỀN (RLS) CHO BẢNG EVENTS ĐỂ KHẮC PHỤC LỖI 42501
-- Chạy script này sẽ xóa các policy cũ và tạo policy mới chuẩn xác hơn.

-- 1. Bảng EVENTS
alter table public.events enable row level security;

-- Xóa các policy cũ (nếu có) để tránh xung đột
drop policy if exists "Xem sự kiện" on public.events;
drop policy if exists "Tạo sự kiện" on public.events;
drop policy if exists "Sửa sự kiện" on public.events;
drop policy if exists "Xóa sự kiện" on public.events;
drop policy if exists "Users can insert their own events" on public.events;
drop policy if exists "Users can view their own events" on public.events;

-- TẠO POLICY MỚI

-- A. QUYỀN XEM (SELECT): 
-- 1. Xem sự kiện do chính mình tạo
-- 2. Xem sự kiện Dòng họ nếu mình là thành viên của dòng họ đó
create policy "Xem sự kiện" on public.events for select using (
  created_by = auth.uid() 
  OR 
  (scope = 'CLAN' and exists (
    select 1 from public.family_members fm
    where fm.clan_id = events.clan_id 
    and fm.profile_id = auth.uid()
  ))
);

-- B. QUYỀN THÊM (INSERT):
-- Cho phép user đã đăng nhập được tạo sự kiện.
-- Quan trọng: check(true) hoặc check(created_by = auth.uid()) để đảm bảo khớp với dòng vừa tạo
create policy "Tạo sự kiện" on public.events for insert with check (
  auth.role() = 'authenticated'
);

-- C. QUYỀN SỬA/XÓA (UPDATE/DELETE):
-- Chỉ người tạo mới được sửa/xóa
create policy "Sửa sự kiện" on public.events for update using (created_by = auth.uid());
create policy "Xóa sự kiện" on public.events for delete using (created_by = auth.uid());


-- 2. Bảng EVENT_PARTICIPANTS (Reset luôn cho chắc)
alter table public.event_participants enable row level security;

drop policy if exists "Xem người tham gia" on public.event_participants;
drop policy if exists "Tự update trạng thái" on public.event_participants;
drop policy if exists "Người tạo event thêm người" on public.event_participants;
drop policy if exists "Thêm người tham gia" on public.event_participants;

create policy "Xem người tham gia" on public.event_participants for select using (true);

create policy "Thêm người tham gia" on public.event_participants for insert with check (
  auth.role() = 'authenticated'
);

create policy "Sửa trạng thái" on public.event_participants for update using (
  user_id = auth.uid() OR 
  exists (select 1 from public.events where id = event_id and created_by = auth.uid())
);
