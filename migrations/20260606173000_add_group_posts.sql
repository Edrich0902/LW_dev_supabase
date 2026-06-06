create table if not exists public.group_posts (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  author_user_id uuid not null references auth.users(id) on delete cascade,
  title text,
  content text not null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint group_posts_content_not_blank check (char_length(trim(content)) > 0)
);

create index if not exists group_posts_group_id_idx
  on public.group_posts(group_id, created_at desc);

create index if not exists group_posts_author_user_id_idx
  on public.group_posts(author_user_id);

create or replace trigger handle_group_posts_updated_at
  before update on public.group_posts
  for each row execute function extensions.moddatetime('updated_at');

create table if not exists public.group_post_reactions (
  id uuid primary key default gen_random_uuid(),
  group_post_id uuid not null references public.group_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reaction_type text not null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint group_post_reactions_unique unique (group_post_id, user_id),
  constraint group_post_reactions_type_check check (reaction_type in ('amen', 'prayer', 'heart'))
);

create index if not exists group_post_reactions_post_id_idx
  on public.group_post_reactions(group_post_id);

create index if not exists group_post_reactions_user_id_idx
  on public.group_post_reactions(user_id);

create or replace trigger handle_group_post_reactions_updated_at
  before update on public.group_post_reactions
  for each row execute function extensions.moddatetime('updated_at');

create or replace function public.is_active_group_member(
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
      and gm.status = 'active'
  );
$$;

grant execute on function public.is_active_group_member(uuid, uuid) to authenticated;
grant execute on function public.is_active_group_member(uuid, uuid) to service_role;

create or replace view public.group_posts_view as
select
  gp.id,
  gp.group_id,
  gp.author_user_id,
  gp.title,
  gp.content,
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

create or replace function public.create_group_post(
  target_group_id uuid,
  target_title text,
  target_content text
)
returns public.group_posts
language plpgsql
security definer
set search_path = public
as $$
declare
  created_post public.group_posts;
  actor_id uuid := auth.uid();
begin
  if actor_id is null then
    raise exception 'Authentication required';
  end if;

  if not (
    public.is_super_admin(actor_id, 'super_admin')
    or public.is_active_group_leader(target_group_id, actor_id)
  ) then
    raise exception 'Not allowed to create posts for this group.';
  end if;

  insert into public.group_posts (
    group_id,
    author_user_id,
    title,
    content
  )
  values (
    target_group_id,
    actor_id,
    nullif(trim(target_title), ''),
    target_content
  )
  returning * into created_post;

  return created_post;
end;
$$;

create or replace function public.update_group_post(
  target_post_id uuid,
  target_title text,
  target_content text
)
returns public.group_posts
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_post public.group_posts;
  actor_id uuid := auth.uid();
begin
  if actor_id is null then
    raise exception 'Authentication required';
  end if;

  update public.group_posts gp
  set
    title = nullif(trim(target_title), ''),
    content = target_content,
    updated_at = now()
  where gp.id = target_post_id
    and (
      public.is_super_admin(actor_id, 'super_admin')
      or (
        gp.author_user_id = actor_id
        and public.is_active_group_leader(gp.group_id, actor_id)
      )
    )
  returning * into updated_post;

  if updated_post.id is null then
    raise exception 'Post not found or not allowed to update.';
  end if;

  return updated_post;
end;
$$;

create or replace function public.delete_group_post(target_post_id uuid)
returns public.group_posts
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_post public.group_posts;
  actor_id uuid := auth.uid();
begin
  if actor_id is null then
    raise exception 'Authentication required';
  end if;

  delete from public.group_posts gp
  where gp.id = target_post_id
    and (
      public.is_super_admin(actor_id, 'super_admin')
      or (
        gp.author_user_id = actor_id
        and public.is_active_group_leader(gp.group_id, actor_id)
      )
    )
  returning * into deleted_post;

  if deleted_post.id is null then
    raise exception 'Post not found or not allowed to delete.';
  end if;

  return deleted_post;
end;
$$;

create or replace function public.set_group_post_reaction(
  target_post_id uuid,
  target_reaction_type text
)
returns public.group_post_reactions
language plpgsql
security definer
set search_path = public
as $$
declare
  reaction public.group_post_reactions;
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
    or public.is_active_group_member(target_group_id, actor_id)
  ) then
    raise exception 'Not allowed to react to this post.';
  end if;

  insert into public.group_post_reactions (
    group_post_id,
    user_id,
    reaction_type
  )
  values (
    target_post_id,
    actor_id,
    target_reaction_type
  )
  on conflict (group_post_id, user_id)
  do update set
    reaction_type = excluded.reaction_type,
    updated_at = now()
  returning * into reaction;

  return reaction;
end;
$$;

create or replace function public.remove_group_post_reaction(target_post_id uuid)
returns public.group_post_reactions
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_reaction public.group_post_reactions;
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
    or public.is_active_group_member(target_group_id, actor_id)
  ) then
    raise exception 'Not allowed to remove a reaction from this post.';
  end if;

  delete from public.group_post_reactions gpr
  where gpr.group_post_id = target_post_id
    and gpr.user_id = actor_id
  returning * into deleted_reaction;

  if deleted_reaction.id is null then
    raise exception 'No reaction found to remove.';
  end if;

  return deleted_reaction;
end;
$$;

alter table public.group_posts enable row level security;
alter table public.group_post_reactions enable row level security;

create policy "allow group post reads to active members"
  on public.group_posts
  for select to authenticated
  using (
    public.is_super_admin(auth.uid(), 'super_admin')
    or public.is_active_group_member(group_id, auth.uid())
  );

create policy "allow group post inserts to active leaders"
  on public.group_posts
  for insert to authenticated
  with check (
    public.is_super_admin(auth.uid(), 'super_admin')
    or (
      author_user_id = auth.uid()
      and public.is_active_group_leader(group_id, auth.uid())
    )
  );

create policy "allow group post updates to author"
  on public.group_posts
  for update to authenticated
  using (
    public.is_super_admin(auth.uid(), 'super_admin')
    or (
      author_user_id = auth.uid()
      and public.is_active_group_leader(group_id, auth.uid())
    )
  )
  with check (
    public.is_super_admin(auth.uid(), 'super_admin')
    or (
      author_user_id = auth.uid()
      and public.is_active_group_leader(group_id, auth.uid())
    )
  );

create policy "allow group post deletes to author"
  on public.group_posts
  for delete to authenticated
  using (
    public.is_super_admin(auth.uid(), 'super_admin')
    or (
      author_user_id = auth.uid()
      and public.is_active_group_leader(group_id, auth.uid())
    )
  );

create policy "allow group post reaction reads to active members"
  on public.group_post_reactions
  for select to authenticated
  using (
    public.is_super_admin(auth.uid(), 'super_admin')
    or exists (
      select 1
      from public.group_posts gp
      where gp.id = group_post_id
        and public.is_active_group_member(gp.group_id, auth.uid())
    )
  );

create policy "allow group post reaction inserts to active members"
  on public.group_post_reactions
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and (
      public.is_super_admin(auth.uid(), 'super_admin')
      or exists (
        select 1
        from public.group_posts gp
        where gp.id = group_post_id
          and public.is_active_group_member(gp.group_id, auth.uid())
      )
    )
  );

create policy "allow group post reaction updates to owner"
  on public.group_post_reactions
  for update to authenticated
  using (
    public.is_super_admin(auth.uid(), 'super_admin')
    or user_id = auth.uid()
  )
  with check (
    public.is_super_admin(auth.uid(), 'super_admin')
    or user_id = auth.uid()
  );

create policy "allow group post reaction deletes to owner"
  on public.group_post_reactions
  for delete to authenticated
  using (
    public.is_super_admin(auth.uid(), 'super_admin')
    or user_id = auth.uid()
  );

grant all on table public.group_posts to authenticated;
grant all on table public.group_posts to service_role;

grant all on table public.group_post_reactions to authenticated;
grant all on table public.group_post_reactions to service_role;

grant all on table public.group_posts_view to authenticated;
grant all on table public.group_posts_view to service_role;

grant execute on function public.create_group_post(uuid, text, text) to authenticated;
grant execute on function public.create_group_post(uuid, text, text) to service_role;
grant execute on function public.update_group_post(uuid, text, text) to authenticated;
grant execute on function public.update_group_post(uuid, text, text) to service_role;
grant execute on function public.delete_group_post(uuid) to authenticated;
grant execute on function public.delete_group_post(uuid) to service_role;
grant execute on function public.set_group_post_reaction(uuid, text) to authenticated;
grant execute on function public.set_group_post_reaction(uuid, text) to service_role;
grant execute on function public.remove_group_post_reaction(uuid) to authenticated;
grant execute on function public.remove_group_post_reaction(uuid) to service_role;
