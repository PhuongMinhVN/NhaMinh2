-- update_schema_vietnamese_genealogy.sql

-- 1. Add Relation Type (Phân loại quan hệ)
-- Values: 
-- 'blood': Ruột thịt (Con đẻ)
-- 'in_law': Dâu/Rể
-- 'adopted': Con nuôi
-- 'social': Kết nghĩa / Bạn bè (Sẽ không được gộp vào Dòng họ chính)
-- 'pet': Thú cưng
ALTER TABLE public.family_members 
ADD COLUMN IF NOT EXISTS relation_type text DEFAULT 'blood';

-- 2. Add Generation Number (Thế thứ / Đời thứ mấy)
-- Root usually is 1 or 0.
ALTER TABLE public.family_members 
ADD COLUMN IF NOT EXISTS generation_number int DEFAULT 1;

-- 3. Add Origin Tracking (Nguồn gốc)
-- To track which "Family" a member came from when merged into a "Clan"
ALTER TABLE public.family_members 
ADD COLUMN IF NOT EXISTS origin_family_name text;

-- 4. Index for Fast Deduplication
CREATE INDEX IF NOT EXISTS idx_family_members_vnccid ON public.family_members(vnccid);
CREATE INDEX IF NOT EXISTS idx_family_members_name_dob ON public.family_members(full_name, birth_date);

-- 5. Update Existing Data
-- Default everyone to 'blood' if null
UPDATE public.family_members SET relation_type = 'blood' WHERE relation_type IS NULL;
