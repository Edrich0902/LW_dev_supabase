create table if not exists public.app_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null,
  title text not null,
  body text not null,
  status text not null default 'open',
  admin_note text,
  device_os text,
  device_model text,
  app_version text,
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamp with time zone,
  resolved_by uuid references auth.users(id) on delete set null,
  resolved_at timestamp with time zone,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint app_feedback_status_check
    check (status in ('open', 'under_review', 'planned', 'resolved', 'closed')),
  constraint app_feedback_category_check
    check (category in ('bug_report', 'feature_request', 'improvement', 'other'))
);

create index if not exists app_feedback_user_created_idx
  on public.app_feedback(user_id, created_at desc);

create index if not exists app_feedback_status_created_idx
  on public.app_feedback(status, created_at desc);

create index if not exists app_feedback_category_created_idx
  on public.app_feedback(category, created_at desc);

create or replace trigger handle_app_feedback_updated_at
  before update on public.app_feedback
  for each row execute function extensions.moddatetime('updated_at');

create or replace view public.app_feedback_owner_view as
select
  af.id,
  af.user_id,
  af.category,
  af.title,
  af.body,
  af.status,
  af.admin_note,
  af.device_os,
  af.device_model,
  af.app_version,
  af.reviewed_at,
  af.resolved_at,
  af.created_at,
  af.updated_at
from public.app_feedback af;

create or replace view public.app_feedback_admin_view as
select
  af.id,
  af.user_id,
  up.first_name,
  up.last_name,
  users.email,
  af.category,
  af.title,
  af.body,
  af.status,
  af.admin_note,
  af.device_os,
  af.device_model,
  af.app_version,
  af.reviewed_by,
  af.reviewed_at,
  af.resolved_by,
  af.resolved_at,
  af.created_at,
  af.updated_at
from public.app_feedback af
left join public.user_profile up on up.id = af.user_id
left join auth.users users on users.id = af.user_id;

alter table public.app_feedback enable row level security;

create policy "allow app feedback owner reads"
  on public.app_feedback
  for select to authenticated
  using (auth.uid() = user_id);

create policy "allow app feedback owner inserts"
  on public.app_feedback
  for insert to authenticated
  with check (
    auth.uid() = user_id
    and status = 'open'
    and reviewed_at is null
    and reviewed_by is null
    and resolved_at is null
    and resolved_by is null
  );

create policy "allow all app feedback access to super admin"
  on public.app_feedback
  for all to authenticated
  using (public.is_super_admin(auth.uid(), 'super_admin'::text))
  with check (public.is_super_admin(auth.uid(), 'super_admin'::text));

grant all on table public.app_feedback to anon;
grant all on table public.app_feedback to authenticated;
grant all on table public.app_feedback to service_role;

grant all on table public.app_feedback_owner_view to anon;
grant all on table public.app_feedback_owner_view to authenticated;
grant all on table public.app_feedback_owner_view to service_role;

grant all on table public.app_feedback_admin_view to anon;
grant all on table public.app_feedback_admin_view to authenticated;
grant all on table public.app_feedback_admin_view to service_role;
