create table if not exists public.prayer_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null,
  body text not null,
  is_anonymous boolean not null default false,
  status text not null default 'pending',
  moderation_note text,
  approved_at timestamp with time zone,
  approved_by uuid references auth.users(id) on delete set null,
  rejected_at timestamp with time zone,
  rejected_by uuid references auth.users(id) on delete set null,
  resolved_at timestamp with time zone,
  resolved_by uuid references auth.users(id) on delete set null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint prayer_requests_status_check
    check (status in ('pending', 'approved', 'rejected', 'resolved')),
  constraint prayer_requests_category_check
    check (category in (
      'healing',
      'family',
      'provision',
      'guidance',
      'spiritual_growth',
      'thanksgiving',
      'other'
    ))
);

create index if not exists prayer_requests_user_created_idx
  on public.prayer_requests(user_id, created_at desc);

create index if not exists prayer_requests_status_created_idx
  on public.prayer_requests(status, created_at desc);

create index if not exists prayer_requests_category_created_idx
  on public.prayer_requests(category, created_at desc);

create table if not exists public.prayer_request_reactions (
  prayer_request_id uuid not null references public.prayer_requests(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamp with time zone not null default now(),
  primary key (prayer_request_id, user_id)
);

create index if not exists prayer_request_reactions_request_idx
  on public.prayer_request_reactions(prayer_request_id);

create or replace view public.prayer_requests_public_view as
select
  pr.id,
  pr.user_id,
  pr.category,
  pr.body,
  pr.is_anonymous,
  pr.status,
  pr.created_at,
  pr.updated_at,
  coalesce(
    case
      when pr.is_anonymous then 'Anoniem'
      else up.first_name
    end,
    'Anoniem'
  ) as display_name,
  count(prr.user_id)::int as reaction_count
from public.prayer_requests pr
left join public.user_profile up on up.id = pr.user_id
left join public.prayer_request_reactions prr on prr.prayer_request_id = pr.id
where pr.status = 'approved'
  and pr.resolved_at is null
group by pr.id, up.first_name;

create or replace view public.prayer_requests_owner_view as
select
  pr.id,
  pr.user_id,
  pr.category,
  pr.body,
  pr.is_anonymous,
  pr.status,
  pr.moderation_note,
  pr.approved_at,
  pr.approved_by,
  pr.rejected_at,
  pr.rejected_by,
  pr.resolved_at,
  pr.resolved_by,
  pr.created_at,
  pr.updated_at,
  count(prr.user_id)::int as reaction_count
from public.prayer_requests pr
left join public.prayer_request_reactions prr on prr.prayer_request_id = pr.id
group by pr.id;

create or replace view public.prayer_requests_admin_view as
select
  pr.id,
  pr.user_id,
  up.first_name,
  up.last_name,
  users.email,
  pr.category,
  pr.body,
  pr.is_anonymous,
  pr.status,
  pr.moderation_note,
  pr.approved_at,
  pr.approved_by,
  pr.rejected_at,
  pr.rejected_by,
  pr.resolved_at,
  pr.resolved_by,
  pr.created_at,
  pr.updated_at,
  count(prr.user_id)::int as reaction_count
from public.prayer_requests pr
left join public.user_profile up on up.id = pr.user_id
left join auth.users users on users.id = pr.user_id
left join public.prayer_request_reactions prr on prr.prayer_request_id = pr.id
group by pr.id, up.first_name, up.last_name, users.email;

alter table public.prayer_requests enable row level security;
alter table public.prayer_request_reactions enable row level security;

create policy "allow public prayer request reads for authenticated users"
  on public.prayer_requests
  for select to authenticated
  using (
    status = 'approved'
    and resolved_at is null
  );

create policy "allow prayer request owner reads"
  on public.prayer_requests
  for select to authenticated
  using (auth.uid() = user_id);

create policy "allow prayer request owner inserts"
  on public.prayer_requests
  for insert to authenticated
  with check (
    auth.uid() = user_id
    and status = 'pending'
    and approved_at is null
    and approved_by is null
    and rejected_at is null
    and rejected_by is null
    and resolved_at is null
    and resolved_by is null
  );

create policy "allow prayer request owner resolve updates"
  on public.prayer_requests
  for update to authenticated
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and status = 'resolved'
    and resolved_at is not null
    and resolved_by = auth.uid()
  );

create policy "allow all prayer request access to super admin"
  on public.prayer_requests
  for all to authenticated
  using (public.is_super_admin(auth.uid(), 'super_admin'::text))
  with check (public.is_super_admin(auth.uid(), 'super_admin'::text));

create policy "allow prayer reaction owner reads"
  on public.prayer_request_reactions
  for select to authenticated
  using (auth.uid() = user_id);

create policy "allow prayer reaction owner inserts"
  on public.prayer_request_reactions
  for insert to authenticated
  with check (auth.uid() = user_id);

create policy "allow prayer reaction owner deletes"
  on public.prayer_request_reactions
  for delete to authenticated
  using (auth.uid() = user_id);

create policy "allow all prayer reaction access to super admin"
  on public.prayer_request_reactions
  for all to authenticated
  using (public.is_super_admin(auth.uid(), 'super_admin'::text))
  with check (public.is_super_admin(auth.uid(), 'super_admin'::text));

grant all on table public.prayer_requests to anon;
grant all on table public.prayer_requests to authenticated;
grant all on table public.prayer_requests to service_role;

grant all on table public.prayer_request_reactions to anon;
grant all on table public.prayer_request_reactions to authenticated;
grant all on table public.prayer_request_reactions to service_role;

grant all on table public.prayer_requests_public_view to anon;
grant all on table public.prayer_requests_public_view to authenticated;
grant all on table public.prayer_requests_public_view to service_role;

grant all on table public.prayer_requests_owner_view to anon;
grant all on table public.prayer_requests_owner_view to authenticated;
grant all on table public.prayer_requests_owner_view to service_role;

grant all on table public.prayer_requests_admin_view to anon;
grant all on table public.prayer_requests_admin_view to authenticated;
grant all on table public.prayer_requests_admin_view to service_role;
