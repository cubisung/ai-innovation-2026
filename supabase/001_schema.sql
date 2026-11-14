-- AI INNOVATION 2026 · VietinBank Đắk Nông
-- 001_schema.sql: bảng dữ liệu, phân quyền RLS và các hàm nghiệp vụ.
-- Chạy một lần trong Supabase > SQL Editor. Mọi thao tác ghi đều đi qua hàm (RPC),
-- người dùng không được ghi trực tiếp vào bảng.

create extension if not exists pgcrypto;

-- ---------- Hàm tiện ích ----------
create or replace function public.today_vn() returns date language sql stable
as $$ select (now() at time zone 'Asia/Ho_Chi_Minh')::date $$;

create or replace function public.blank_stages() returns jsonb language sql immutable
as $$ select jsonb_agg(jsonb_build_object('state','locked','start','','done','','by','')) from generate_series(1,5) $$;

create or replace function public.set_updated_at() returns trigger language plpgsql
as $$ begin new.updated_at = now(); return new; end $$;

-- ---------- Bảng ----------
create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('cell','dept')),
  name text not null,
  sort int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (kind, name)
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  ad text not null,
  full_name text not null,
  dept text not null,
  cell int not null check (cell between 1 and 3),
  title text not null default '',
  role text not null default 'member' check (role in ('member','committee')),
  com_ok boolean not null default false,
  approved boolean not null default false,  -- tài khoản mới phải được Cấp uỷ duyệt (trừ khi có trong danh sách đảng viên)
  locked boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index profiles_ad_key on public.profiles (lower(ad));

-- Danh sách đảng viên do Cấp uỷ nhập từ Excel. Dùng để tính tổng số đảng viên và tự duyệt tài khoản trùng User AD.
create table public.roster (
  ad text primary key,
  full_name text not null,
  dept text not null,
  cell int not null check (cell between 1 and 3),
  title text not null default '',
  role text not null default 'member' check (role in ('member','committee')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index roster_ad_key on public.roster (lower(ad));

create table public.commitments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  content text not null,
  pledged_at date not null,
  confirmed_at date,
  confirmed_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.initiatives (
  id uuid primary key default gen_random_uuid(),
  owner uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  problem text not null default '',
  field text not null default '',
  tech text not null default '',
  solution text not null default '',
  goal text not null default '',
  expected text not null default '',
  output text not null default '',
  start_date date not null,
  due_date date not null,
  criteria text not null default '',
  is_primary boolean not null default false,
  status text not null default 'draft' check (status in ('draft','pending','revise','approved','paused')),
  submitted_at date,
  approved_at date,
  featured boolean not null default false,
  edit_req_note text,
  edit_req_at timestamptz,
  stages jsonb not null default public.blank_stages(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (due_date >= start_date)
);
create unique index initiatives_one_primary on public.initiatives (owner) where is_primary;
create index initiatives_owner_idx on public.initiatives (owner);

create table public.progress_updates (
  id uuid primary key default gen_random_uuid(),
  initiative_id uuid not null references public.initiatives(id) on delete cascade,
  stage int not null check (stage between 1 and 5),
  author uuid not null references public.profiles(id),
  content text not null,
  created_at timestamptz not null default now()
);
create index progress_updates_init_idx on public.progress_updates (initiative_id);

create table public.evidences (
  id uuid primary key default gen_random_uuid(),
  update_id uuid not null references public.progress_updates(id) on delete cascade,
  kind text not null check (kind in ('link','file')),
  name text not null,
  url text,
  path text,
  created_at timestamptz not null default now()
);
create index evidences_update_idx on public.evidences (update_id);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  initiative_id uuid not null references public.initiatives(id) on delete cascade,
  stage int not null check (stage between 1 and 5),
  reviewer uuid not null references public.profiles(id),
  action text not null check (action in ('approve','revise','confirm','reopen')),
  note text not null default '',
  created_at timestamptz not null default now()
);
create index reviews_init_idx on public.reviews (initiative_id);

create table public.comments (
  id uuid primary key default gen_random_uuid(),
  initiative_id uuid not null references public.initiatives(id) on delete cascade,
  author uuid not null references public.profiles(id),
  content text not null,
  created_at timestamptz not null default now()
);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor uuid,
  action text not null,
  detail text not null default '',
  created_at timestamptz not null default now()
);

create trigger t_org_upd before update on public.organizations for each row execute function public.set_updated_at();
create trigger t_profiles_upd before update on public.profiles for each row execute function public.set_updated_at();
create trigger t_roster_upd before update on public.roster for each row execute function public.set_updated_at();
create trigger t_commit_upd before update on public.commitments for each row execute function public.set_updated_at();
create trigger t_init_upd before update on public.initiatives for each row execute function public.set_updated_at();

insert into public.organizations (kind, name, sort) values
 ('cell','Chi bộ 1',1),('cell','Chi bộ 2',2),('cell','Chi bộ 3',3),
 ('dept','Phòng Khách hàng doanh nghiệp',1),('dept','Phòng Bán lẻ',2),('dept','Phòng Kế toán',3),
 ('dept','Phòng Tiền tệ kho quỹ',4),('dept','Phòng Tổ chức hành chính',5),('dept','Phòng Tổng hợp',6);

-- ---------- Hàm kiểm tra quyền ----------
create or replace function public.is_active() returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from profiles where id = auth.uid() and approved and not locked) $$;

create or replace function public.is_committee() returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from profiles where id = auth.uid() and role = 'committee' and com_ok and approved and not locked) $$;

-- Cấp uỷ cùng Chi bộ duyệt; không tự duyệt của mình. Nếu Chi bộ không còn cấp uỷ nào khác thì cấp uỷ Chi bộ khác duyệt thay.
create or replace function public.can_review(p_owner uuid) returns boolean language sql stable security definer set search_path = public
as $$
  select public.is_committee() and auth.uid() <> p_owner and (
    exists (select 1 from profiles a, profiles o where a.id = auth.uid() and o.id = p_owner and a.cell = o.cell)
    or not exists (select 1 from profiles c, profiles o where o.id = p_owner and c.cell = o.cell and c.id <> p_owner
                   and c.role = 'committee' and c.com_ok and c.approved and not c.locked)
  )
$$;

create or replace function public.ad_taken(p_ad text) returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from profiles where lower(ad) = lower(trim(p_ad))) $$;

create or replace function public._need_active() returns uuid language plpgsql stable security definer set search_path = public
as $$
declare v uuid := auth.uid();
begin
  if v is null or not exists (select 1 from profiles where id = v and approved and not locked) then
    raise exception 'Tài khoản chưa đăng nhập, chưa được duyệt hoặc đã bị khóa' using errcode = '42501';
  end if;
  return v;
end $$;

create or replace function public._log(p_action text, p_detail text) returns void language sql security definer set search_path = public
as $$ insert into audit_logs (actor, action, detail) values (auth.uid(), p_action, coalesce(p_detail,'')) $$;

create or replace function public._st(p_stages jsonb, p_k int, p_patch jsonb) returns jsonb language sql immutable
as $$ select jsonb_set(p_stages, array[p_k::text], (p_stages -> p_k) || p_patch) $$;

create or replace function public._has_evidence(p_id uuid, p_stage int) returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from progress_updates u join evidences e on e.update_id = u.id where u.initiative_id = p_id and u.stage = p_stage) $$;

-- ---------- Tạo hồ sơ khi đăng ký tài khoản ----------
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public
as $$
declare m jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
        v_ad text := coalesce(nullif(regexp_replace(coalesce(m->>'ad',''), '\s+', '', 'g'),''), split_part(new.email,'@',1));
        v_role text := case when m->>'role' = 'committee' then 'committee' else 'member' end;
        v_dept text := coalesce(nullif(trim(m->>'dept'),''), 'Chưa rõ');
        v_name text := coalesce(nullif(trim(m->>'full_name'),''), v_ad);
        v_cell int := least(3, greatest(1, coalesce(nullif(regexp_replace(coalesce(m->>'cell',''), '\D', '', 'g'),'')::int, 1)));
        v_title text := coalesce(trim(m->>'title'),'');
        r roster;
        -- Khi hệ thống chưa có Cấp uỷ nào: tài khoản được duyệt tự động và Cấp uỷ đầu tiên được xác nhận tự động.
        v_boot boolean := not exists (select 1 from profiles where role = 'committee' and com_ok and approved and not locked);
begin
  select * into r from roster where lower(ad) = lower(v_ad);
  if r.ad is not null then  -- có trong danh sách: lấy thông tin theo danh sách, không theo người tự khai
    v_ad := r.ad; v_name := r.full_name; v_dept := r.dept; v_cell := r.cell; v_title := r.title; v_role := r.role;
  end if;
  insert into profiles (id, ad, full_name, dept, cell, title, role, com_ok, approved)
  values (new.id, v_ad, v_name, v_dept, v_cell, v_title, v_role, v_role = 'committee' and v_boot, v_boot or r.ad is not null);
  insert into organizations (kind, name, sort) values ('dept', v_dept, 99) on conflict do nothing;
  insert into audit_logs (actor, action, detail) values (new.id, 'Đăng ký tài khoản', v_ad);
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

-- ---------- Hàm nghiệp vụ (RPC) ----------
create or replace function public.save_initiative(p_id uuid, p jsonb) returns uuid language plpgsql security definer set search_path = public
as $$
declare me uuid := _need_active(); v_id uuid;
begin
  if coalesce(trim(p->>'title'),'') = '' then raise exception 'Thiếu tên sáng kiến'; end if;
  if (p->>'due')::date < (p->>'start')::date then raise exception 'Thời hạn hoàn thành phải sau ngày bắt đầu'; end if;
  if p_id is null then
    insert into initiatives (owner, title, problem, field, tech, solution, goal, expected, output, start_date, due_date, criteria, is_primary)
    values (me, trim(p->>'title'), coalesce(p->>'problem',''), coalesce(p->>'field',''), coalesce(p->>'tech',''), coalesce(p->>'solution',''),
            coalesce(p->>'goal',''), coalesce(p->>'expected',''), coalesce(p->>'output',''), (p->>'start')::date, (p->>'due')::date,
            coalesce(p->>'criteria',''), not exists (select 1 from initiatives where owner = me and is_primary))
    returning id into v_id;
    perform _log('Tạo sáng kiến', p->>'title');
  else
    update initiatives set title = trim(p->>'title'), problem = coalesce(p->>'problem',''), field = coalesce(p->>'field',''), tech = coalesce(p->>'tech',''),
           solution = coalesce(p->>'solution',''), goal = coalesce(p->>'goal',''), expected = coalesce(p->>'expected',''), output = coalesce(p->>'output',''),
           start_date = (p->>'start')::date, due_date = (p->>'due')::date, criteria = coalesce(p->>'criteria','')
    where id = p_id and owner = me and status in ('draft','revise') returning id into v_id;
    if v_id is null then raise exception 'Chỉ sửa được sáng kiến của mình khi đang là bản nháp hoặc được yêu cầu bổ sung'; end if;
    perform _log('Sửa sáng kiến', p->>'title');
  end if;
  return v_id;
end $$;

create or replace function public.delete_initiative(p_id uuid) returns void language plpgsql security definer set search_path = public
as $$
declare me uuid := _need_active(); v_title text;
begin
  delete from initiatives where id = p_id and owner = me and status = 'draft' returning title into v_title;
  if v_title is null then raise exception 'Chỉ xóa được bản nháp của mình'; end if;
  if not exists (select 1 from initiatives where owner = me and is_primary) then
    update initiatives set is_primary = true where id = (select id from initiatives where owner = me order by created_at limit 1);
  end if;
  perform _log('Xóa bản nháp', v_title);
end $$;

create or replace function public.set_primary(p_id uuid) returns void language plpgsql security definer set search_path = public
as $$
declare me uuid := _need_active();
begin
  if not exists (select 1 from initiatives where id = p_id and owner = me and status in ('draft','revise')) then
    raise exception 'Chỉ đổi sáng kiến chính khi sáng kiến chưa gửi hoặc được yêu cầu bổ sung';
  end if;
  update initiatives set is_primary = false where owner = me and is_primary and id <> p_id;
  update initiatives set is_primary = true where id = p_id;
end $$;

create or replace function public.submit_registration(p_content text) returns void language plpgsql security definer set search_path = public
as $$
declare me uuid := _need_active(); n int;
begin
  select count(*) into n from initiatives where owner = me and status in ('draft','revise');
  if n = 0 then raise exception 'Chưa có sáng kiến nào để gửi'; end if;
  if (select count(*) from initiatives where owner = me and is_primary) <> 1 then raise exception 'Cần chọn đúng một sáng kiến chính'; end if;
  insert into commitments (user_id, content, pledged_at) values (me, p_content, today_vn()) on conflict (user_id) do nothing;
  update initiatives set status = 'pending', submitted_at = today_vn(), edit_req_note = null, edit_req_at = null,
         stages = _st(blank_stages(), 0, jsonb_build_object('state','submitted','start',today_vn()::text))
  where owner = me and status in ('draft','revise');
  perform _log('Gửi đăng ký', n || ' sáng kiến');
end $$;

create or replace function public.approve_registration(p_owner uuid) returns void language plpgsql security definer set search_path = public
as $$
declare me uuid := _need_active(); r record; n int := 0;
begin
  if not can_review(p_owner) then raise exception 'Bạn không có quyền duyệt đăng ký này' using errcode = '42501'; end if;
  for r in select id from initiatives where owner = p_owner and status = 'pending' loop
    update initiatives set status = 'approved', approved_at = today_vn(),
      stages = _st(_st(stages, 0, jsonb_build_object('state','confirmed','done',today_vn()::text,'by',me::text)), 1, jsonb_build_object('state','open','start',today_vn()::text))
    where id = r.id;
    insert into reviews (initiative_id, stage, reviewer, action) values (r.id, 1, me, 'approve');
    n := n + 1;
  end loop;
  if n = 0 then raise exception 'Không có đăng ký nào đang chờ duyệt'; end if;
  update commitments set confirmed_at = today_vn(), confirmed_by = me where user_id = p_owner and confirmed_at is null;
  perform _log('Xác nhận cam kết', (select ad from profiles where id = p_owner) || ' · ' || n || ' sáng kiến');
end $$;

create or replace function public.request_revision(p_owner uuid, p_note text) returns void language plpgsql security definer set search_path = public
as $$
declare me uuid := _need_active(); r record;
begin
  if not can_review(p_owner) then raise exception 'Bạn không có quyền duyệt đăng ký này' using errcode = '42501'; end if;
  if coalesce(trim(p_note),'') = '' then raise exception 'Hãy nhập nội dung cần bổ sung'; end if;
  for r in select id from initiatives where owner = p_owner and status = 'pending' loop
    update initiatives set status = 'revise', stages = _st(stages, 0, jsonb_build_object('state','revise')) where id = r.id;
    insert into reviews (initiative_id, stage, reviewer, action, note) values (r.id, 1, me, 'revise', trim(p_note));
  end loop;
  perform _log('Yêu cầu bổ sung đăng ký', (select ad from profiles where id = p_owner));
end $$;

create or replace function public.request_edit(p_id uuid, p_note text) returns void language plpgsql security definer set search_path = public
as $$
declare me uuid := _need_active(); v_title text;
begin
  if coalesce(trim(p_note),'') = '' then raise exception 'Hãy nhập lý do cần chỉnh sửa'; end if;
  update initiatives set edit_req_note = trim(p_note), edit_req_at = now()
  where id = p_id and owner = me and (status = 'pending' or (status = 'approved' and (stages->1->>'state') = 'open'
        and not exists (select 1 from progress_updates u where u.initiative_id = p_id)))
  returning title into v_title;
  if v_title is null then raise exception 'Chỉ yêu cầu chỉnh sửa khi sáng kiến đang chờ xác nhận, hoặc đã xác nhận nhưng chưa có cập nhật tiến độ'; end if;
  perform _log('Yêu cầu chỉnh sửa', v_title);
end $$;

create or replace function public.resolve_edit(p_id uuid, p_reopen boolean) returns void language plpgsql security definer set search_path = public
as $$
declare me uuid := _need_active(); i initiatives;
begin
  select * into i from initiatives where id = p_id;
  if i.id is null or not can_review(i.owner) or i.edit_req_note is null then raise exception 'Không có yêu cầu chỉnh sửa để xử lý' using errcode = '42501'; end if;
  if p_reopen then
    update initiatives set status = 'revise', approved_at = null, edit_req_note = null, edit_req_at = null,
           stages = _st(blank_stages(), 0, jsonb_build_object('state','revise')) where id = p_id;
    insert into reviews (initiative_id, stage, reviewer, action) values (p_id, 1, me, 'reopen');
    perform _log('Mở lại cho chỉnh sửa', i.title);
  else
    update initiatives set edit_req_note = null, edit_req_at = null where id = p_id;
    perform _log('Từ chối yêu cầu chỉnh sửa', i.title);
  end if;
end $$;

create or replace function public.add_update(p_id uuid, p_stage int, p_content text, p_evidences jsonb) returns uuid language plpgsql security definer set search_path = public
as $$
declare me uuid := _need_active(); i initiatives; v_id uuid; e jsonb;
begin
  select * into i from initiatives where id = p_id;
  if i.id is null or i.owner <> me then raise exception 'Chỉ cập nhật được sáng kiến của mình' using errcode = '42501'; end if;
  if i.status <> 'approved' or p_stage not between 2 and 5 or (i.stages->(p_stage-1)->>'state') not in ('open','revise') then
    raise exception 'Giai đoạn này chưa mở để cập nhật';
  end if;
  if coalesce(trim(p_content),'') = '' then raise exception 'Hãy nhập nội dung cập nhật'; end if;
  insert into progress_updates (initiative_id, stage, author, content) values (p_id, p_stage, me, trim(p_content)) returning id into v_id;
  for e in select * from jsonb_array_elements(coalesce(p_evidences,'[]'::jsonb)) loop
    if e->>'kind' = 'link' and (e->>'url') ~* '^https?://' then
      insert into evidences (update_id, kind, name, url) values (v_id, 'link', coalesce(e->>'name', e->>'url'), e->>'url');
    elsif e->>'kind' = 'file' and (e->>'path') like p_id::text || '/%' then
      insert into evidences (update_id, kind, name, path) values (v_id, 'file', coalesce(e->>'name','Tệp minh chứng'), e->>'path');
    else
      raise exception 'Minh chứng không hợp lệ';
    end if;
  end loop;
  perform _log('Cập nhật tiến độ', i.title || ' · Giai đoạn ' || p_stage);
  return v_id;
end $$;

create or replace function public.send_stage(p_id uuid, p_stage int) returns void language plpgsql security definer set search_path = public
as $$
declare me uuid := _need_active(); i initiatives;
begin
  select * into i from initiatives where id = p_id;
  if i.id is null or i.owner <> me then raise exception 'Chỉ gửi được sáng kiến của mình' using errcode = '42501'; end if;
  if i.status <> 'approved' or p_stage not between 2 and 5 or (i.stages->(p_stage-1)->>'state') not in ('open','revise') then
    raise exception 'Giai đoạn này chưa mở để gửi xác nhận';
  end if;
  if not _has_evidence(p_id, p_stage) then raise exception 'Cần ít nhất một cập nhật có minh chứng'; end if;
  update initiatives set stages = _st(stages, p_stage-1, jsonb_build_object('state','submitted')) where id = p_id;
  perform _log('Gửi xác nhận giai đoạn', i.title || ' · Giai đoạn ' || p_stage);
end $$;

create or replace function public.confirm_stage(p_id uuid, p_stage int) returns void language plpgsql security definer set search_path = public
as $$
declare me uuid := _need_active(); i initiatives; s jsonb;
begin
  select * into i from initiatives where id = p_id;
  if i.id is null or not can_review(i.owner) then raise exception 'Bạn không có quyền xác nhận sáng kiến này' using errcode = '42501'; end if;
  if i.status <> 'approved' or p_stage not between 2 and 5 or (i.stages->(p_stage-1)->>'state') <> 'submitted' then
    raise exception 'Giai đoạn này chưa được gửi xác nhận';
  end if;
  if not _has_evidence(p_id, p_stage) then raise exception 'Giai đoạn này chưa có minh chứng'; end if;
  s := _st(i.stages, p_stage-1, jsonb_build_object('state','confirmed','done',today_vn()::text,'by',me::text));
  if p_stage < 5 then s := _st(s, p_stage, jsonb_build_object('state','open','start',today_vn()::text)); end if;
  update initiatives set stages = s where id = p_id;
  insert into reviews (initiative_id, stage, reviewer, action) values (p_id, p_stage, me, 'confirm');
  perform _log(case when p_stage = 5 then 'Xác nhận hoàn thành' else 'Xác nhận giai đoạn' end, i.title || ' · Giai đoạn ' || p_stage);
end $$;

create or replace function public.return_stage(p_id uuid, p_stage int, p_note text) returns void language plpgsql security definer set search_path = public
as $$
declare me uuid := _need_active(); i initiatives;
begin
  select * into i from initiatives where id = p_id;
  if i.id is null or not can_review(i.owner) then raise exception 'Bạn không có quyền xác nhận sáng kiến này' using errcode = '42501'; end if;
  if p_stage not between 2 and 5 or (i.stages->(p_stage-1)->>'state') <> 'submitted' then raise exception 'Giai đoạn này chưa được gửi xác nhận'; end if;
  if coalesce(trim(p_note),'') = '' then raise exception 'Hãy nhập nội dung cần bổ sung'; end if;
  update initiatives set stages = _st(stages, p_stage-1, jsonb_build_object('state','revise')) where id = p_id;
  insert into reviews (initiative_id, stage, reviewer, action, note) values (p_id, p_stage, me, 'revise', trim(p_note));
  perform _log('Yêu cầu bổ sung giai đoạn', i.title || ' · Giai đoạn ' || p_stage);
end $$;

create or replace function public.toggle_pause(p_id uuid) returns void language plpgsql security definer set search_path = public
as $$
declare me uuid := _need_active(); i initiatives;
begin
  select * into i from initiatives where id = p_id;
  if i.id is null or not can_review(i.owner) or i.status not in ('approved','paused') or (i.stages->4->>'state') = 'confirmed' then
    raise exception 'Không thể tạm dừng hoặc tiếp tục sáng kiến này' using errcode = '42501';
  end if;
  update initiatives set status = case when status = 'paused' then 'approved' else 'paused' end where id = p_id;
  perform _log(case when i.status = 'paused' then 'Tiếp tục triển khai' else 'Tạm dừng' end, i.title);
end $$;

create or replace function public.toggle_featured(p_id uuid) returns void language plpgsql security definer set search_path = public
as $$
declare me uuid := _need_active(); v_title text;
begin
  if not is_committee() then raise exception 'Chỉ Cấp uỷ được đánh dấu sáng kiến tiêu biểu' using errcode = '42501'; end if;
  update initiatives set featured = not featured where id = p_id and (stages->4->>'state') = 'confirmed' returning title into v_title;
  if v_title is null then raise exception 'Chỉ đánh dấu được sáng kiến đã hoàn thành'; end if;
  perform _log('Đổi đánh dấu tiêu biểu', v_title);
end $$;

create or replace function public.add_comment(p_id uuid, p_text text) returns void language plpgsql security definer set search_path = public
as $$
declare me uuid := _need_active();
begin
  if coalesce(trim(p_text),'') = '' then raise exception 'Hãy nhập nội dung bình luận'; end if;
  if not exists (select 1 from initiatives where id = p_id and status <> 'draft') then raise exception 'Không tìm thấy sáng kiến'; end if;
  insert into comments (initiative_id, author, content) values (p_id, me, trim(p_text));
end $$;

create or replace function public.admin_set_committee(p_user uuid, p_ok boolean) returns void language plpgsql security definer set search_path = public
as $$
declare me uuid := _need_active();
begin
  if not is_committee() or p_user = me then raise exception 'Chỉ Cấp uỷ khác mới được xác nhận' using errcode = '42501'; end if;
  if p_ok then update profiles set role = 'committee', com_ok = true where id = p_user;
  else update profiles set role = 'member', com_ok = false where id = p_user; end if;
  perform _log(case when p_ok then 'Xác nhận Cấp uỷ' else 'Chuyển thành Đảng viên' end, (select ad from profiles where id = p_user));
end $$;

create or replace function public.admin_set_locked(p_user uuid, p_locked boolean) returns void language plpgsql security definer set search_path = public
as $$
declare me uuid := _need_active();
begin
  if not is_committee() or p_user = me then raise exception 'Chỉ Cấp uỷ khác mới được khóa hoặc mở khóa' using errcode = '42501'; end if;
  update profiles set locked = p_locked where id = p_user;
  perform _log(case when p_locked then 'Khóa tài khoản' else 'Mở khóa tài khoản' end, (select ad from profiles where id = p_user));
end $$;

create or replace function public.admin_approve(p_user uuid) returns void language plpgsql security definer set search_path = public
as $$
declare me uuid := _need_active();
begin
  if not is_committee() then raise exception 'Chỉ Cấp uỷ được duyệt tài khoản' using errcode = '42501'; end if;
  update profiles set approved = true where id = p_user;
  perform _log('Duyệt tài khoản', (select ad from profiles where id = p_user));
end $$;

-- Nhập danh sách đảng viên: [{"ad":"..","full_name":"..","dept":"..","cell":1,"title":"..","role":"member|committee"}]
create or replace function public.import_roster(p_rows jsonb) returns int language plpgsql security definer set search_path = public
as $$
declare me uuid := _need_active(); e jsonb; n int := 0; v_ad text; v_dept text;
begin
  if not is_committee() then raise exception 'Chỉ Cấp uỷ được nhập danh sách đảng viên' using errcode = '42501'; end if;
  for e in select * from jsonb_array_elements(coalesce(p_rows,'[]'::jsonb)) loop
    v_ad := regexp_replace(coalesce(e->>'ad',''), '\s+', '', 'g');
    continue when v_ad = '';
    v_dept := coalesce(nullif(trim(e->>'dept'),''), 'Chưa rõ');
    delete from roster where lower(ad) = lower(v_ad);
    insert into roster (ad, full_name, dept, cell, title, role)
    values (v_ad, coalesce(nullif(trim(e->>'full_name'),''), v_ad), v_dept,
            least(3, greatest(1, coalesce(nullif(regexp_replace(coalesce(e->>'cell',''), '\D', '', 'g'),'')::int, 1))),
            coalesce(trim(e->>'title'),''), case when e->>'role' = 'committee' then 'committee' else 'member' end);
    insert into organizations (kind, name, sort) values ('dept', v_dept, 99) on conflict do nothing;
    n := n + 1;
  end loop;
  perform _log('Nhập danh sách đảng viên', n || ' dòng');
  return n;
end $$;

create or replace function public.remove_roster(p_ad text) returns void language plpgsql security definer set search_path = public
as $$
declare me uuid := _need_active();
begin
  if not is_committee() then raise exception 'Chỉ Cấp uỷ được sửa danh sách đảng viên' using errcode = '42501'; end if;
  delete from roster where lower(ad) = lower(p_ad);
  perform _log('Xóa khỏi danh sách đảng viên', p_ad);
end $$;

-- ---------- RLS: chỉ cho đọc, mọi thao tác ghi đi qua hàm ----------
alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.commitments enable row level security;
alter table public.roster enable row level security;
alter table public.initiatives enable row level security;
alter table public.progress_updates enable row level security;
alter table public.evidences enable row level security;
alter table public.reviews enable row level security;
alter table public.comments enable row level security;
alter table public.audit_logs enable row level security;

create policy org_read on public.organizations for select to anon, authenticated using (true);
create policy profiles_read on public.profiles for select to authenticated using (id = auth.uid() or public.is_active());
create policy roster_read on public.roster for select to authenticated using (public.is_active());
create policy commitments_read on public.commitments for select to authenticated using (public.is_active());
create policy initiatives_read on public.initiatives for select to authenticated
  using (public.is_active() and (status <> 'draft' or owner = auth.uid()));
create policy updates_read on public.progress_updates for select to authenticated
  using (public.is_active() and exists (select 1 from public.initiatives i where i.id = initiative_id));
create policy evidences_read on public.evidences for select to authenticated
  using (public.is_active() and exists (select 1 from public.progress_updates u where u.id = update_id));
create policy reviews_read on public.reviews for select to authenticated
  using (public.is_active() and exists (select 1 from public.initiatives i where i.id = initiative_id));
create policy comments_read on public.comments for select to authenticated
  using (public.is_active() and exists (select 1 from public.initiatives i where i.id = initiative_id));
create policy audit_read on public.audit_logs for select to authenticated using (public.is_committee());

revoke all on all tables in schema public from anon, authenticated;
grant select on public.organizations to anon, authenticated;
grant select on public.profiles, public.roster, public.commitments, public.initiatives, public.progress_updates,
      public.evidences, public.reviews, public.comments, public.audit_logs to authenticated;

revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function public.ad_taken(text) to anon, authenticated;
grant execute on function public.today_vn(), public.is_active(), public.is_committee(), public.can_review(uuid),
  public.save_initiative(uuid, jsonb), public.delete_initiative(uuid), public.set_primary(uuid), public.submit_registration(text),
  public.approve_registration(uuid), public.request_revision(uuid, text), public.request_edit(uuid, text), public.resolve_edit(uuid, boolean),
  public.add_update(uuid, int, text, jsonb), public.send_stage(uuid, int), public.confirm_stage(uuid, int), public.return_stage(uuid, int, text),
  public.toggle_pause(uuid), public.toggle_featured(uuid), public.add_comment(uuid, text),
  public.admin_set_committee(uuid, boolean), public.admin_set_locked(uuid, boolean), public.admin_approve(uuid),
  public.import_roster(jsonb), public.remove_roster(text) to authenticated;
