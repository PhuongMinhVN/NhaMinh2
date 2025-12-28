
-- FIX RLS SỰ KIỆN: Cho phép người tạo luôn xem được bài của mình
-- (Tránh lỗi chặn xem ngay sau khi tạo nếu thông tin chưa khớp)

drop policy if exists "Xem sự kiện" on public.events;

create policy "Xem sự kiện" on public.events for select using (
  -- 1. Chính chủ tạo (luôn xem được)
  created_by = auth.uid()
  
  OR 
  
  -- 2. Sự kiện Dòng họ: Thành viên trong cùng tộc xem được
  (scope = 'CLAN' and exists (
      select 1 from public.family_members fm
      where fm.clan_id = events.clan_id 
      and fm.profile_id = auth.uid()
  ))
  
  OR
  
  -- 3. Sự kiện Gia đình (Hiện tại tạm để create_by, mở rộng sau)
  (scope = 'FAMILY' and created_by = auth.uid()) 
);
