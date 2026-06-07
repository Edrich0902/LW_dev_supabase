-- 1. Add praise_report column to prayer_requests
alter table public.prayer_requests
add column if not exists praise_report text;

-- 2. Update RLS read policy on prayer_requests to allow viewing of resolved requests with praise reports
drop policy if exists "allow public prayer request reads for authenticated users" on public.prayer_requests;

create policy "allow public prayer request reads for authenticated users"
  on public.prayer_requests
  for select to authenticated
  using (
    is_private = false
    and (
      (status = 'approved' and resolved_at is null)
      or 
      (status = 'resolved' and praise_report is not null and trim(praise_report) <> '')
    )
  );

-- Drop old views to prevent PG column reordering/renaming errors
drop view if exists public.prayer_requests_public_view;
drop view if exists public.prayer_requests_owner_view;
drop view if exists public.prayer_requests_admin_view;

-- 3. Recreate public view to include praise_report and fetch resolved entries with praise reports
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
  pr.praise_report,
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
where pr.is_private = false
  and (
    (pr.status = 'approved' and pr.resolved_at is null)
    or
    (pr.status = 'resolved' and pr.praise_report is not null and trim(pr.praise_report) <> '')
  )
group by pr.id, up.first_name, pr.praise_report;

-- 4. Recreate owner view to include praise_report
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
  pr.is_private,
  pr.praise_report,
  count(prr.user_id)::int as reaction_count
from public.prayer_requests pr
left join public.prayer_request_reactions prr on prr.prayer_request_id = pr.id
group by pr.id, pr.praise_report;

-- 5. Recreate admin view to include praise_report
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
  count(prr.user_id)::int as reaction_count,
  pr.is_private,
  pr.praise_report
from public.prayer_requests pr
left join public.user_profile up on up.id = pr.user_id
left join auth.users users on users.id = pr.user_id
left join public.prayer_request_reactions prr on prr.prayer_request_id = pr.id
group by pr.id, up.first_name, up.last_name, users.email, pr.praise_report;
