# LW Platform Roadmap

Shared by `LW_Portal_2.0` and `LW_App`. **This is the only roadmap file** — do not maintain copies in sub-projects.

## Shared Product Direction

LW Portal is the operational and content control layer.
LW App is the congregation-facing experience layer.
Both products run on the same Supabase backend and should be planned as one platform rather than two separate systems.

## Current Shared Foundation

These backend domains already exist in the system and should be extended before introducing unrelated new modules:

- Users and profiles
- Announcements
- Sermons
- Events and event RSVP
- Groups / Connect and Serve
- Prayer requests
- Notes
- Social media links
- Tithes and offerings settings
- Meta data / church information
- Pastoral blog

## Now

These are the next highest-value features because they build directly on existing shared entities and create complete loops between portal operations and app engagement.

### 1. Groups 2.0

Turn groups into a full discipleship and community workflow.

- Status: shared Supabase contract, portal admin management, and app member/leader flows are delivered
- Backend: `group_memberships`, shared views, RPCs, and RLS for join, approve, decline, leave, remove, and leader assignment
- Portal: group CRUD plus leader assignment, active-member management, pending-request approval, and membership counts
- App: dedicated group detail screens, join/leave actions, `My Groups`, and leader moderation tools
- App: group feed with leader-authored rich-text posts and member reactions

### 2. Group Feed Moderation and Notifications

Extend the new group feed into an operational communications loop.

- Status: pinned posts (backend, mobile, portal) and portal feed moderation are delivered; push notifications remain pending
- Backend: `is_pinned` column, `set_group_post_pinned` RPC, and updated `group_posts_view` with pinned-first ordering
- Portal: feed tab in group manage view — admins can view, pin/unpin, and delete posts via Quill rich-text viewer
- App: leaders can pin/unpin posts from the group feed; pinned posts are visually badged and float to top
- App: deep links into specific group posts when notifications are added
- Add push notification delivery for new group posts
- Add feed analytics or read-state only if needed later

### 3. Prayer Workflow Completion

Complete the prayer request lifecycle from submission to care follow-up.

- Status: private requests (portal/app), portal pastoral notes trail, and app reactions are delivered; other app-side actions and assignment remain
- Portal: multi-step pastoral notes per request — admins can add/delete internal notes with author + timestamp trail
- Portal: private request flag — hides the request from the public app view; portal admins see all
- App: replace generic reaction with `Ek Het Gebid` (delivered as 'Ek bid vir jou')
- App: allow request owners to post updates / praise reports
- App: support private prayer requests visible only to church leadership (delivered)
- Portal: assign prayer requests to a leader or team member (deferred)

### 4. Announcements and Notifications Platform

Use announcements as the base communications system across the platform.

- Portal: scheduled announcements
- Portal: push action for mobile delivery
- App: notification center for missed announcements and pushes
- App: event reminder notifications for RSVP'd users
- Add delivery and read-state tracking where practical

### 5. Sermon Series and Contextual Notes

Improve sermon discoverability and long-term engagement.

- Portal: sermon series management with artwork and descriptions
- App: series collections and guided discovery
- App: sermon-linked notes
- App: continue watching / listening progress

### 6. Pastoral Blog

A pastoral communications channel where church leaders author and publish blog-style posts from the portal, which appear as a scrollable feed on the mobile app. Members can react to posts.

- Status: **delivered** — Supabase schema, portal list + editor views, app feed with reactions, dashboard tiles
- Commenting on posts deferred to a future iteration

### 7. Attendance and Check-In

Add the next operational layer on top of events and RSVPs.

- Portal: attendance registers per event or service
- Portal: first-timer visibility and follow-up flags
- App: QR or manual event check-in for selected event types
- Portal: attendance reporting and trends

## Next

### 8. Member Journey CRM

Track the path from visitor to engaged member.

### 9. Volunteer Scheduling and Rosters

Coordinate service teams more effectively.

### 10. Featured Content and Home Screen Curation

Let the portal intentionally shape what users see first.

### 11. Resource Library

Create a managed library for documents and study resources.

### 12. Giving Records and Reporting

Extend giving from static banking details into structured stewardship data.

### 13. Dashboard Analytics and Reporting

Make trends visible to leaders and administrators.

## Later

### 14. Global Search

### 15. Testimonies Module

### 16. Live Service Mode

### 17. Audit Trail and Granular Roles

### 18. Media Library

### 19. Settings and Integrations Hub

## New Additions To Include

- Households and family links
- Follow-up task engine
- Volunteer availability
- Profile completeness and data quality
- Content expiry and archiving rules
- Language preference targeting (see `LW_App/docs/i18n-plan.md`)

## Delivery Rule

When a feature affects shared backend data or a user workflow that spans portal and app, planning must cover:

- Required Supabase schema changes
- Portal admin workflows
- App member workflows
- Permissions and visibility rules
- Notifications or follow-up actions
- Analytics or reporting needs
