-- Resolve the default signup role by name instead of a hardcoded UUID.
-- Requires a row in public.roles with role = 'user' (create manually).

create or replace function public.add_user_default_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  default_role_id uuid;
begin
  select r.id
  into default_role_id
  from public.roles r
  where lower(btrim(r.role)) = 'user'
  limit 1;

  if default_role_id is null then
    raise exception 'Default role "user" not found in public.roles';
  end if;

  insert into public.user_roles (user_id, role_id)
  values (new.id, default_role_id);

  return new;
end;
$$;
