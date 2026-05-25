-- Add capacity to events table
alter table public.events add column if not exists capacity integer;

-- Create event_rsvps table
create table if not exists public.event_rsvps (
  id uuid default gen_random_uuid() primary key,
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint event_rsvps_status_check check (status in ('attending', 'interested', 'not_attending')),
  constraint event_rsvps_unique_user_event unique(event_id, user_id)
);

create index if not exists event_rsvps_event_id_idx on public.event_rsvps(event_id);
create index if not exists event_rsvps_user_id_idx on public.event_rsvps(user_id);

create or replace trigger handle_updated_at
  before update on public.event_rsvps
  for each row execute function extensions.moddatetime('updated_at');

-- RLS
alter table public.event_rsvps enable row level security;

create policy "allow read access to authed users" on public.event_rsvps
  for select to authenticated using (true);

create policy "allow owner inserts" on public.event_rsvps
  for insert to authenticated with check (auth.uid() = user_id);

create policy "allow owner updates" on public.event_rsvps
  for update to authenticated using (auth.uid() = user_id);

create policy "allow owner deletes" on public.event_rsvps
  for delete to authenticated using (auth.uid() = user_id);

create policy "allow all access to super admin" on public.event_rsvps
  for all to authenticated
  using (public.is_super_admin(auth.uid(), 'super_admin'))
  with check (public.is_super_admin(auth.uid(), 'super_admin'));

-- Aggregate counts view (queried by Flutter app and portal)
create or replace view public.event_rsvp_summary as
select
  event_id,
  count(*) filter (where status = 'attending')     as attending_count,
  count(*) filter (where status = 'interested')    as interested_count,
  count(*) filter (where status = 'not_attending') as not_attending_count
from public.event_rsvps
group by event_id;

-- Detail view with user info for admin portal (mirrors prayer_requests_admin_view pattern)
create or replace view public.event_rsvp_details_view as
select
  er.id,
  er.event_id,
  er.user_id,
  er.status,
  er.created_at,
  up.first_name,
  up.last_name,
  au.email
from public.event_rsvps er
left join public.user_profile up on up.id = er.user_id
left join auth.users au on au.id = er.user_id;

-- Grants
grant all on table public.event_rsvps to anon, authenticated, service_role;
grant all on table public.event_rsvp_summary to anon, authenticated, service_role;
grant all on table public.event_rsvp_details_view to anon, authenticated, service_role;
