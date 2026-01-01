-- Create a storage bucket for avatars if it doesn't exist
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Set up access policies for the avatars bucket

-- Allow public read access to everyone
create policy "Avatar Public Access"
  on storage.objects for select
  using ( bucket_id = 'avatars' );

-- Allow authenticated users to upload their own avatar
-- We will use the user's ID as the file name or folder structure to ensure uniqueness and security
-- For simplicity in this demo, we allow authenticated users to insert objects into the avatars bucket
create policy "Avatar Upload Access"
  on storage.objects for insert
  with check ( bucket_id = 'avatars' and auth.role() = 'authenticated' );

-- Allow users to update their own avatar (replace existing file)
create policy "Avatar Update Access"
  on storage.objects for update
  using ( bucket_id = 'avatars' and auth.role() = 'authenticated' );

-- Allow users to delete their own avatar
create policy "Avatar Delete Access"
  on storage.objects for delete
  using ( bucket_id = 'avatars' and auth.role() = 'authenticated' );
