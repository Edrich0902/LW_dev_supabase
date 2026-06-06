-- pastoral_posts: church-wide leader-authored blog posts with draft/publish workflow
create table if not exists public.pastoral_posts (
  id uuid primary key default gen_random_uuid(),
  author_user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  content text not null,
  cover_image_url text,
  cover_image_public_id text,
  is_published boolean not null default false,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint pastoral_posts_title_not_blank check (char_length(trim(title)) > 0),
  constraint pastoral_posts_content_not_blank check (char_length(trim(content)) > 0)
);

create index if not exists pastoral_posts_published_created_idx
  on public.pastoral_posts(is_published, created_at desc);

create index if not exists pastoral_posts_author_user_id_idx
  on public.pastoral_posts(author_user_id);

create or replace trigger handle_pastoral_posts_updated_at
  before update on public.pastoral_posts
  for each row execute function extensions.moddatetime('updated_at');

-- pastoral_post_reactions: one reaction per user per post; toggle via upsert
create table if not exists public.pastoral_post_reactions (
  id uuid primary key default gen_random_uuid(),
  pastoral_post_id uuid not null references public.pastoral_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reaction_type text not null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint pastoral_post_reactions_unique unique (pastoral_post_id, user_id),
  constraint pastoral_post_reactions_type_check check (reaction_type in ('amen', 'prayer', 'heart'))
);

create index if not exists pastoral_post_reactions_post_id_idx
  on public.pastoral_post_reactions(pastoral_post_id);

create index if not exists pastoral_post_reactions_user_id_idx
  on public.pastoral_post_reactions(user_id);

create or replace trigger handle_pastoral_post_reactions_updated_at
  before update on public.pastoral_post_reactions
  for each row execute function extensions.moddatetime('updated_at');

-- View: enriches posts with author info, reaction aggregates, and current user state.
-- The WHERE clause handles visibility: published posts are public; admins see all.
create or replace view public.pastoral_posts_view as
select
  pp.id,
  pp.author_user_id,
  pp.title,
  pp.content,
  pp.cover_image_url,
  pp.cover_image_public_id,
  pp.is_published,
  pp.created_at,
  pp.updated_at,
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
  (pp.author_user_id = auth.uid()) as is_author
from public.pastoral_posts pp
join public.user_profile up on up.id = pp.author_user_id
left join lateral (
  select
    count(*)::int as reaction_count,
    count(*) filter (where ppr.reaction_type = 'amen')::int as amen_count,
    count(*) filter (where ppr.reaction_type = 'prayer')::int as prayer_count,
    count(*) filter (where ppr.reaction_type = 'heart')::int as heart_count
  from public.pastoral_post_reactions ppr
  where ppr.pastoral_post_id = pp.id
) reaction_counts on true
left join lateral (
  select ppr.reaction_type
  from public.pastoral_post_reactions ppr
  where ppr.pastoral_post_id = pp.id
    and ppr.user_id = auth.uid()
  limit 1
) current_user_reaction on true
where pp.is_published = true
  or public.is_super_admin(auth.uid(), 'super_admin');

-- RPCs

create or replace function public.create_pastoral_post(
  target_title text,
  target_content text,
  target_cover_image_url text default null,
  target_cover_image_public_id text default null
)
returns public.pastoral_posts
language plpgsql
security definer
set search_path = public
as $$
declare
  created_post public.pastoral_posts;
  actor_id uuid := auth.uid();
begin
  if actor_id is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_super_admin(actor_id, 'super_admin') then
    raise exception 'Not allowed to create pastoral posts.';
  end if;

  insert into public.pastoral_posts (
    author_user_id,
    title,
    content,
    cover_image_url,
    cover_image_public_id
  )
  values (
    actor_id,
    trim(target_title),
    target_content,
    nullif(trim(coalesce(target_cover_image_url, '')), ''),
    nullif(trim(coalesce(target_cover_image_public_id, '')), '')
  )
  returning * into created_post;

  return created_post;
end;
$$;

create or replace function public.update_pastoral_post(
  target_post_id uuid,
  target_title text,
  target_content text,
  target_cover_image_url text default null,
  target_cover_image_public_id text default null
)
returns public.pastoral_posts
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_post public.pastoral_posts;
  actor_id uuid := auth.uid();
begin
  if actor_id is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_super_admin(actor_id, 'super_admin') then
    raise exception 'Not allowed to update pastoral posts.';
  end if;

  update public.pastoral_posts
  set
    title = trim(target_title),
    content = target_content,
    cover_image_url = nullif(trim(coalesce(target_cover_image_url, '')), ''),
    cover_image_public_id = nullif(trim(coalesce(target_cover_image_public_id, '')), ''),
    updated_at = now()
  where id = target_post_id
  returning * into updated_post;

  if updated_post.id is null then
    raise exception 'Post not found or not allowed to update.';
  end if;

  return updated_post;
end;
$$;

create or replace function public.set_pastoral_post_published(
  target_post_id uuid,
  should_publish boolean
)
returns public.pastoral_posts
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_post public.pastoral_posts;
  actor_id uuid := auth.uid();
begin
  if actor_id is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_super_admin(actor_id, 'super_admin') then
    raise exception 'Not allowed to publish or unpublish pastoral posts.';
  end if;

  update public.pastoral_posts
  set
    is_published = should_publish,
    updated_at = now()
  where id = target_post_id
  returning * into updated_post;

  if updated_post.id is null then
    raise exception 'Post not found.';
  end if;

  return updated_post;
end;
$$;

create or replace function public.delete_pastoral_post(target_post_id uuid)
returns public.pastoral_posts
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_post public.pastoral_posts;
  actor_id uuid := auth.uid();
begin
  if actor_id is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_super_admin(actor_id, 'super_admin') then
    raise exception 'Not allowed to delete pastoral posts.';
  end if;

  delete from public.pastoral_posts
  where id = target_post_id
  returning * into deleted_post;

  if deleted_post.id is null then
    raise exception 'Post not found.';
  end if;

  return deleted_post;
end;
$$;

create or replace function public.set_pastoral_post_reaction(
  target_post_id uuid,
  target_reaction_type text
)
returns public.pastoral_post_reactions
language plpgsql
security definer
set search_path = public
as $$
declare
  reaction public.pastoral_post_reactions;
  actor_id uuid := auth.uid();
begin
  if actor_id is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1 from public.pastoral_posts
    where id = target_post_id and is_published = true
  ) then
    raise exception 'Post not found or not published.';
  end if;

  insert into public.pastoral_post_reactions (
    pastoral_post_id,
    user_id,
    reaction_type
  )
  values (
    target_post_id,
    actor_id,
    target_reaction_type
  )
  on conflict (pastoral_post_id, user_id)
  do update set
    reaction_type = excluded.reaction_type,
    updated_at = now()
  returning * into reaction;

  return reaction;
end;
$$;

create or replace function public.remove_pastoral_post_reaction(target_post_id uuid)
returns public.pastoral_post_reactions
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_reaction public.pastoral_post_reactions;
  actor_id uuid := auth.uid();
begin
  if actor_id is null then
    raise exception 'Authentication required';
  end if;

  delete from public.pastoral_post_reactions
  where pastoral_post_id = target_post_id
    and user_id = actor_id
  returning * into deleted_reaction;

  if deleted_reaction.id is null then
    raise exception 'No reaction found to remove.';
  end if;

  return deleted_reaction;
end;
$$;

-- RLS

alter table public.pastoral_posts enable row level security;
alter table public.pastoral_post_reactions enable row level security;

create policy "allow pastoral post reads to authenticated"
  on public.pastoral_posts
  for select to authenticated
  using (
    is_published = true
    or public.is_super_admin(auth.uid(), 'super_admin')
  );

create policy "allow pastoral post inserts to super admin"
  on public.pastoral_posts
  for insert to authenticated
  with check (
    public.is_super_admin(auth.uid(), 'super_admin')
  );

create policy "allow pastoral post updates to super admin"
  on public.pastoral_posts
  for update to authenticated
  using (public.is_super_admin(auth.uid(), 'super_admin'))
  with check (public.is_super_admin(auth.uid(), 'super_admin'));

create policy "allow pastoral post deletes to super admin"
  on public.pastoral_posts
  for delete to authenticated
  using (public.is_super_admin(auth.uid(), 'super_admin'));

create policy "allow pastoral post reaction reads to authenticated"
  on public.pastoral_post_reactions
  for select to authenticated
  using (
    public.is_super_admin(auth.uid(), 'super_admin')
    or exists (
      select 1
      from public.pastoral_posts pp
      where pp.id = pastoral_post_id
        and pp.is_published = true
    )
  );

create policy "allow pastoral post reaction inserts to authenticated"
  on public.pastoral_post_reactions
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1
      from public.pastoral_posts pp
      where pp.id = pastoral_post_id
        and pp.is_published = true
    )
  );

create policy "allow pastoral post reaction updates to owner"
  on public.pastoral_post_reactions
  for update to authenticated
  using (
    public.is_super_admin(auth.uid(), 'super_admin')
    or user_id = auth.uid()
  )
  with check (
    public.is_super_admin(auth.uid(), 'super_admin')
    or user_id = auth.uid()
  );

create policy "allow pastoral post reaction deletes to owner"
  on public.pastoral_post_reactions
  for delete to authenticated
  using (
    public.is_super_admin(auth.uid(), 'super_admin')
    or user_id = auth.uid()
  );

-- Grants

grant all on table public.pastoral_posts to authenticated;
grant all on table public.pastoral_posts to service_role;

grant all on table public.pastoral_post_reactions to authenticated;
grant all on table public.pastoral_post_reactions to service_role;

grant all on table public.pastoral_posts_view to authenticated;
grant all on table public.pastoral_posts_view to service_role;

grant execute on function public.create_pastoral_post(text, text, text, text) to authenticated;
grant execute on function public.create_pastoral_post(text, text, text, text) to service_role;
grant execute on function public.update_pastoral_post(uuid, text, text, text, text) to authenticated;
grant execute on function public.update_pastoral_post(uuid, text, text, text, text) to service_role;
grant execute on function public.set_pastoral_post_published(uuid, boolean) to authenticated;
grant execute on function public.set_pastoral_post_published(uuid, boolean) to service_role;
grant execute on function public.delete_pastoral_post(uuid) to authenticated;
grant execute on function public.delete_pastoral_post(uuid) to service_role;
grant execute on function public.set_pastoral_post_reaction(uuid, text) to authenticated;
grant execute on function public.set_pastoral_post_reaction(uuid, text) to service_role;
grant execute on function public.remove_pastoral_post_reaction(uuid) to authenticated;
grant execute on function public.remove_pastoral_post_reaction(uuid) to service_role;
