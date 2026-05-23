drop table if exists public.tithes_offerings_settings cascade;

create table public.tithes_offerings_settings (
  id uuid primary key default gen_random_uuid(),
  bank text not null default '',
  account_name text not null default '',
  account_number text not null default '',
  branch_code text not null default '',
  reference text not null default '',
  snapscan_qr_url text,
  header_image_public_id text,
  header_image_url text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

-- enforce a single settings row
create unique index if not exists tithes_offerings_settings_singleton_idx
  on public.tithes_offerings_settings ((true));

alter table public.tithes_offerings_settings enable row level security;

-- any authenticated user (mobile app) can read
create policy "allow read for authenticated users"
  on public.tithes_offerings_settings
  for select to "authenticated"
  using (true);

-- only super admins can insert / update
create policy "allow all access to super admin"
  on public.tithes_offerings_settings
  for all to "authenticated"
  using (public.is_super_admin(auth.uid(), 'super_admin'::text))
  with check (public.is_super_admin(auth.uid(), 'super_admin'::text));
