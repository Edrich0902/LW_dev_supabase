-- Create the user_bible_interactions table
create table if not exists public.user_bible_interactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  version_id text not null,
  book_id text not null,
  chapter_number text not null,
  verse_number text not null,
  highlight_color text, -- 'yellow', 'green', 'blue', 'pink', 'orange' or null
  is_bookmarked boolean not null default false,
  note text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  
  -- Constraint to ensure one row per user/verse combination
  constraint unique_user_verse unique (user_id, version_id, book_id, chapter_number, verse_number)
);

-- Indices for optimized lookups and sync times
create index if not exists user_bible_interactions_user_idx 
  on public.user_bible_interactions(user_id);

create index if not exists user_bible_interactions_lookup_idx 
  on public.user_bible_interactions(user_id, version_id, book_id, chapter_number);

-- Enable RLS (Row Level Security)
alter table public.user_bible_interactions enable row level security;

-- Create policy for user security
create policy "Gebruikers kan hul eie Bybel-interaksies bestuur"
  on public.user_bible_interactions
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
