class AppNotificationItem {
  final int id;
  final String type;
  final String title;
  final String body;
  final String? deeplink;
  final DateTime createdAt;
  final bool isRead;

  const AppNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.deeplink,
  });

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt']?.toString();
    DateTime? parsed;
    if (createdAtRaw != null && createdAtRaw.isNotEmpty) {
      // 서버가 timezone 없이 내려줄 때 UTC 기준으로 해석해 KST(UTC+9)로 고정 표시
      final utcSource =
          createdAtRaw.endsWith('Z') ? createdAtRaw : '${createdAtRaw}Z';
      final utc = DateTime.tryParse(utcSource)?.toUtc();
      if (utc != null) {
        parsed = utc.add(const Duration(hours: 9));
      }
    }

    return AppNotificationItem(
      id: (json['id'] as num?)?.toInt() ?? -1,
      type: json['type']?.toString() ?? 'general',
      title: json['title']?.toString() ?? '알림',
      body: json['body']?.toString() ?? '',
      deeplink: json['deeplink']?.toString(),
      createdAt: parsed ?? DateTime.now(),
      isRead: json['isRead'] == true,
    );
  }

  AppNotificationItem copyWith({bool? isRead}) {
    return AppNotificationItem(
      id: id,
      type: type,
      title: title,
      body: body,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      deeplink: deeplink,
    );
  }
}
