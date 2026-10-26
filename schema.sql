-- Jalankan sekali melalui Supabase SQL Editor di proyek BARU.
create extension if not exists pgcrypto;
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null default '',
 role text not null default 'viewer' check (role in ('admin','operator','viewer')),
 created_at timestamptz not null default now()
);
create or replace function public.archive_role() returns text
language sql stable security definer set search_path = '' as $$
 select p.role from public.profiles p where p.id = (select auth.uid())
$$;
revoke all on function public.archive_role() from public;
grant execute on function public.archive_role() to authenticated;
create or replace function public.new_archive_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
 insert into public.profiles(id, full_name, role)
 values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name',''), 'viewer');
 return new;
end $$;
drop trigger if exists archive_user_added on auth.users;
create trigger archive_user_added after insert on auth.users
for each row execute function public.new_archive_user();
-- profiles users yang dibuat sebelum schema dijalankan
insert into public.profiles (id, full_name)
select id, coalesce(raw_user_meta_data->>'full_name','') from auth.users
on conflict (id) do nothing;

create table if not exists public.archives (
 id uuid primary key default gen_random_uuid(),
 title text not null check(length(trim(title)) between 1 and 180),
 category text not null check(category ~ '^ARK-(0[1-9]|10)$'),
 subfolder text not null check(subfolder ~ '^ARK-(0[1-9]|10)[.][0-9]{2}$'),
 year integer not null check(year between 1900 and 2200),
 document_date date,
 document_number text not null default '',
 origin text not null default '',
 notes text not null default '',
 file_path text unique,
 file_name text,
 file_size bigint check(file_size is null or file_size >= 0),
 created_by uuid not null default auth.uid() references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint matching_code check(left(subfolder,6)=category)
);
create index if not exists archives_search_idx on public.archives (year,category,subfolder);
create index if not exists archives_created_idx on public.archives (created_at desc);

create table if not exists public.archive_audit (
 id bigint generated always as identity primary key,
 archive_id uuid,
 action text not null,
 actor uuid,
 at timestamptz not null default now(),
 payload jsonb
);
create or replace function public.audit_archive() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
 if tg_op = 'DELETE' then
   insert into public.archive_audit(archive_id,action,actor,payload) values(old.id,'DELETE',auth.uid(),to_jsonb(old));
   return old;
 elsif tg_op = 'INSERT' then
   insert into public.archive_audit(archive_id,action,actor,payload) values(new.id,'INSERT',auth.uid(),to_jsonb(new));
   return new;
 else
   new.updated_at=now();
   insert into public.archive_audit(archive_id,action,actor,payload) values(new.id,'UPDATE',auth.uid(),jsonb_build_object('before',to_jsonb(old),'after',to_jsonb(new)));
   return new;
 end if;
end $$;
drop trigger if exists archive_audit_trigger on public.archives;
create trigger archive_audit_trigger before insert or update or delete on public.archives
for each row execute function public.audit_archive();

alter table public.profiles enable row level security;
alter table public.archives enable row level security;
alter table public.archive_audit enable row level security;
create policy profiles_read on public.profiles for select to authenticated using(id=auth.uid() or public.archive_role()='admin');
create policy profiles_admin_update on public.profiles for update to authenticated using(public.archive_role()='admin') with check(public.archive_role()='admin');
create policy archives_read on public.archives for select to authenticated using(public.archive_role() in ('admin','operator','viewer'));
create policy archives_insert on public.archives for insert to authenticated with check(public.archive_role() in ('admin','operator') and created_by=auth.uid());
create policy archives_update on public.archives for update to authenticated using(public.archive_role() in ('admin','operator')) with check(public.archive_role() in ('admin','operator'));
create policy archives_delete on public.archives for delete to authenticated using(public.archive_role()='admin');
create policy audit_read on public.archive_audit for select to authenticated using(public.archive_role()='admin');
-- Prevent role update by users; only admin policy allows it. Admin role granted manually in SQL initially.
grant usage on schema public to authenticated;
grant select on public.profiles,public.archives,public.archive_audit to authenticated;
grant update(role,full_name) on public.profiles to authenticated;
grant insert,update,delete on public.archives to authenticated;

insert into storage.buckets(id,name,public,file_size_limit)
values ('arsip-private','arsip-private',false,26214400)
on conflict (id) do update set public=false, file_size_limit=26214400;
-- Storage key: arsip/<archive_uuid>/<random_uuid>-<filename>.
-- Read requires archive record matching the id in the pathname.
create policy archive_files_read on storage.objects for select to authenticated
using (bucket_id='arsip-private' and public.archive_role() in ('admin','operator','viewer')
 and exists(select 1 from public.archives a where a.id::text=(storage.foldername(name))[2]));
create policy archive_files_upload on storage.objects for insert to authenticated
with check (bucket_id='arsip-private' and public.archive_role() in ('admin','operator')
 and (storage.foldername(name))[1]='arsip' and (storage.foldername(name))[2] is not null);
create policy archive_files_delete on storage.objects for delete to authenticated
using(bucket_id='arsip-private' and public.archive_role()='admin');
-- CATATAN: file orphan mungkin tersisa bila upload berhasil tetapi insert metadata gagal.
-- File lama ketika diganti dapat dibersihkan oleh admin menggunakan Storage dashboard.
-- Setelah admin pertama dibuat via Authentication > Users, jadikan admin via:
-- update public.profiles set role='admin' where id='<UUID_USER_ADMIN>';
-- Nonaktifkan sign up publik di Authentication > Providers / Signups.
