class AppNotificationItem {
  final int id;
  final String type;
  final String title;
  final String body;
  final String? deeplink;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic> data;
  final String? userId;

  const AppNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.deeplink,
    this.data = const {},
    this.userId,
  });

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt']?.toString();
    final parsed = createdAtRaw == null
        ? null
        : DateTime.tryParse(createdAtRaw)?.toLocal();

    return AppNotificationItem(
      id: (json['id'] as num?)?.toInt() ?? -1,
      type: json['type']?.toString() ?? 'general',
      title: json['title']?.toString() ?? '알림',
      body: json['body']?.toString() ?? '',
      deeplink: json['deeplink']?.toString(),
      createdAt: parsed ?? DateTime.now(),
      isRead: json['isRead'] == true,
      data: Map<String, dynamic>.from(json['data'] as Map? ?? {}),
      userId: json['userId']?.toString(),
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
      data: data,
      userId: userId,
    );
  }
}
