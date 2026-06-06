create table if not exists public.prayer_request_notes (
  id uuid primary key default gen_random_uuid(),
  prayer_request_id uuid not null references public.prayer_requests(id) on delete cascade,
  author_user_id uuid not null references auth.users(id) on delete cascade,
  body text not null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint prayer_request_notes_body_not_blank check (char_length(trim(body)) > 0)
);

create index if not exists prayer_request_notes_request_id_idx
  on public.prayer_request_notes(prayer_request_id, created_at asc);

create index if not exists prayer_request_notes_author_user_id_idx
  on public.prayer_request_notes(author_user_id);

create or replace trigger handle_prayer_request_notes_updated_at
  before update on public.prayer_request_notes
  for each row execute function extensions.moddatetime('updated_at');

create or replace view public.prayer_request_notes_view as
select
  prn.id,
  prn.prayer_request_id,
  prn.author_user_id,
  prn.body,
  prn.created_at,
  prn.updated_at,
  up.first_name  as author_first_name,
  up.last_name   as author_last_name,
  trim(concat_ws(' ', up.first_name, up.last_name)) as author_full_name
from public.prayer_request_notes prn
join public.user_profile up on up.id = prn.author_user_id
order by prn.created_at asc;

alter table public.prayer_request_notes enable row level security;

create policy "allow prayer request note reads to super admin"
  on public.prayer_request_notes for select to authenticated
  using (public.is_super_admin(auth.uid(), 'super_admin'::text));

create policy "allow prayer request note inserts to super admin"
  on public.prayer_request_notes for insert to authenticated
  with check (
    public.is_super_admin(auth.uid(), 'super_admin'::text)
    and author_user_id = auth.uid()
  );

create policy "allow prayer request note deletes to own notes"
  on public.prayer_request_notes for delete to authenticated
  using (
    public.is_super_admin(auth.uid(), 'super_admin'::text)
    and author_user_id = auth.uid()
  );

grant all on table public.prayer_request_notes to authenticated;
grant all on table public.prayer_request_notes to service_role;

grant all on table public.prayer_request_notes_view to authenticated;
grant all on table public.prayer_request_notes_view to service_role;
