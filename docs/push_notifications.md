# Push notifications

The app uses Supabase `notifications` for the authenticated user's inbox. Database triggers atomically record order status changes, album membership/acceptance changes and published templates. Each record creates a durable `push_outbox` entry for each enabled device belonging to that user. Private events never use Firebase topics. The retired Java private-topic sender is disabled; public template campaigns are still supported there for rollback compatibility.

`push-dispatch` claims a batch with expiring leases, rechecks the current device owner and account preferences, and sends FCM HTTP v1 notifications. Invalid tokens are removed, transient failures retry with backoff (up to 10 attempts), and permanent errors remain visible as failed queue entries. A notification id provides a stable Android tag/APNs collapse id. Delivery is at least once: a crash between an accepted FCM request and its database acknowledgement may retry. The inbox event itself remains unique. Notification records and their queue entries expire after 90 days; cleanup runs with the worker.

## Deploy and activate

1. Apply the repository migrations, including `20260908094551_targeted_push_notifications.sql`, to the app's Supabase project.
2. Configure Edge Function secrets through the Supabase dashboard or an untracked environment file (never paste secret values into source control):
   - `FIREBASE_SERVICE_ACCOUNT_JSON`: Firebase service account JSON containing `project_id`, `client_email` and `private_key`; grant the account Firebase Cloud Messaging API send permission for the same Firebase project as the app.
   - `PUSH_DISPATCH_SECRET`: a random secret with at least 32 characters.
   - `PUSH_DELIVERY_ENABLED`: `true` only after the intended environment and credentials are verified. Omitting it prevents sends.
   - Standard Supabase-managed `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are required by the function.
3. Deploy the `push-dispatch` Edge Function. Its config has `verify_jwt=false`, because it validates `X-Push-Secret` itself and rejects empty/short/mismatched secrets. This function must never be invoked by mobile clients.
4. In Supabase Vault, create `snapfit_push_dispatch_url` with your project URL followed by `/functions/v1/push-dispatch`, and `snapfit_push_dispatch_secret` with the same value as `PUSH_DISPATCH_SECRET`.
5. Run `supabase/setup/push_dispatch_schedule.sql` once in SQL Editor. It schedules the worker every minute using pg_cron/pg_net and replaces only the job named `snapfit-push-dispatch`. The scheduling step is required; deploying the function alone does not run the queue.
6. In Apple Developer/Xcode, enable Push Notifications for `com.devsheep.snapFit` and regenerate/download signing profiles. Upload the APNs authentication key in the matching Firebase iOS app. The project uses `Runner.entitlements` with development APNs for Debug and production for Release/Profile, plus remote notification/background fetch modes. Repository configuration cannot create Apple account capabilities or upload the APNs key.

No secrets, database deployment, scheduler installation or real FCM sends were performed by the implementation tests.

## Mobile behavior

Initialization happens after the UI is mounted. FCM/APNs or network errors schedule retries and do not prevent app startup. APNs token availability is checked before token or topic operations. The first authenticated session requests notification permission; a denied user can reopen OS settings from the notification settings screen. Resume rechecks permission and updates the installation's UTC offset. Logout removes its server binding before signing out, deletes its FCM token and clears local notifications; login and token refresh register the current account again. Old global topic subscriptions are removed.

Account preferences persist per user. The master toggle enables/disables delivery without opting the user into marketing. Both foreground display and the server respect categories and quiet hours (22:00 inclusive to 08:00 exclusive in the last reported device offset). Messages sent immediately before quiet hours expire before 22:00. Quiet-time messages remain in the inbox but are not delivered later as a burst. A device timezone change is learned when the app resumes. Offline preference changes are retried and visibly reported as not yet synced.

OS taps, local notification taps and inbox taps share the app's navigation handler. Payloads include `userId` and are rejected when they belong to another account; taps received before login wait until a session is established. The app reads only per-user inbox rows and updates read flags idempotently.

Invite links themselves have no recipient identity. No token is broadcast when creating a link. Acceptance notifies the album owner; direct membership invites notify the known recipient. The app currently has no album comment event backend; the comment category is reserved for a future server-created recipient notification.

## Verification

Tests use generated keys, fake FCM/native channels, mocked HTTP and an isolated in-memory PostgreSQL runtime. They never contact Google or Supabase.

- `flutter test --no-pub test/unit/notification_policy_test.dart test/unit/fcm_notification_lifecycle_test.dart test/unit/fcm_notification_service_security_test.dart`
- `node --test test/server/push_policy.test.mjs` (Node with TypeScript stripping)
- `PGLITE_MODULE=/path/to/@electric-sql/pglite/dist/index.js node --test test/server/push_notifications_sql.test.mjs`
- Backend: `./gradlew test --tests '*PushNotificationPrivacyTest'`

Before production rollout, use a dedicated test account/device to verify denied/granted permissions, foreground/background/terminated delivery and taps, account switching, token renewal, master/category opt-out, quiet-hour boundaries, and retry after disabling/re-enabling worker credentials. Do not test recipient isolation using public topic broadcasts. Inspect queue status/counts instead of copying device tokens or message payloads into logs.
