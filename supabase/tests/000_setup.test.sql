-- Smoke test: proves the pgTAP harness runs (`npm run db:test`).
-- Phase 1 adds one test file per RLS policy group.
begin;
create extension if not exists pgtap with schema extensions;
select plan(2);

select has_schema('public');
select has_schema('auth');

select * from finish();
rollback;
