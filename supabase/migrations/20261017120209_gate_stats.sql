-- OMIS Entry — counts for the gate app home screen (docs/SPEC.md → G3 Guard home).
-- Guards may only read open visits, so they cannot count today's entries themselves;
-- this returns the numbers without exposing the rows.

create function public.gate_stats(p_gate_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_today_start timestamptz := private.local_midnight(private.local_today());
begin
  if not private.has_role('guard') then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'on_site', (select count(*) from public.visits where exit_at is null),
    'entries_today', (select count(*) from public.visits where entry_at >= v_today_start),
    'entries_today_at_gate', case when p_gate_id is null then null else
      (select count(*) from public.visits where entry_at >= v_today_start and gate_id = p_gate_id) end
  );
end;
$$;

comment on function public.gate_stats is 'On-site count and entries today (Africa/Blantyre) for the gate app. Operators only.';

revoke execute on function public.gate_stats(uuid) from public, anon;
grant execute on function public.gate_stats(uuid) to authenticated;
