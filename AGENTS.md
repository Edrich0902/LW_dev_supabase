# Supabase — Agent Guide

Shared Postgres backend for LW Portal 2.0 and LW App.

## Layout

- `migrations/` — ordered SQL migrations (source of truth for schema)
- `config.toml` — local Supabase CLI config
- `DEPLOYMENT_GUIDE.md` — production deploy, SMTP, FCM blueprint

## Conventions

- One migration per logical change: `YYYYMMDDHHMMSS_descriptive_name.sql`
- Migrations are append-only — never edit applied migrations; add a new migration to fix issues
- Use views for complex reads; use RPCs for multi-step writes and permission checks
- Enable RLS on all user-facing tables; test policies for member, leader, and super_admin paths
- Avoid `security_invoker = on` on views that join `auth.users` — caused `permission denied for table users` on groups views (fixed in `20260606143000_fix_groups_view_permissions.sql`)

## Key Domains (migrations)

| Area | Migration(s) |
|------|----------------|
| Base schema | `20260520212401_remote_schema.sql` |
| Profiles / signup trigger | `20260523135758_add_signup_profile_trigger.sql` |
| Bible interactions | `20260523163500_add_user_bible_interactions.sql` |
| Tithes & offerings | `20260523180000_add_tithes_offerings_settings.sql` |
| Prayer requests | `20260524233817_add_prayer_requests.sql` |
| Portal roles | `20260525110000_add_portal_role_management.sql` |
| Event RSVP | `20260525120000_add_event_rsvp.sql` |
| App feedback | `20260530120000_add_app_feedback.sql` |
| Groups 2.0 | `20260606123000_add_groups_2_0.sql`, `20260606143000_fix_groups_view_permissions.sql` |
| Group feed | `20260606173000_add_group_posts.sql`, `20260607000000_add_group_post_pinning.sql` |
| Prayer notes / private / praise | `20260607100000` – `20260607150000` |
| Pastoral blog | `20260607120000_add_pastoral_blog.sql` |
| Preferred language | `20260607130000_add_user_profile_preferred_language.sql` |

## Local Development

```bash
supabase start          # local stack
supabase db reset       # replay all migrations locally
supabase db status      # compare local vs linked remote
```

## Production

See `DEPLOYMENT_GUIDE.md` for `supabase link`, `supabase db push`, SMTP, and auth URL configuration.

## Cross-Project Coordination

When adding schema:

1. Write migration in `migrations/`
2. Update portal services/stores in `LW_Portal_2.0/`
3. Update app services/models in `LW_App/`
4. Update `roadmap.md` at workspace root if feature status changes
5. Add a feature handoff doc under `LW_App/docs/` or `LW_Portal_2.0/docs/` if the domain is non-obvious
