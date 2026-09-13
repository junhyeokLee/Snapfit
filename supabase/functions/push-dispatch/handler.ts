import { authorizedSecret, deliveryPolicy, fcmMessage, isInvalidToken, retryDelaySeconds } from './policy.ts';
import { googleAccessToken, parseServiceAccount } from './google-auth.ts';
import { dispatchDiagnostic, type DispatchStage } from './diagnostics.ts';

export function createPushDispatchHandler(dependencies: {
  env: (name: string) => string | undefined;
  adminClient: () => any;
  getAccessToken?: typeof googleAccessToken;
  logError?: (diagnostic: Record<string, unknown>) => void;
}): (req: Request) => Promise<Response> {
  const { env, adminClient } = dependencies;
  const logError = dependencies.logError ?? ((diagnostic) => console.error(JSON.stringify(diagnostic)));
  return async (req) => {
    if (req.method !== 'POST') return Response.json({ error: 'method_not_allowed' }, { status: 405 });
    if (!authorizedSecret(env('PUSH_DISPATCH_SECRET') ?? '', req.headers.get('X-Push-Secret') ?? '')) {
      return Response.json({ error: 'forbidden' }, { status: 403 });
    }
    if (env('PUSH_DELIVERY_ENABLED') !== 'true') {
      return Response.json({ error: 'push_delivery_disabled' }, { status: 503 });
    }
    let stage: DispatchStage = 'credential_parse';
    try {
      const account = parseServiceAccount(env('FIREBASE_SERVICE_ACCOUNT_JSON') ?? '{}');
      stage = 'oauth';
      const accessToken = await (dependencies.getAccessToken ?? googleAccessToken)(account);
      stage = 'admin_client';
      const supabase = adminClient();
      stage = 'cleanup';
      const { error: cleanupError } = await supabase.rpc('cleanup_notifications');
      if (cleanupError) throw cleanupError;
      stage = 'claim';
      const { data: rows, error } = await supabase.rpc('claim_push_deliveries', { p_limit: 25 });
      if (error) throw error;
      stage = 'delivery';
      const counts = { sent: 0, discarded: 0, retry: 0, failed: 0 };
      const finish = async (row: any, patch: Record<string, unknown>) => {
        const { error } = await supabase.from('push_outbox').update({ ...patch, locked_until: null })
          .eq('id', row.id).eq('lease_token', row.lease_token);
        if (error) throw error;
      };
      const deliver = async (row: any) => {
        try {
          const [deviceResult, notificationResult, prefsResult] = await Promise.all([
            supabase.from('push_devices').select('user_id,enabled,timezone_offset_minutes')
              .eq('token', row.token).eq('user_id', row.user_id).maybeSingle(),
            supabase.from('notifications').select('*').eq('id', row.notification_id).eq('user_id', row.user_id).maybeSingle(),
            supabase.from('push_preferences').select('*').eq('user_id', row.user_id).maybeSingle(),
          ]);
          for (const result of [deviceResult, notificationResult, prefsResult]) if (result.error) throw result.error;
          const device = deviceResult.data, notification = notificationResult.data;
          if (!device?.enabled || !notification) {
            await finish(row, { status: 'discarded', last_error: 'recipient_unavailable' }); counts.discarded++; return;
          }
          const now = new Date();
          const policy = deliveryPolicy(notification.category, prefsResult.data, device.timezone_offset_minutes, now);
          if (!policy.allowed) {
            await finish(row, { status: 'discarded', last_error: 'notification_preferences' }); counts.discarded++; return;
          }
          const response = await fetch(`https://fcm.googleapis.com/v1/projects/${encodeURIComponent(account.project_id)}/messages:send`, {
            method: 'POST', headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
            body: JSON.stringify(fcmMessage(notification, row.token, now, policy.ttlSeconds)), signal: AbortSignal.timeout(10_000),
          });
          const result = await response.json().catch(() => ({}));
          if (response.ok) {
            await finish(row, { status: 'sent', sent_at: new Date().toISOString(), last_error: null }); counts.sent++; return;
          }
          if (isInvalidToken(result)) {
            const { error } = await supabase.from('push_devices').delete().eq('token', row.token).eq('user_id', row.user_id);
            if (error) throw error;
            await finish(row, { status: 'discarded', last_error: 'unregistered_token' }); counts.discarded++; return;
          }
          // Permanent payload errors require operator correction. Never log tokens or message contents.
          if (response.status === 400 || response.status === 404) {
            await finish(row, { status: 'failed', last_error: `fcm_${response.status}` }); counts.failed++; return;
          }
          throw new Error(`fcm_${response.status}`);
        } catch (_) {
          const failed = row.attempts >= 10;
          await finish(row, { status: failed ? 'failed' : 'pending', last_error: 'delivery_failed',
            available_at: new Date(Date.now() + retryDelaySeconds(row.attempts) * 1000).toISOString() });
          failed ? counts.failed++ : counts.retry++;
        }
      };
      for (let i = 0; i < (rows ?? []).length; i += 5) await Promise.all(rows.slice(i, i + 5).map(deliver));
      return Response.json({ ok: true, ...counts });
    } catch (error) {
      const diagnostic = dispatchDiagnostic(error, stage);
      logError({ event: 'push_dispatch_failed', ...diagnostic });
      return Response.json({ error: 'push_dispatch_failed', ...diagnostic }, { status: 500 });
    }
  };
}
