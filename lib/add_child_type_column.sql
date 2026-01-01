-- ADD CHILD TYPE COLUMN

-- 1. Add 'child_type' column to distinguish relationships
-- Values: 'biological' (Con ruột), 'adopted' (Con nuôi), 'step' (Con riêng), 'grandchild' (Cháu - placeholder if needed)
alter table public.family_members add column if not exists child_type text default 'biological';

-- 2. Add 'role_label' column for custom labels like "Cháu đích tôn", "Con trưởng", etc.
alter table public.family_members add column if not exists role_label text;
