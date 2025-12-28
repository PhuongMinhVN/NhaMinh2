-- CẬP NHẬT SCHEMA V3: QUẢN LÝ DÒNG HỌ & HỢP TỘC

-- 1. Bảng `clans`: Quản lý các dòng họ riêng biệt
CREATE TABLE IF NOT EXISTS public.clans (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    owner_id UUID REFERENCES auth.users(id), -- Người tạo/Chi trưởng
    type TEXT DEFAULT 'clan' CHECK (type IN ('clan', 'family')), -- Phân loại: Dòng họ hoặc Gia đình
    qr_code TEXT UNIQUE, -- Mã định danh duy nhất (có thể là UUID hoặc Custom String)
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Bật RLS cho clans
ALTER TABLE public.clans ENABLE ROW LEVEL SECURITY;

-- Policy: Ai cũng có thể xem (để scan QR)
CREATE POLICY "Anyone can view clans" ON public.clans FOR SELECT USING (true);
-- Policy: Chỉ owner mới được sửa
CREATE POLICY "Owner can update clan" ON public.clans FOR UPDATE USING (auth.uid() = owner_id);
-- Policy: Authenticated users can insert
CREATE POLICY "Users can create clan" ON public.clans FOR INSERT WITH CHECK (auth.uid() = owner_id);


-- 2. Cập nhật `family_members`: Gắn thành viên vào Clan
ALTER TABLE public.family_members 
ADD COLUMN IF NOT EXISTS clan_id UUID REFERENCES public.clans(id),
ADD COLUMN IF NOT EXISTS branch_name TEXT, -- Tên chi/nhánh (Vd: Chi 2)
ADD COLUMN IF NOT EXISTS is_male_lineage BOOLEAN DEFAULT TRUE; -- Theo dòng nam

-- 3. Bảng `clan_join_requests`: Yêu cầu gia nhập/hợp tộc
CREATE TABLE IF NOT EXISTS public.clan_join_requests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    requester_id UUID REFERENCES auth.users(id),
    target_clan_id UUID REFERENCES public.clans(id),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Policy cho request
ALTER TABLE public.clan_join_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "User can view own requests" ON public.clan_join_requests FOR SELECT USING (auth.uid() = requester_id);
CREATE POLICY "Clan owner can view requests to their clan" ON public.clan_join_requests 
FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.clans WHERE id = target_clan_id AND owner_id = auth.uid())
);
CREATE POLICY "Users can create requests" ON public.clan_join_requests FOR INSERT WITH CHECK (auth.uid() = requester_id);
CREATE POLICY "Clan owner can update status" ON public.clan_join_requests 
FOR UPDATE USING (
     EXISTS (SELECT 1 FROM public.clans WHERE id = target_clan_id AND owner_id = auth.uid())
);

-- 4. Function: Sinh mã QR Code tự động khi tạo Clan
CREATE OR REPLACE FUNCTION generate_clan_qr() 
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.qr_code IS NULL THEN
    NEW.qr_code := 'CLAN-' || substring(md5(random()::text) from 1 for 8);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_generate_clan_qr
BEFORE INSERT ON public.clans
FOR EACH ROW EXECUTE FUNCTION generate_clan_qr();

-- 5. RPC: Xử lý Hợp Tộc (Merge)
-- Hàm này sẽ chuyển toàn bộ thành viên do user này quản lý (hoặc chọn lọc) sang clan mới
-- Và update cha của root_node cũ thành new_parent_id
CREATE OR REPLACE FUNCTION merge_clan_tree(
    target_clan_id UUID, 
    source_root_id BIGINT, 
    new_parent_id BIGINT
)
RETURNS VOID AS $$
DECLARE
    -- Biến để đếm số lượng cập nhật
    affected_rows INT;
BEGIN
    -- 1. Cập nhật cha cho nút gốc của nhánh muốn ghép
    UPDATE public.family_members
    SET father_id = new_parent_id,
        clan_id = target_clan_id -- Chuyển luôn người này sang clan mới
    WHERE id = source_root_id;

    -- 2. Cập nhật clan_id cho toàn bộ con cháu của node này (Đệ quy)
    -- Sử dụng CTE đệ quy để tìm tất cả hậu duệ
    WITH RECURSIVE descendants AS (
        SELECT id FROM public.family_members WHERE id = source_root_id
        UNION
        SELECT fm.id FROM public.family_members fm
        INNER JOIN descendants d ON fm.father_id = d.id OR fm.mother_id = d.id
    )
    UPDATE public.family_members
    SET clan_id = target_clan_id
    WHERE id IN (SELECT id FROM descendants);
    
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

NOTIFY pgrst, 'reload schema';
