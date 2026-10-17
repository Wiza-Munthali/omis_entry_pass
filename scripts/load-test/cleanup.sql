-- Removes everything seed.sql and scan.mjs created (rows tagged LOADTEST-).
begin;
set local session_replication_role = replica;

create temp table lt_passes on commit drop as
  select pa.id from public.passes pa join public.people pe on pe.id = pa.person_id
  where pe.id_number like 'LOADTEST-%';

delete from public.audit_log
where (target_table = 'visits' and target_id in (
         select v.id::text from public.visits v where v.pass_id in (select id from lt_passes)))
   or (target_table = 'passes' and target_id in (select id::text from lt_passes));
delete from public.flags where pass_id in (select id from lt_passes);
delete from public.visits where pass_id in (select id from lt_passes);
delete from public.passes where id in (select id from lt_passes);
delete from public.vehicles where person_id in (select id from public.people where id_number like 'LOADTEST-%');
delete from public.people where id_number like 'LOADTEST-%';

commit;
select 'load-test data removed';
