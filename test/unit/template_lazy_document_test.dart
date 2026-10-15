import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';

void main() {
  test('metadata and favorite copies do not materialize album documents', () {
    var calls = 0;
    final template = PremiumTemplate(
      id: 7,
      title: 'test',
      coverImageUrl: '',
      previewImages: const [],
      pageCount: 24,
      userCount: 0,
      documentBuilder: () {
        calls++;
        return '{"pages":[]}';
      },
    );
    final liked = template.copyWith(isLiked: true, likeCount: 1);
    expect(liked.title, 'test');
    expect(calls, 0);
    expect(liked.templateJson, '{"pages":[]}');
    expect(calls, 1);
    expect(liked.copyWith(templateJson: '{}').templateJson, '{}');
    expect(calls, 1);
    expect(
      PremiumTemplate.fromJson(liked.toJson()).templateJson,
      '{"pages":[]}',
    );
  });
}
