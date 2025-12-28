-- CẬP NHẬT CẤU TRÚC CHO FAMILY TREE VÀ SỰ KIỆN

-- 1. Bảng family_members: Thêm avatar và đánh dấu gốc
ALTER TABLE public.family_members 
ADD COLUMN IF NOT EXISTS avatar_url TEXT,
ADD COLUMN IF NOT EXISTS is_root BOOLEAN DEFAULT FALSE;

-- 2. Bảng clan_events: Thêm loại sự kiện và báo trước
-- type: 'annual' (hàng năm), 'one_time' (1 lần)
ALTER TABLE public.clan_events
ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'one_time' CHECK (type IN ('annual', 'one_time')),
ADD COLUMN IF NOT EXISTS notify_before_days INT DEFAULT 3;

-- 3. Trigger kiểm tra logic (Optional): Đảm bảo chỉ có 1 root (nếu cần, nhưng tạm thời để mở cho linh hoạt nhiều nhánh)

-- 4. RPC: Lấy danh sách sự kiện sắp tới (Bao gồm tính toán ngày Âm)
-- Lưu ý: Việc tính ngày Âm -> Dương phức tạp nên ta sẽ xử lý ở tầng Application (Flutter).
-- Hàm này chỉ hỗ trợ query cơ bản.

-- Refresh lại cache schema
NOTIFY pgrst, 'reload schema';
