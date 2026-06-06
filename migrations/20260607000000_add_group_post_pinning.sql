-- Add is_pinned column to group_posts
alter table public.group_posts
  add column if not exists is_pinned boolean not null default false;

-- Update index to support pinned-first ordering
drop index if exists public.group_posts_group_id_idx;
create index group_posts_group_id_idx
  on public.group_posts(group_id, is_pinned desc, created_at desc);

-- Recreate group_posts_view to expose is_pinned
-- Drop first because CREATE OR REPLACE cannot reorder existing columns
drop view if exists public.group_posts_view;

create view public.group_posts_view as
select
  gp.id,
  gp.group_id,
  gp.author_user_id,
  gp.title,
  gp.content,
  gp.is_pinned,
  gp.created_at,
  gp.updated_at,
  up.first_name as author_first_name,
  up.last_name as author_last_name,
  trim(concat_ws(' ', up.first_name, up.last_name)) as author_full_name,
  up.profile_public_id as author_profile_public_id,
  up.profile_url as author_profile_url,
  coalesce(reaction_counts.reaction_count, 0) as reaction_count,
  coalesce(reaction_counts.amen_count, 0) as amen_count,
  coalesce(reaction_counts.prayer_count, 0) as prayer_count,
  coalesce(reaction_counts.heart_count, 0) as heart_count,
  current_user_reaction.reaction_type as current_user_reaction,
  (gp.author_user_id = auth.uid()) as is_author
from public.group_posts gp
join public.user_profile up on up.id = gp.author_user_id
left join lateral (
  select
    count(*)::int as reaction_count,
    count(*) filter (where gpr.reaction_type = 'amen')::int as amen_count,
    count(*) filter (where gpr.reaction_type = 'prayer')::int as prayer_count,
    count(*) filter (where gpr.reaction_type = 'heart')::int as heart_count
  from public.group_post_reactions gpr
  where gpr.group_post_id = gp.id
) reaction_counts on true
left join lateral (
  select gpr.reaction_type
  from public.group_post_reactions gpr
  where gpr.group_post_id = gp.id
    and gpr.user_id = auth.uid()
  limit 1
) current_user_reaction on true
where public.is_active_group_member(gp.group_id, auth.uid())
  or public.is_super_admin(auth.uid(), 'super_admin');

grant all on table public.group_posts_view to authenticated;
grant all on table public.group_posts_view to service_role;

-- RPC: leaders and super_admin can pin or unpin any post in their group
create or replace function public.set_group_post_pinned(
  target_post_id uuid,
  should_pin boolean
)
returns public.group_posts
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_post public.group_posts;
  target_group_id uuid;
  actor_id uuid := auth.uid();
begin
  if actor_id is null then
    raise exception 'Authentication required';
  end if;

  select gp.group_id
  into target_group_id
  from public.group_posts gp
  where gp.id = target_post_id;

  if target_group_id is null then
    raise exception 'Post not found.';
  end if;

  if not (
    public.is_super_admin(actor_id, 'super_admin')
    or public.is_active_group_leader(target_group_id, actor_id)
  ) then
    raise exception 'Not allowed to pin or unpin posts in this group.';
  end if;

  update public.group_posts
  set
    is_pinned = should_pin,
    updated_at = now()
  where id = target_post_id
  returning * into updated_post;

  return updated_post;
end;
$$;

grant execute on function public.set_group_post_pinned(uuid, boolean) to authenticated;
grant execute on function public.set_group_post_pinned(uuid, boolean) to service_role;
