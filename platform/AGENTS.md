# LW Platform — Agent Guide

Single source of truth for AI agents working across the Lewende Woord Paarl (LWP) platform.

## Workspace Layout

| Directory | Role | Status |
|-----------|------|--------|
| `LW_Portal_2.0/` | Admin portal (Vue 3 + TypeScript) | **Active** — content and operations control layer |
| `LW_App/` | Member mobile app (Flutter) | **Active** — congregation-facing experience |
| `supabase/` | Shared backend (Postgres, Auth, RLS, RPCs) | **Active** — schema lives in `migrations/` |
| `LW_Portal/` | Legacy admin portal (Svelte) | **Deprecated** — replaced by `LW_Portal_2.0`; do not extend |

Each active project has its own `AGENTS.md` with stack-specific conventions. Read this file first, then the project file for the area you are changing.

## Platform Model

- **LW Portal 2.0** is the operational and content control layer (super-admin only).
- **LW App** is the congregation-facing experience layer (Afrikaans UI).
- Both run on the **same Supabase project** and share entities: users, announcements, sermons, events, groups, prayer requests, notes, pastoral blog, etc.
- **Cloudinary** handles media for both clients.
- Plan cross-cutting features as one platform, not two separate products.

## Shared Backend

- SQL migrations: `supabase/migrations/` (currently 17 migrations).
- Deploy and ops: `supabase/DEPLOYMENT_GUIDE.md`.
- Backend agent notes: `supabase/AGENTS.md`.
- Never put schema changes only in app or portal repos — add a migration in `supabase/`.

## Roadmap

The platform roadmap lives at **`roadmap.md`** (workspace root). When adding features, reprioritizing, or marking work complete, update that file only.

## Cross-Project Delivery Rule

When a feature touches shared data or spans portal + app, plan for:

1. Supabase schema / views / RPCs / RLS
2. Portal admin workflows
3. App member workflows
4. Permissions and visibility
5. Notifications or follow-up actions (if applicable)

## Feature Reference Docs

Keep these for deep context on specific domains — they are not duplicated in AGENTS files:

| Doc | Purpose |
|-----|---------|
| `LW_App/docs/groups-feed-handoff.md` | Groups 2.0 + feed: backend contract, mobile UX, portal moderation |
| `LW_Portal_2.0/docs/events.md` | Events calendar quirks (drag behaviour, RSVP scope) |
| `LW_App/THEME.md` | Flutter design tokens and branding |
| `supabase/DEPLOYMENT_GUIDE.md` | Production migrations, SMTP, FCM blueprint |
| `LW_App/docs/i18n-plan.md` | Future English/Afrikaans i18n (not yet implemented) |

Delivered or superseded planning docs are in `docs/archive/` under each project.

## Commit Style

Recent history uses lowercase prefixes: `feature:`, `bugfix:`, `refactor:`, `chore:`, `fix:`.

## Security

- Never commit `.env`, `.env.development`, `.env.production`, or API keys.
- Portal env: `LW_Portal_2.0/.env.example` → `.env.development` / `.env.staging` / `.env.production`.
- App env: `LW_App/.env.development` / `.env.production` (bundled via `pubspec.yaml`, read through `lib/Utils/environment.dart`).
