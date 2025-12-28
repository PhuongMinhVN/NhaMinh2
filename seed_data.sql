-- ==============================================================================
-- SCRIPT TẠO DỮ LIỆU MẪU (SEED DATA)
-- CHÚ Ý: Bạn cần Đăng Ký ít nhất 1 tài khoản trên App trước khi chạy script này.
-- Script sẽ lấy User đầu tiên tìm thấy để làm "chủ nhân" của các dữ liệu mẫu.
-- ==============================================================================

DO $$
DECLARE
  my_uid uuid;
  grandpa_id bigint;
  dad_id bigint;
  mom_id bigint;
BEGIN
  -- 1. Lấy ID của user đầu tiên tìm thấy trong hệ thống (Chính là bạn)
  SELECT id INTO my_uid FROM auth.users LIMIT 1;

  IF my_uid IS NOT NULL THEN
    
    -- Cập nhật Profile của bạn thành Tộc Trưởng (Admin) để test full quyền
    UPDATE public.profiles 
    SET full_name = 'Nguyễn Văn Minh (Admin)', 
        role = 'toc_truong',
        phone = '0912345678'
    WHERE id = my_uid;

    -- ==========================================================================
    -- 2. TẠO DỮ LIỆU CÂY GIA PHẢ (FAMILY MEMBERS)
    -- ==========================================================================
    
    -- Thế hệ 1: Ông nội (đã mất)
    INSERT INTO public.family_members (full_name, nickname, gender, is_alive, death_date, generation_level, bio)
    VALUES ('Nguyễn Văn Tổ', 'Cụ Cố', 'male', false, '1980-01-01', 1, 'Người khai sáng chi phái 2')
    RETURNING id INTO grandpa_id;

    -- Thế hệ 2: Bố (đang sống)
    INSERT INTO public.family_members (full_name, gender, is_alive, birth_date, father_id, generation_level)
    VALUES ('Nguyễn Văn Ba', 'male', true, '1960-05-15', grandpa_id, 2)
    RETURNING id INTO dad_id;

    -- Thế hệ 2: Mẹ (đang sống)
    INSERT INTO public.family_members (full_name, gender, is_alive, birth_date, generation_level)
    VALUES ('Trần Thị Mẹ', 'female', true, '1965-08-20', 2)
    RETURNING id INTO mom_id;

    -- Thế hệ 3: Bản thân User (Gắn kết với tài khoản App)
    -- Lưu ý: Kiểm tra xem user này đã có trong family_members chưa, nếu chưa mới thêm
    IF NOT EXISTS (SELECT 1 FROM public.family_members WHERE profile_id = my_uid) THEN
        INSERT INTO public.family_members (full_name, gender, is_alive, birth_date, father_id, mother_id, generation_level, profile_id)
        VALUES ('Nguyễn Văn Minh', 'male', true, '1990-01-01', dad_id, mom_id, 3, my_uid);
    END IF;


    -- ==========================================================================
    -- 3. TẠO SỰ KIỆN (EVENTS) - VIỆC HỌ & VIỆC NHÀ
    -- ==========================================================================
    
    -- Xóa dữ liệu cũ để tránh trùng lặp khi chạy nhiều lần
    DELETE FROM public.clan_events WHERE created_by = my_uid;

    -- Việc Họ (CLAN) - Hiển thị bên Tab "Việc Dòng Họ"
    INSERT INTO public.clan_events (title, description, event_date, is_lunar, location, scope, created_by)
    VALUES 
    ('Giỗ Tổ Hùng Vương (Họ)', 'Cả dòng họ tập trung tại nhà thờ tổ. Yêu cầu mặc trang phục chỉnh tề.', '2025-04-07', true, 'Nhà Thờ Tổ', 'CLAN', my_uid),
    ('Họp mặt cuối năm z', 'Tổng kết quỹ và trao thưởng khuyến học cho các cháu.', '2025-12-25', false, 'Nhà Văn Hóa Thôn', 'CLAN', my_uid);

    -- Việc Nhà (FAMILY) - Hiển thị bên Tab "Việc Nhà Mình"
    INSERT INTO public.clan_events (title, description, event_date, is_lunar, location, scope, created_by)
    VALUES 
    ('Sinh nhật Con Gái (Bé Bông)', 'Mua bánh kem và tổ chức tiệc nhỏ tại nhà.', '2025-06-01', false, 'Nhà riêng', 'FAMILY', my_uid),
    ('Giỗ Ông Nội (Cúng cơm)', 'Làm mâm cơm cúng ông, mời các bác sang ăn.', '2025-02-15', true, 'Nhà Bố Mẹ', 'FAMILY', my_uid);


    -- ==========================================================================
    -- 4. TẠO BÀI ĐĂNG (POSTS) - TEST NEWSFEED
    -- ==========================================================================
    INSERT INTO public.posts (content, author_id, scope, type)
    VALUES 
    ('Chào cả nhà! Năm nay giỗ tổ có mời đoàn chèo ở Thái Bình về hát không nhỉ?', my_uid, 'CLAN', 'news'),
    ('Cuối tuần này gia đình mình đi picnic ở Ecopark nhé!', my_uid, 'FAMILY', 'news');


    -- ==========================================================================
    -- 5. TẠO QUỸ (FUNDS)
    -- ==========================================================================
    INSERT INTO public.clan_funds (title, amount, type, contributor_name, note)
    VALUES
    ('Đóng góp tu sửa mái đình', 2000000, 'income', 'Nguyễn Văn Minh', 'Chuyển khoản VCB');

    RAISE NOTICE 'Đã tạo dữ liệu mẫu thành công cho User ID: %', my_uid;

  ELSE
    RAISE EXCEPTION 'KHÔNG TÌM THẤY USER NÀO! Vui lòng Đăng ký tài khoản trên App và Đăng nhập ít nhất 1 lần trước khi chạy script này.';
  END IF;

END $$;
