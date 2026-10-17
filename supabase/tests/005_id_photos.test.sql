-- id_photos table and the id-photos storage bucket.
-- Spec: guards may insert only; receptionists read rows for passes they are deciding
-- (pending, or decided by them); admins read all.
begin;
\ir helpers/setup.psql
select plan(28);

select tests.build_world();
select tests.snapshot_counts();

-- ---------------------------------------------------------------------------
-- id_photos rows
-- ---------------------------------------------------------------------------
select tests.authenticate_as('guard');
select lives_ok(
  $$insert into public.id_photos (pass_id, storage_path) values (tests.id('gate_pending'), tests.id('gate_pending') || '/new.jpg')$$,
  'guard attaches a photo to own pending gate request');
select throws_ok(
  $$insert into public.id_photos (pass_id, storage_path) values (tests.id('web_pending'), tests.id('web_pending') || '/x.jpg')$$,
  '42501', null, 'guard cannot attach to a web request');
select throws_ok(
  $$insert into public.id_photos (pass_id, storage_path) values (tests.id('decided_by_rec'), tests.id('decided_by_rec') || '/x.jpg')$$,
  '42501', null, 'guard cannot attach to an already decided request');
select throws_ok(
  $$insert into public.id_photos (pass_id, storage_path, uploaded_by) values (tests.id('gate_pending'), 'spoof.jpg', tests.id('guard2'))$$,
  '42501', null, 'guard cannot set uploaded_by');
select throws_ok(
  $$insert into public.id_photos (pass_id, storage_path, delete_after) values (tests.id('gate_pending'), 'keep.jpg', now() + interval '10 years')$$,
  '42501', null, 'guard cannot extend retention');
select is((select count(*)::int from public.id_photos), 0, 'guard cannot read id_photos');
select throws_ok($$delete from public.id_photos$$, '42501', null, 'guard cannot delete id_photos');
reset role;
select is((select uploaded_by from public.id_photos where storage_path = tests.id('gate_pending') || '/new.jpg'),
          tests.id('guard'), 'uploaded_by is the guard');

select tests.authenticate_as('guard2');
select throws_ok(
  $$insert into public.id_photos (pass_id, storage_path) values (tests.id('gate_pending'), tests.id('gate_pending') || '/y.jpg')$$,
  '42501', null, 'another guard cannot attach to someone else''s request');
reset role;

select tests.authenticate_as('staff');
select throws_ok(
  $$insert into public.id_photos (pass_id, storage_path) values (tests.id('gate_pending'), 'z.jpg')$$,
  '42501', null, 'staff cannot insert id_photos');
select is((select count(*)::int from public.id_photos), 0, 'staff cannot read id_photos');
reset role;

select tests.authenticate_as('receptionist');
select ok(exists (select 1 from public.id_photos where id = tests.id('photo_pending')), 'receptionist reads photo of a pending request');
select ok(exists (select 1 from public.id_photos where id = tests.id('photo_rec')), 'receptionist reads photo of a request they decided');
select ok(not exists (select 1 from public.id_photos where id = tests.id('photo_admin')),
          'receptionist cannot read photo of a request someone else decided');
select throws_ok(
  $$insert into public.id_photos (pass_id, storage_path) values (tests.id('web_pending'), 'r.jpg')$$,
  '42501', null, 'receptionist cannot attach to a request they did not create');
reset role;

select tests.authenticate_as('admin');
select is((select count(*)::int from public.id_photos), tests.total('id_photos') + 1, 'admin reads all id_photos');
reset role;

select tests.authenticate_anon();
select throws_ok('select * from public.id_photos', '42501', null, 'anon cannot read id_photos');
reset role;

-- ---------------------------------------------------------------------------
-- storage bucket id-photos
-- ---------------------------------------------------------------------------
select is((select public from storage.buckets where id = 'id-photos'), false, 'id-photos bucket is private');

-- Existing objects for the fixture photos.
insert into storage.objects (bucket_id, name)
select 'id-photos', storage_path from public.id_photos;

select tests.authenticate_as('guard');
select lives_ok(
  $$insert into storage.objects (bucket_id, name) values ('id-photos', tests.id('gate_pending') || '/upload.jpg')$$,
  'guard uploads to own pending gate request folder');
select throws_ok(
  $$insert into storage.objects (bucket_id, name) values ('id-photos', tests.id('web_pending') || '/upload.jpg')$$,
  '42501', null, 'guard cannot upload into another request folder');
select throws_ok(
  $$insert into storage.objects (bucket_id, name) values ('id-photos', 'not-a-uuid/upload.jpg')$$,
  '42501', null, 'guard cannot upload outside a pass folder');
select is((select count(*)::int from storage.objects where bucket_id = 'id-photos'), 0, 'guard cannot list or download photos');
reset role;

select tests.authenticate_as('receptionist');
select ok(exists (select 1 from storage.objects where name = tests.id('gate_pending') || '/a.jpg'),
          'receptionist downloads photo of a pending request');
select ok(exists (select 1 from storage.objects where name = tests.id('decided_by_rec') || '/b.jpg'),
          'receptionist downloads photo of a request they decided');
select ok(not exists (select 1 from storage.objects where name = tests.id('decided_by_admin') || '/c.jpg'),
          'receptionist cannot download photo of a request someone else decided');
reset role;

select tests.authenticate_as('admin');
select ok(exists (select 1 from storage.objects where name = tests.id('decided_by_admin') || '/c.jpg'),
          'admin downloads any photo');
reset role;

select tests.authenticate_as('staff');
select is((select count(*)::int from storage.objects where bucket_id = 'id-photos'), 0, 'staff cannot see photos');
select throws_ok(
  $$insert into storage.objects (bucket_id, name) values ('id-photos', tests.id('gate_pending') || '/s.jpg')$$,
  '42501', null, 'staff cannot upload photos');
reset role;

select * from finish();
rollback;
