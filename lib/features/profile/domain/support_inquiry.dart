/// 고객이 접수한 문의의 내용과 서버에서 확인한 상태.
class SupportInquiry {
  const SupportInquiry({
    required this.id,
    required this.userId,
    required this.category,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String userId, category, subject, message, status;
  final DateTime createdAt;

  factory SupportInquiry.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int
        ? rawId
        : rawId is String
        ? int.tryParse(rawId)
        : null;
    final userId = json['user_id'];
    final category = json['category'];
    final subject = json['subject'];
    final message = json['message'];
    final status = json['status'];
    final createdAt = json['created_at'] is String
        ? DateTime.tryParse(json['created_at'] as String)
        : null;
    if (id == null ||
        id <= 0 ||
        userId is! String ||
        userId.trim().isEmpty ||
        category is! String ||
        subject is! String ||
        message is! String ||
        status is! String ||
        createdAt == null) {
      throw const FormatException('문의 정보를 확인하지 못했어요.');
    }
    return SupportInquiry(
      id: id,
      userId: userId,
      category: category,
      subject: subject,
      message: message,
      status: status,
      createdAt: createdAt.toUtc(),
    );
  }

  String get categoryLabel => switch (category.trim().toUpperCase()) {
    'GENERAL' => '계정 · 기타',
    'ORDER' => '주문',
    'PAYMENT' => '템플릿 · 소재 구매',
    'DELIVERY' => '인쇄 · 배송',
    'BUG' => '앨범 편집 · 오류',
    'ACCOUNT_DELETION' => '계정 삭제 요청',
    _ => '기타',
  };

  // 처리 완료는 실제 답변 발송이나 답변 본문이 존재한다는 뜻이 아니다.
  String get statusLabel => switch (status.trim().toUpperCase()) {
    'OPEN' => '접수됨',
    'IN_PROGRESS' => '확인 중',
    'RESOLVED' => '처리 완료',
    _ => '상태 확인 필요',
  };
}

class SupportInquiryPage {
  const SupportInquiryPage({required this.items, required this.hasMore});
  final List<SupportInquiry> items;
  final bool hasMore;

  int? get nextBeforeId => hasMore && items.isNotEmpty ? items.last.id : null;
}
