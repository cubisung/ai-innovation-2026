-- 002_storage.sql: kho tệp minh chứng (riêng tư, tối đa 10 MB mỗi tệp). Chạy sau 001_schema.sql.
insert into storage.buckets (id, name, public, file_size_limit)
values ('evidences', 'evidences', false, 10485760) on conflict (id) do nothing;

-- Đường dẫn tệp: <mã sáng kiến>/<tên tệp>. Chỉ chủ sáng kiến được tải lên.
create policy evidences_upload on storage.objects for insert to authenticated
  with check (bucket_id = 'evidences' and public.is_active()
    and exists (select 1 from public.initiatives i where i.id::text = (storage.foldername(name))[1] and i.owner = auth.uid()));

-- Xem tệp: chủ sáng kiến, Cấp uỷ, hoặc mọi đảng viên khi sáng kiến đã hoàn thành.
create policy evidences_view on storage.objects for select to authenticated
  using (bucket_id = 'evidences' and public.is_active()
    and exists (select 1 from public.initiatives i where i.id::text = (storage.foldername(name))[1]
      and (i.owner = auth.uid() or public.is_committee() or (i.stages->4->>'state') = 'confirmed')));
-- Không có quyền sửa hoặc xóa tệp cho người dùng: lịch sử minh chứng được giữ nguyên.
