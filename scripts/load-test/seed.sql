-- Load-test data for record_scan (scripts/load-test/scan.mjs). Run against local or a
-- staging project, never production. Everything is tagged LOADTEST- so cleanup.sql can
-- remove it. Triggers are off while seeding: no emails, pushes or audit rows for test data.
--
-- About a month of a busy site: 3,000 pass holders, 60,000 past visits.
begin;
set local session_replication_role = replica;

insert into public.people (full_name, id_number, phone)
select 'Load Test ' || i, 'LOADTEST-' || i, '+265 000 ' || lpad(i::text, 6, '0')
from generate_series(1, 3000) i;

insert into public.vehicles (person_id, plate)
select id, 'LT' || substr(id_number, 10)
from public.people
where id_number like 'LOADTEST-%' and substr(id_number, 10)::int % 2 = 0;

insert into public.passes (person_id, vehicle_id, type, status, valid_from, valid_until, source, decided_at)
select pe.id, ve.id, 'staff', 'approved', now() - interval '60 days', now() + interval '300 days', 'web', now() - interval '60 days'
from public.people pe
left join public.vehicles ve on ve.person_id = pe.id
where pe.id_number like 'LOADTEST-%';

-- Closed visits over the last 30 days, spread across gates and working hours.
with load_passes as (
  select pa.id, pa.person_id, row_number() over () as n
  from public.passes pa join public.people pe on pe.id = pa.person_id
  where pe.id_number like 'LOADTEST-%'
), gates as (
  select id, row_number() over (order by name) as n, count(*) over () as total from public.gates where is_active
)
insert into public.visits (pass_id, person_id, gate_id, entry_at, exit_at)
select lp.id, lp.person_id, g.id, t.entry_at, t.entry_at + interval '8 hours'
from generate_series(1, 60000) i
join load_passes lp on lp.n = 1 + (i % 3000)
join gates g on g.n = 1 + (i % g.total)
cross join lateral (
  select date_trunc('day', now()) - ((1 + i % 30) * interval '1 day') + interval '6 hours'
         + (i % 600) * interval '1 minute' as entry_at
) t;

commit;
analyze public.people, public.vehicles, public.passes, public.visits;

select count(*) || ' load-test passes' from public.passes pa join public.people pe on pe.id = pa.person_id
where pe.id_number like 'LOADTEST-%';
