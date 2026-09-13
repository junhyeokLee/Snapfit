export interface PushPreferences {
  all_enabled?: boolean; order_enabled?: boolean; invite_enabled?: boolean;
  comment_enabled?: boolean; marketing_enabled?: boolean; new_template_enabled?: boolean; night_mute?: boolean;
}
export function deliveryPolicy(category: string, preferences: PushPreferences | null,
  timezoneOffsetMinutes: number, now: Date): { allowed: boolean; ttlSeconds: number } {
  const prefs = preferences ?? {};
  if (prefs.all_enabled === false) return { allowed: false, ttlSeconds: 0 };
  const columns: Record<string, keyof PushPreferences> = { order: 'order_enabled', invite: 'invite_enabled',
    comment: 'comment_enabled', marketing: 'marketing_enabled', new_template: 'new_template_enabled' };
  const column = columns[category];
  if (column && (prefs[column] ?? category !== 'marketing') === false) return { allowed: false, ttlSeconds: 0 };
  const local = new Date(now.getTime() + timezoneOffsetMinutes * 60_000);
  const hour = local.getUTCHours();
  if (prefs.night_mute && (hour >= 22 || hour < 8)) return { allowed: false, ttlSeconds: 0 };
  // A notification queued at 21:59 must expire before quiet hours, even if offline.
  const untilQuiet = (22 - hour) * 3600 - local.getUTCMinutes() * 60 - local.getUTCSeconds();
  return { allowed: true, ttlSeconds: prefs.night_mute ? Math.min(300, untilQuiet) : 300 };
}
export function fcmMessage(notification: { id: number; user_id: string; type: string; category: string;
  title: string; body: string; data?: Record<string, unknown>; deeplink?: string }, token: string,
  now: Date, ttlSeconds: number) {
  const data: Record<string, string> = {};
  for (const [key, value] of Object.entries(notification.data ?? {})) data[key] = String(value);
  Object.assign(data, { notificationId: String(notification.id), userId: notification.user_id,
    type: notification.type, category: notification.category, deeplink: notification.deeplink ?? '' });
  return { message: { token, notification: { title: notification.title, body: notification.body }, data,
    android: { priority: 'high', ttl: `${ttlSeconds}s`, notification: {
      channel_id: 'snapfit_push', tag: `notification-${notification.id}` } },
    apns: { headers: { 'apns-push-type': 'alert', 'apns-priority': '10',
      'apns-collapse-id': `notification-${notification.id}`,
      'apns-expiration': String(Math.floor(now.getTime() / 1000) + ttlSeconds) },
      payload: { aps: { sound: 'default' } } } } };
}
export function retryDelaySeconds(attempt: number): number { return Math.min(3600, 30 * 2 ** Math.max(0, attempt - 1)); }
export function isInvalidToken(response: unknown): boolean {
  const error = (response as { error?: { details?: Array<{ errorCode?: string }> } })?.error;
  return error?.details?.some((detail) => detail.errorCode === 'UNREGISTERED') === true;
}
export function authorizedSecret(expected: string, supplied: string): boolean {
  if (expected.length < 32 || expected.length !== supplied.length) return false;
  let difference = 0;
  for (let i = 0; i < expected.length; i++) difference |= expected.charCodeAt(i) ^ supplied.charCodeAt(i);
  return difference === 0;
}
