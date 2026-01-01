-- update_schema_vietnamese_genealogy_v2.sql

-- 1. Add Identity Column (VNCCID) - Was missing
ALTER TABLE public.family_members 
ADD COLUMN IF NOT EXISTS vnccid text;

-- 2. Add Relation Type (Phân loại quan hệ)
ALTER TABLE public.family_members 
ADD COLUMN IF NOT EXISTS relation_type text DEFAULT 'blood';

-- 3. Add Generation Number (Thế thứ)
ALTER TABLE public.family_members 
ADD COLUMN IF NOT EXISTS generation_number int DEFAULT 1;

-- 4. Add Origin Tracking
ALTER TABLE public.family_members 
ADD COLUMN IF NOT EXISTS origin_family_name text;

-- 5. Add Maternal Side Flag (Bên Ngoại)
ALTER TABLE public.family_members 
ADD COLUMN IF NOT EXISTS is_maternal boolean DEFAULT false;

-- 6. Add Birth Order (Con thứ mấy)
ALTER TABLE public.family_members 
ADD COLUMN IF NOT EXISTS birth_order int;

-- 7. Add Generation Title (Cao Tổ, Tằng Tổ...)
ALTER TABLE public.family_members 
ADD COLUMN IF NOT EXISTS generation_title text;

-- 8. Create Indexes (Now safe)
CREATE INDEX IF NOT EXISTS idx_family_members_vnccid ON public.family_members(vnccid);
CREATE INDEX IF NOT EXISTS idx_family_members_name_dob ON public.family_members(full_name, birth_date);

-- 9. Update defaults
UPDATE public.family_members SET relation_type = 'blood' WHERE relation_type IS NULL;
UPDATE public.family_members SET is_maternal = false WHERE is_maternal IS NULL;
