alter table public.prayer_requests
  add column if not exists is_private boolean not null default false;

create index if not exists prayer_requests_is_private_idx
  on public.prayer_requests(is_private);

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
  and pr.is_private = false
group by pr.id, up.first_name;

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
  pr.is_private
from public.prayer_requests pr
left join public.user_profile up on up.id = pr.user_id
left join auth.users users on users.id = pr.user_id
left join public.prayer_request_reactions prr on prr.prayer_request_id = pr.id
group by pr.id, up.first_name, up.last_name, users.email;

grant all on table public.prayer_requests_public_view to anon;
grant all on table public.prayer_requests_public_view to authenticated;
grant all on table public.prayer_requests_public_view to service_role;

grant all on table public.prayer_requests_admin_view to anon;
grant all on table public.prayer_requests_admin_view to authenticated;
grant all on table public.prayer_requests_admin_view to service_role;
