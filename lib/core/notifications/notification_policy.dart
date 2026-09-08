/// Shared local policy for remote and bundled notifications.
bool allowsNotification({
  required bool all,
  required bool categoryEnabled,
  required bool nightMute,
  required DateTime now,
}) =>
    all && categoryEnabled && !(nightMute && (now.hour >= 22 || now.hour < 8));

String notificationCategory(Map<String, dynamic> data) {
  final category = data['category']?.toString();
  if (category != null && category.isNotEmpty) return category;
  return switch (data['type']?.toString()) {
    'order_status' => 'order',
    'album_invite' || 'invite_accepted' || 'album_member_changed' => 'invite',
    'album_comment' => 'comment',
    'template_new' || 'template_update' => 'new_template',
    'marketing' => 'marketing',
    _ => 'general',
  };
}
