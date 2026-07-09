# Supabase Production Deployment & Integration Guide

This guide outlines the concrete requirements, configuration settings, and step-by-step walkthroughs for deploying the current local Supabase database changes to a production Supabase instance. It covers three main areas:
1. **Database Migrations Deployment**
2. **Custom SMTP Email Provider Integration**
3. **Push Notifications Integration (FCM Backend & Mobile Blueprint)**

---

## 1. Database Migrations Deployment

The local Supabase project has **17 database migrations** located in `supabase/migrations/`. These define the schema for user profiles, bible interactions, tithes/offerings settings, prayer requests, events, app feedback, pastoral blogs, and the **Groups 2.0 / Group Feed** feature.

### Prerequisites
- Install the [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started) on your local machine:
  ```bash
  brew install supabase/tap/supabase
  ```
- Retrieve your **Production Supabase Project Reference ID** (found in the Supabase Dashboard URL: `https://supabase.com/dashboard/project/<project-ref>`) and your **Database Password**.

### Walkthrough Steps

#### Step 1: Login to Supabase CLI
Authenticate the CLI with your Supabase account:
```bash
supabase login
```

#### Step 2: Link Local Repo to Production Project
From the root of the project directory where the `supabase` folder is located, run:
```bash
supabase link --project-ref <your-production-project-ref>
```
*Note: You will be prompted to enter the database password you set when creating the production Supabase project.*

#### Step 3: Verify Local vs. Production Status
Check if your local migrations are ahead of production:
```bash
supabase db status
```
This lists all migration files and indicates whether they are applied locally and on the remote (production) database.

#### Step 4: Dry-Run / Validate Database Schema
To ensure your production database is currently in sync with the migrations baseline before pushing:
```bash
supabase db diff --use-migra
```
If there are no differences between your local tracking and remote schema, this will return empty.

#### Step 5: Push Migrations to Production
To apply all pending migrations in chronological order to the remote production database, execute:
```bash
supabase db push
```
> [!WARNING]
> Do not manually modify production tables via the Supabase Table Editor prior to running this command, as it can cause schema conflicts or make migrations fail. If you have done so, you may need to resolve the diffs or use `--force`.

#### Step 6: Verify Deployment
Verify that all 17 migrations have been applied:
```bash
supabase db status
```
Verify that all columns, views (like `group_posts_view` and `groups_public_view`), and functions/triggers exist and are working correctly on the Supabase Dashboard.

---

## 2. Custom SMTP Email Provider Integration

By default, Supabase projects use a shared SMTP server which is strictly rate-limited (3 emails per hour). For production, you **must** configure a custom SMTP provider (e.g., **Mailtrap**, **Resend**, **SendGrid**, or **Amazon SES**).

### Production Settings Checklist (Supabase Dashboard)
1. Go to the [Supabase Console](https://supabase.com) -> Select your project -> **Project Settings** -> **Auth**.
2. Scroll to the **SMTP Settings** section.
3. Toggle **Enable Custom SMTP** to **ON**.

| Setting Field | Example (Mailtrap) | Example (Resend) | Description |
| :--- | :--- | :--- | :--- |
| **Sender Email** | `no-reply@yourdomain.com` | `no-reply@lewendewoordpaarl.co.za` | Must be a verified address/domain in your Mailtrap sending console. |
| **Sender Name** | `Lewende Woord Paarl` | `Lewende Woord Paarl` | Display name visible to users in their inbox. |
| **SMTP Host** | `send.smtp.mailtrap.io` | `smtp.resend.com` | The Mailtrap SMTP transactional host. |
| **SMTP Port** | `587` | `587` | Use `587` for STARTTLS (recommended) or `465` for SSL. |
| **SMTP Username** | `api` | `resend` | For Mailtrap, this is literally the string `api`. |
| **SMTP Password** | `[Your Mailtrap SMTP Password]` | `re_prod_xxxxxx` | The SMTP API token generated under your verified domain settings. |

### Mailtrap Integration Walkthrough
1. Log in to your [Mailtrap Console](https://mailtrap.io/).
2. Navigate to **Email Sending** -> **Sending Domains** in the sidebar.
3. Click on your verified domain name.
4. Click the **SMTP/API Settings** tab.
5. Under **SMTP Integration**, choose **Svelte/Flutter** (or generic SMTP) to display credentials:
   - **Host**: `send.smtp.mailtrap.io`
   - **Port**: `587` (or `465` / `2525`)
   - **Username**: `api`
   - **Password**: Copy your generated credentials password.
6. Input these credentials into the Supabase Dashboard SMTP settings as shown above and click **Save**.

### DNS & Deliverability Requirements
To ensure emails do not get flagged as spam:
- **SPF Record**: Add/update a `TXT` record on your domain registrar containing `v=spf1 include:amazonses.com ... ~all` (dependent on your provider).
- **DKIM Records**: Add the CNAME/TXT records provided by Resend/SendGrid to authenticate outgoing emails.
- **DMARC Record**: Add a `TXT` record `_dmarc.yourdomain.com` with `v=DMARC1; p=none;` (or `quarantine` / `reject`).


### Auth URL Configuration
1. Under **Project Settings > Auth**, locate **URL Configuration**.
2. **Site URL**: Change this from `http://127.0.0.1:3000` (local dev) to your production portal URL:
   - e.g., `https://portal.lewendewoordpaarl.co.za`
3. **Redirect URLs**: Update the whitelist of redirect schemes. Ensure these match your production app deep links and portal callbacks:
   - `lwpapp://*` (For Flutter app authentication redirections)
   - `https://portal.lewendewoordpaarl.co.za/auth/callback`
   - `https://portal.lewendewoordpaarl.co.za/auth/reset-password`

---

## 3. Push Notifications Integration (FCM)

Push notifications are deferred to the next phase of the roadmap. However, when we implement them, here is the full blueprint of requirements for backend and mobile integration.

### High-Level Architecture
1. **FCM Token Handshake**: Mobile app gets token from FCM and writes to `user_device_tokens` table.
2. **Database Trigger Hook**: Insertion on `group_posts` triggers webhook calling Supabase Edge Function.
3. **Delivery Flow**: The Edge Function queries members of the group, retrieves their device tokens, and dispatches the payload to the Firebase FCM v1 API.

### Requirement 1: Firebase Project Setup
Because both Android (FCM) and iOS (APNs bridged through FCM) require Firebase:
1. Create a project in the [Firebase Console](https://console.firebase.google.com/).
2. Add your **Android App** (package name: `com.lewendewoordpaarl.lw_app` or similar) and download `google-services.json`. Put it in `LW_App/android/app/`.
3. Add your **iOS App** (bundle ID: `com.lewendewoordpaarl.lwApp` or similar) and download `GoogleService-Info.plist`. Put it in `LW_App/ios/Runner/`.
4. **iOS Certificate Setup**: 
   - Go to Apple Developer account -> Certificates, Identifiers & Profiles -> Keys. Create an APNs key (`.p8`).
   - In Firebase Console -> Project Settings -> Cloud Messaging -> iOS app configuration, upload the APNs key.

### Requirement 2: Device Token Storage Table
A migration must be written to store FCM tokens associated with users. Add this to a new migration file:

```sql
-- Create table to map authenticated users to their active devices
create table public.user_device_tokens (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  fcm_token text unique not null,
  device_os text check (device_os in ('ios', 'android')),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable Row Level Security (RLS)
alter table public.user_device_tokens enable row level security;

-- Create policies so users can only manage their own device tokens
create policy "Users can insert their own device tokens"
  on public.user_device_tokens for insert
  with check (auth.uid() = user_id);

create policy "Users can view their own device tokens"
  on public.user_device_tokens for select
  using (auth.uid() = user_id);

create policy "Users can update their own device tokens"
  on public.user_device_tokens for update
  using (auth.uid() = user_id);

create policy "Users can delete their own device tokens"
  on public.user_device_tokens for delete
  using (auth.uid() = user_id);
```

### Requirement 3: Supabase Trigger & Edge Function (Backend)
To trigger push notifications automatically when a new group post is published:
1. **Create a Database Webhook** under the Database section in the Supabase Dashboard, targeting the `group_posts` table on `INSERT`.
2. **Write a Deno Edge Function** (e.g. `supabase/functions/send-post-notification/index.ts`):
   - It parses the incoming new post (which contains `group_id` and `author_id`).
   - It queries `group_memberships` view to find all active member IDs in that group.
   - It queries `user_device_tokens` to extract the `fcm_token` values for those members.
   - It requests a secure OAuth2 access token for FCM using a Google Service Account credentials JSON.
   - It sends a POST request to the FCM v1 endpoint: `https://fcm.googleapis.com/v1/projects/<your-firebase-project-id>/messages:send` with the notification payload (title: "Nuwe Groepskrywe", body: post preview text).
3. **Configure Secrets**:
   - Generate a private key JSON from Firebase Console > Project Settings > Service Accounts.
   - Set it as a Supabase Secret:
     ```bash
     supabase secrets set FIREBASE_SERVICE_ACCOUNT_KEY='{"type": "service_account", ...}'
     ```

### Requirement 4: Flutter Mobile App Integration
1. Add the dependencies to `pubspec.yaml`:
   ```yaml
   dependencies:
     firebase_core: ^2.27.0
     firebase_messaging: ^14.7.19
     flutter_local_notifications: ^16.3.1
   ```
2. Initialize Firebase and configure background notification handling in `lib/main.dart` or a specialized service:
   ```dart
   import 'package:firebase_core/firebase_core.dart';
   import 'package:firebase_messaging/firebase_messaging.dart';

   Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
     await Firebase.initializeApp();
     // Handle background message
   }

   void initNotifications() async {
     await Firebase.initializeApp();
     FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
     
     // Request permission (essential on iOS)
     NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
       alert: true,
       badge: true,
       sound: true,
     );
     
     if (settings.authorizationStatus == AuthorizationStatus.authorized) {
       // Retrieve the device's FCM Token
       String? token = await FirebaseMessaging.instance.getToken();
       if (token != null) {
         // Call your Supabase client to upsert into user_device_tokens table
         await saveTokenToSupabase(token);
       }
     }
     
     // Handle Foreground Messages
     FirebaseMessaging.onMessage.listen((RemoteMessage message) {
       // Display local notification banner if app is open
     });

     // Handle User tapping on notification from background
     FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
       // Extract group_id from message.data and navigate:
       // Navigator.push(context, MaterialPageRoute(builder: (_) => GroupFeedPage(groupId: message.data['group_id'])));
     });
   }
   ```
