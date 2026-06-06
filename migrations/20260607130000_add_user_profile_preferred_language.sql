alter table public.user_profile
add column if not exists preferred_language text;

create or replace view public.user_profile_view as
select
  user_profile.id,
  user_profile.first_name,
  user_profile.last_name,
  user_profile.updated_at,
  user_profile.created_at,
  roles.role,
  user_profile.is_baptized,
  user_profile.is_member,
  user_profile.address,
  users.email,
  user_profile.profile_public_id,
  user_profile.profile_url,
  user_profile.preferred_language
from public.user_profile
join auth.users on user_profile.id = users.id
join public.user_roles on user_profile.id = user_roles.user_id
join public.roles on user_roles.role_id = roles.id;
