import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_draft_generation_service.dart';

void main() {
  test(
    'generation timeout does not claim the remote request was cancelled',
    () {
      final result = AiAlbumDraftGenerationResult.templateFailed(
        code: 'template_generation_timeout',
      );
      expect(result.failureMessage, contains('처리 결과를 받지 못했어요'));
      expect(result.failureMessage, contains('요청 내용은 그대로'));
      expect(result.failureMessage, isNot(contains('중단')));
      expect(result.failureMessage, isNot(contains('취소')));
      expect(result.shouldChargePoints, isFalse);
    },
  );
  for (final (code, text) in [
    ('template_provider_rate_limited', '사용 한도'),
    ('template_provider_not_configured', '연결을 준비'),
    ('template_provider_model_unavailable', '연결을 준비'),
    ('template_provider_model_not_supported', '연결을 준비'),
    ('template_provider_free_only', '연결을 준비'),
    ('ai_generation_privacy_review_required', 'AI에 보내지 않았어요'),
    ('template_generation_timeout', '오래 걸려'),
  ]) {
    test('$code preserves the retry flow without charging points', () {
      final result = AiAlbumDraftGenerationResult.templateFailed(code: code);
      expect(result.shouldChargePoints, isFalse);
      expect(result.failureMessage, contains(text));
      expect(result.failureMessage, contains('포인트는 차감되지 않았어요'));
      expect(result.primaryCtaLabel, '디자인 요청 다시 보기');
      expect(result.status, AiAlbumDraftGenerationStatus.failed);
      expect(result.draft, isNull);
    });
  }
}
