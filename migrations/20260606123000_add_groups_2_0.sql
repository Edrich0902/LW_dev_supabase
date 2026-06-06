create table if not exists public.group_memberships (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null,
  status text not null,
  requested_at timestamp with time zone,
  responded_at timestamp with time zone,
  responded_by uuid references auth.users(id) on delete set null,
  joined_at timestamp with time zone,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint group_memberships_group_user_unique unique (group_id, user_id),
  constraint group_memberships_role_check check (role in ('leader', 'member')),
  constraint group_memberships_status_check
    check (status in ('pending', 'active', 'declined', 'left', 'removed')),
  constraint group_memberships_leader_active_check check (role <> 'leader' or status = 'active'),
  constraint group_memberships_role_status_check
    check (
      (role = 'leader' and status = 'active')
      or (role = 'member' and status in ('pending', 'active', 'declined', 'left', 'removed'))
    )
);

create index if not exists group_memberships_group_id_idx
  on public.group_memberships(group_id);

create index if not exists group_memberships_user_id_idx
  on public.group_memberships(user_id);

create index if not exists group_memberships_group_status_idx
  on public.group_memberships(group_id, status);

create index if not exists group_memberships_group_role_status_idx
  on public.group_memberships(group_id, role, status);

create or replace trigger handle_group_memberships_updated_at
  before update on public.group_memberships
  for each row execute function extensions.moddatetime('updated_at');

create or replace function public.is_active_group_leader(
  target_group_id uuid,
  target_user_id uuid default auth.uid()
)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.group_memberships gm
    where gm.group_id = target_group_id
      and gm.user_id = target_user_id
      and gm.role = 'leader'
      and gm.status = 'active'
  );
$$;

grant execute on function public.is_active_group_leader(uuid, uuid) to authenticated;
grant execute on function public.is_active_group_leader(uuid, uuid) to service_role;

create or replace function public.can_view_group_whatsapp(
  target_group_id uuid,
  target_user_id uuid default auth.uid()
)
returns boolean
language sql
security definer
set search_path = public
as $$
  select
    public.is_super_admin(target_user_id, 'super_admin')
    or exists (
      select 1
      from public.group_memberships gm
      where gm.group_id = target_group_id
        and gm.user_id = target_user_id
        and gm.status = 'active'
    );
$$;

grant execute on function public.can_view_group_whatsapp(uuid, uuid) to authenticated;
grant execute on function public.can_view_group_whatsapp(uuid, uuid) to service_role;

create or replace view public.groups_public_view
with (security_invoker = on) as
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

create or replace view public.groups_admin_view
with (security_invoker = on) as
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

create or replace view public.group_memberships_view
with (security_invoker = on) as
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

create or replace function public.request_group_join(target_group_id uuid)
returns public.group_memberships
language plpgsql
security definer
set search_path = public
as $$
declare
  membership public.group_memberships;
  now_utc timestamp with time zone := now();
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  insert into public.group_memberships (
    group_id,
    user_id,
    role,
    status,
    requested_at,
    responded_at,
    responded_by,
    joined_at
  )
  values (
    target_group_id,
    auth.uid(),
    'member',
    'pending',
    now_utc,
    null,
    null,
    null
  )
  on conflict (group_id, user_id)
  do update set
    role = 'member',
    status = 'pending',
    requested_at = now_utc,
    responded_at = null,
    responded_by = null,
    joined_at = null,
    updated_at = now_utc
  where public.group_memberships.status in ('declined', 'left', 'removed')
  returning * into membership;

  if membership.id is null then
    raise exception 'A pending or active membership already exists for this user.';
  end if;

  return membership;
end;
$$;

create or replace function public.cancel_group_join_request(target_group_id uuid)
returns public.group_memberships
language plpgsql
security definer
set search_path = public
as $$
declare
  membership public.group_memberships;
begin
  update public.group_memberships gm
  set
    status = 'left',
    responded_at = now(),
    responded_by = auth.uid(),
    updated_at = now()
  where gm.group_id = target_group_id
    and gm.user_id = auth.uid()
    and gm.status = 'pending'
  returning * into membership;

  if membership.id is null then
    raise exception 'No pending join request found.';
  end if;

  return membership;
end;
$$;

create or replace function public.approve_group_membership(
  target_group_id uuid,
  target_user_id uuid
)
returns public.group_memberships
language plpgsql
security definer
set search_path = public
as $$
declare
  membership public.group_memberships;
  actor_id uuid := auth.uid();
begin
  if not (
    public.is_super_admin(actor_id, 'super_admin')
    or public.is_active_group_leader(target_group_id, actor_id)
  ) then
    raise exception 'Not allowed to approve memberships for this group.';
  end if;

  update public.group_memberships gm
  set
    role = 'member',
    status = 'active',
    responded_at = now(),
    responded_by = actor_id,
    joined_at = coalesce(gm.joined_at, now()),
    updated_at = now()
  where gm.group_id = target_group_id
    and gm.user_id = target_user_id
    and gm.status = 'pending'
  returning * into membership;

  if membership.id is null then
    raise exception 'No pending membership found to approve.';
  end if;

  return membership;
end;
$$;

create or replace function public.decline_group_membership(
  target_group_id uuid,
  target_user_id uuid
)
returns public.group_memberships
language plpgsql
security definer
set search_path = public
as $$
declare
  membership public.group_memberships;
  actor_id uuid := auth.uid();
begin
  if not (
    public.is_super_admin(actor_id, 'super_admin')
    or public.is_active_group_leader(target_group_id, actor_id)
  ) then
    raise exception 'Not allowed to decline memberships for this group.';
  end if;

  update public.group_memberships gm
  set
    role = 'member',
    status = 'declined',
    responded_at = now(),
    responded_by = actor_id,
    joined_at = null,
    updated_at = now()
  where gm.group_id = target_group_id
    and gm.user_id = target_user_id
    and gm.status = 'pending'
  returning * into membership;

  if membership.id is null then
    raise exception 'No pending membership found to decline.';
  end if;

  return membership;
end;
$$;

create or replace function public.leave_group(target_group_id uuid)
returns public.group_memberships
language plpgsql
security definer
set search_path = public
as $$
declare
  membership public.group_memberships;
begin
  update public.group_memberships gm
  set
    role = 'member',
    status = 'left',
    responded_at = now(),
    responded_by = auth.uid(),
    updated_at = now()
  where gm.group_id = target_group_id
    and gm.user_id = auth.uid()
    and gm.status = 'active'
  returning * into membership;

  if membership.id is null then
    raise exception 'No active membership found to leave.';
  end if;

  return membership;
end;
$$;

create or replace function public.remove_group_member(
  target_group_id uuid,
  target_user_id uuid
)
returns public.group_memberships
language plpgsql
security definer
set search_path = public
as $$
declare
  membership public.group_memberships;
  actor_id uuid := auth.uid();
begin
  if not (
    public.is_super_admin(actor_id, 'super_admin')
    or public.is_active_group_leader(target_group_id, actor_id)
  ) then
    raise exception 'Not allowed to remove members from this group.';
  end if;

  update public.group_memberships gm
  set
    role = 'member',
    status = 'removed',
    responded_at = now(),
    responded_by = actor_id,
    joined_at = null,
    updated_at = now()
  where gm.group_id = target_group_id
    and gm.user_id = target_user_id
    and gm.status = 'active'
  returning * into membership;

  if membership.id is null then
    raise exception 'No active member found to remove.';
  end if;

  return membership;
end;
$$;

create or replace function public.set_group_leader(
  target_group_id uuid,
  target_user_id uuid,
  should_be_leader boolean default true
)
returns public.group_memberships
language plpgsql
security definer
set search_path = public
as $$
declare
  membership public.group_memberships;
  actor_id uuid := auth.uid();
  now_utc timestamp with time zone := now();
begin
  if not (
    public.is_super_admin(actor_id, 'super_admin')
    or public.is_active_group_leader(target_group_id, actor_id)
  ) then
    raise exception 'Not allowed to update leaders for this group.';
  end if;

  if should_be_leader then
    insert into public.group_memberships (
      group_id,
      user_id,
      role,
      status,
      requested_at,
      responded_at,
      responded_by,
      joined_at
    )
    values (
      target_group_id,
      target_user_id,
      'leader',
      'active',
      now_utc,
      now_utc,
      actor_id,
      now_utc
    )
    on conflict (group_id, user_id)
    do update set
      role = 'leader',
      status = 'active',
      responded_at = now_utc,
      responded_by = actor_id,
      joined_at = coalesce(public.group_memberships.joined_at, now_utc),
      updated_at = now_utc
    returning * into membership;
  else
    update public.group_memberships gm
    set
      role = 'member',
      status = 'active',
      responded_at = now_utc,
      responded_by = actor_id,
      joined_at = coalesce(gm.joined_at, now_utc),
      updated_at = now_utc
    where gm.group_id = target_group_id
      and gm.user_id = target_user_id
      and gm.role = 'leader'
      and gm.status = 'active'
    returning * into membership;

    if membership.id is null then
      raise exception 'No active leader found to update.';
    end if;
  end if;

  return membership;
end;
$$;

create or replace function public.update_group_from_leader(
  target_group_id uuid,
  target_title text,
  target_description text,
  target_whatsapp_link text,
  target_location text,
  target_banner_url text,
  target_banner_public_id text
)
returns public.groups
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_group public.groups;
  actor_id uuid := auth.uid();
begin
  if not (
    public.is_super_admin(actor_id, 'super_admin')
    or public.is_active_group_leader(target_group_id, actor_id)
  ) then
    raise exception 'Not allowed to update this group.';
  end if;

  update public.groups g
  set
    title = target_title,
    description = target_description,
    "whatsappLink" = target_whatsapp_link,
    location = target_location,
    banner_url = target_banner_url,
    banner_public_id = target_banner_public_id,
    updated_at = now()
  where g.id = target_group_id
  returning * into updated_group;

  return updated_group;
end;
$$;

alter table public.group_memberships enable row level security;

create policy "allow membership reads to super_admin leader or owner"
  on public.group_memberships
  for select to authenticated
  using (
    public.is_super_admin(auth.uid(), 'super_admin')
    or user_id = auth.uid()
    or public.is_active_group_leader(group_id, auth.uid())
  );

create policy "allow membership self insert for request flow"
  on public.group_memberships
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and role = 'member'
    and status = 'pending'
  );

create policy "allow membership updates to super_admin leader or owner"
  on public.group_memberships
  for update to authenticated
  using (
    public.is_super_admin(auth.uid(), 'super_admin')
    or user_id = auth.uid()
    or public.is_active_group_leader(group_id, auth.uid())
  )
  with check (
    public.is_super_admin(auth.uid(), 'super_admin')
    or user_id = auth.uid()
    or public.is_active_group_leader(group_id, auth.uid())
  );

grant all on table public.group_memberships to authenticated;
grant all on table public.group_memberships to service_role;

grant all on table public.groups_public_view to anon;
grant all on table public.groups_public_view to authenticated;
grant all on table public.groups_public_view to service_role;

grant all on table public.groups_admin_view to authenticated;
grant all on table public.groups_admin_view to service_role;

grant all on table public.group_memberships_view to authenticated;
grant all on table public.group_memberships_view to service_role;

grant execute on function public.request_group_join(uuid) to authenticated;
grant execute on function public.request_group_join(uuid) to service_role;
grant execute on function public.cancel_group_join_request(uuid) to authenticated;
grant execute on function public.cancel_group_join_request(uuid) to service_role;
grant execute on function public.approve_group_membership(uuid, uuid) to authenticated;
grant execute on function public.approve_group_membership(uuid, uuid) to service_role;
grant execute on function public.decline_group_membership(uuid, uuid) to authenticated;
grant execute on function public.decline_group_membership(uuid, uuid) to service_role;
grant execute on function public.leave_group(uuid) to authenticated;
grant execute on function public.leave_group(uuid) to service_role;
grant execute on function public.remove_group_member(uuid, uuid) to authenticated;
grant execute on function public.remove_group_member(uuid, uuid) to service_role;
grant execute on function public.set_group_leader(uuid, uuid, boolean) to authenticated;
grant execute on function public.set_group_leader(uuid, uuid, boolean) to service_role;
grant execute on function public.update_group_from_leader(uuid, text, text, text, text, text, text)
  to authenticated;
grant execute on function public.update_group_from_leader(uuid, text, text, text, text, text, text)
  to service_role;
