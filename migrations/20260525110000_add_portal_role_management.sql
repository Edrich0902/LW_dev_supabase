create unique index if not exists roles_role_normalized_idx
  on public.roles (lower(btrim(role)));

create or replace function public.get_admin_users()
returns table (
  id uuid,
  first_name character varying,
  last_name character varying,
  updated_at timestamp with time zone,
  created_at timestamp with time zone,
  role_id uuid,
  role text,
  is_baptized boolean,
  is_member boolean,
  address character varying,
  email text,
  profile_public_id text,
  profile_url text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_super_admin(auth.uid(), 'super_admin') then
    raise exception 'Only super admins can read users';
  end if;

  return query
  select
    up.id,
    up.first_name,
    up.last_name,
    up.updated_at,
    up.created_at,
    assigned_role.role_id,
    assigned_role.role,
    up.is_baptized,
    up.is_member,
    up.address,
    users.email::text,
    up.profile_public_id,
    up.profile_url
  from public.user_profile up
  join auth.users users on up.id = users.id
  left join lateral (
    select
      r.id as role_id,
      r.role,
      ur.created_at
    from public.user_roles ur
    join public.roles r on r.id = ur.role_id
    where ur.user_id = up.id
    order by ur.created_at desc nulls last, r.created_at desc nulls last, r.role asc
    limit 1
  ) assigned_role on true;
end;
$$;

grant execute on function public.get_admin_users() to authenticated;
grant execute on function public.get_admin_users() to service_role;

create or replace function public.get_admin_user_profile(target_user_id uuid default auth.uid())
returns table (
  id uuid,
  first_name character varying,
  last_name character varying,
  updated_at timestamp with time zone,
  created_at timestamp with time zone,
  role_id uuid,
  role text,
  is_baptized boolean,
  is_member boolean,
  address character varying,
  email text,
  profile_public_id text,
  profile_url text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_super_admin(auth.uid(), 'super_admin') then
    raise exception 'Only super admins can read users';
  end if;

  return query
  select admin_users.*
  from public.get_admin_users() as admin_users
  where admin_users.id = target_user_id;
end;
$$;

grant execute on function public.get_admin_user_profile(uuid) to authenticated;
grant execute on function public.get_admin_user_profile(uuid) to service_role;

create or replace function public.create_role(role_name text)
returns public.roles
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_role text;
  created_role public.roles;
begin
  if not public.is_super_admin(auth.uid(), 'super_admin') then
    raise exception 'Only super admins can create roles';
  end if;

  normalized_role := lower(trim(coalesce(role_name, '')));
  normalized_role := regexp_replace(normalized_role, '\s+', '_', 'g');
  normalized_role := regexp_replace(normalized_role, '[^a-z0-9_]', '', 'g');

  if normalized_role = '' then
    raise exception 'Role name is required';
  end if;

  if normalized_role !~ '^[a-z][a-z0-9_]*$' then
    raise exception 'Role name must start with a letter and contain only lowercase letters, numbers, and underscores';
  end if;

  if exists (
    select 1
    from public.roles
    where lower(btrim(role)) = normalized_role
  ) then
    raise exception 'Role already exists';
  end if;

  insert into public.roles (role)
  values (normalized_role)
  returning * into created_role;

  return created_role;
end;
$$;

grant execute on function public.create_role(text) to authenticated;
grant execute on function public.create_role(text) to service_role;

create or replace function public.set_user_role(target_user_id uuid, target_role_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_super_admin(auth.uid(), 'super_admin') then
    raise exception 'Only super admins can assign roles';
  end if;

  if target_user_id is null then
    raise exception 'User id is required';
  end if;

  if target_role_id is null then
    raise exception 'Role id is required';
  end if;

  if not exists (
    select 1
    from auth.users
    where id = target_user_id
  ) then
    raise exception 'User not found';
  end if;

  if not exists (
    select 1
    from public.roles
    where id = target_role_id
  ) then
    raise exception 'Role not found';
  end if;

  delete from public.user_roles
  where user_id = target_user_id;

  insert into public.user_roles (user_id, role_id)
  values (target_user_id, target_role_id);
end;
$$;

grant execute on function public.set_user_role(uuid, uuid) to authenticated;
grant execute on function public.set_user_role(uuid, uuid) to service_role;
