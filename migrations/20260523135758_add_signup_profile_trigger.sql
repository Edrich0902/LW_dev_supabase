-- Create or replace the new user signup profile trigger
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.user_profile (id, first_name, last_name, profile_url, profile_public_id)
  values (
    new.id, 
    coalesce(new.raw_user_meta_data->>'first_name', ''), 
    coalesce(new.raw_user_meta_data->>'last_name', ''), 
    new.raw_user_meta_data->>'profile_url', 
    new.raw_user_meta_data->>'profile_public_id'
  );
  return new;
end;
$$ language plpgsql security definer;

-- Attach the trigger to run after every auth user is created
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
