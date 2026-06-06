create or replace view public.groups_public_view as
select
  g.id,
  g.title,
  g.description,
  g.type,
  case
    when public.can_view_group_whatsapp(g.id, auth.uid()) then g."whatsappLink"
    else null
  end as "whatsappLink",
  g.location,
  g.banner_url,
  g.banner_public_id,
  g.created_at,
  g.updated_at,
  coalesce(leader_counts.leader_count, 0) as leader_count,
  coalesce(member_counts.member_count, 0) as member_count,
  coalesce(pending_counts.pending_count, 0) as pending_count,
  current_membership.status as membership_status,
  coalesce(
    current_membership.role = 'leader' and current_membership.status = 'active',
    false
  ) as "isLeader"
from public.groups g
left join lateral (
  select count(*)::int as leader_count
  from public.group_memberships gm
  where gm.group_id = g.id
    and gm.role = 'leader'
    and gm.status = 'active'
) leader_counts on true
left join lateral (
  select count(*)::int as member_count
  from public.group_memberships gm
  where gm.group_id = g.id
    and gm.role = 'member'
    and gm.status = 'active'
) member_counts on true
left join lateral (
  select count(*)::int as pending_count
  from public.group_memberships gm
  where gm.group_id = g.id
    and gm.status = 'pending'
) pending_counts on true
left join lateral (
  select gm.role, gm.status
  from public.group_memberships gm
  where gm.group_id = g.id
    and gm.user_id = auth.uid()
  limit 1
) current_membership on true;

create or replace view public.groups_admin_view as
select
  g.*,
  coalesce(leader_counts.leader_count, 0) as leader_count,
  coalesce(member_counts.member_count, 0) as member_count,
  coalesce(pending_counts.pending_count, 0) as pending_count
from public.groups g
left join lateral (
  select count(*)::int as leader_count
  from public.group_memberships gm
  where gm.group_id = g.id
    and gm.role = 'leader'
    and gm.status = 'active'
) leader_counts on true
left join lateral (
  select count(*)::int as member_count
  from public.group_memberships gm
  where gm.group_id = g.id
    and gm.role = 'member'
    and gm.status = 'active'
) member_counts on true
left join lateral (
  select count(*)::int as pending_count
  from public.group_memberships gm
  where gm.group_id = g.id
    and gm.status = 'pending'
) pending_counts on true
where public.is_super_admin(auth.uid(), 'super_admin');

create or replace view public.group_memberships_view as
select
  gm.id,
  gm.group_id,
  gm.user_id,
  gm.role,
  gm.status,
  gm.requested_at,
  gm.responded_at,
  gm.responded_by,
  gm.joined_at,
  gm.created_at,
  gm.updated_at,
  up.first_name,
  up.last_name,
  trim(concat_ws(' ', up.first_name, up.last_name)) as full_name,
  users.email::text as email,
  up.profile_public_id,
  up.profile_url,
  responder_profile.first_name as responded_by_first_name,
  responder_profile.last_name as responded_by_last_name,
  trim(concat_ws(' ', responder_profile.first_name, responder_profile.last_name))
    as responded_by_full_name
from public.group_memberships gm
join public.user_profile up on up.id = gm.user_id
join auth.users users on users.id = gm.user_id
left join public.user_profile responder_profile on responder_profile.id = gm.responded_by
where public.is_super_admin(auth.uid(), 'super_admin')
  or gm.user_id = auth.uid()
  or public.is_active_group_leader(gm.group_id, auth.uid());
