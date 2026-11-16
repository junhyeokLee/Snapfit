// 실제 고객센터 위젯을 로컬 가상 문의로 캡처한다. 전송은 실행하지 않는다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/profile/presentation/views/support_inquiry_screen.dart';

import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/support_center_screen_test.dart'
    show
        SupportCenterFixture,
        SupportHistoryMemoryRepository,
        mountSupportCenter,
        supportHistoryInquiry;

import 'capture_support.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

SupportHistoryMemoryRepository _repository() => SupportHistoryMemoryRepository(
  inquiries: [
    supportHistoryInquiry(
      243,
      subject: '편집한 앨범에 새 사진이 적용되지 않아요',
      message:
          '가족 앨범을 편집하고 있어요. 사진을 고른 뒤 프레임에 넣었는데 이전 사진이 그대로 보여요.\n'
          '앱을 다시 열어도 같아서 어떤 부분을 확인하면 되는지 문의드립니다.',
      category: 'BUG',
    ),
    supportHistoryInquiry(
      235,
      subject: '구매한 여행 템플릿을 다시 찾고 싶어요',
      message: '지난주에 구매한 여행 템플릿을 새 앨범에도 사용할 수 있는지 궁금해요.',
      category: 'PAYMENT',
      status: 'IN_PROGRESS',
    ),
    supportHistoryInquiry(
      221,
      subject: '인쇄 주문의 배송지를 확인하고 싶어요',
      message: '주문한 앨범이 발송되기 전에 배송지를 다시 확인하고 싶어요.',
      category: 'DELIVERY',
      status: 'RESOLVED',
    ),
  ],
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enterDraft(WidgetTester tester) async {
  await tester.ensureVisible(_key('support-subject'));
  await tester.enterText(
    _key('support-subject'),
    '편집한 앨범에 새 사진이 적용되지 않아요',
  );
  await tester.ensureVisible(_key('support-message'));
  await tester.enterText(
    _key('support-message'),
    '사진을 선택해서 프레임에 넣었는데 이전 사진이 그대로 보여요.\n'
    '앱을 다시 열어도 같아요. 어떤 부분을 확인하면 될까요?',
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(auditFonts);

  testWidgets('support design capture history expanded compose and category', (
    tester,
  ) async {
    final repository = _repository();
    await mountSupportCenter(
      tester,
      SupportCenterFixture(repository: repository),
      capture: auditBoundary,
    );
    await auditCapture(tester, 'support-01-history-390');

    await _tap(tester, _key('support-inquiry-243'));
    await auditCapture(tester, 'support-02-history-expanded-390');

    await _tap(tester, _key('support-history-new'));
    expect(find.byType(SupportInquiryScreen), findsOneWidget);
    await auditCapture(tester, 'support-03-compose-390');

    await _tap(tester, _key('support-category'));
    await auditCapture(tester, 'support-04-category-390');
    await _tap(tester, find.text('앨범 편집 · 오류').last);

    await _enterDraft(tester);
    await tester.ensureVisible(_key('support-submit'));
    await tester.pumpAndSettle();
    await auditCapture(tester, 'support-05-compose-filled-390');
    expect(repository.submissions, isEmpty);
  });

  testWidgets('support design capture narrow large text dark', (tester) async {
    final repository = _repository();
    await mountSupportCenter(
      tester,
      SupportCenterFixture(repository: repository),
      size: const Size(320, 568),
      dark: true,
      scale: 1.6,
      capture: auditBoundary,
    );
    await _tap(tester, _key('support-inquiry-243'));
    await auditCapture(tester, 'support-06-expanded-320-large-dark');

    await _tap(tester, _key('support-history-new'));
    expect(find.byType(SupportInquiryScreen), findsOneWidget);
    await auditCapture(tester, 'support-07-compose-320-large-dark');

    await _enterDraft(tester);
    await tester.ensureVisible(_key('support-submit'));
    await tester.pumpAndSettle();
    await auditCapture(tester, 'support-08-compose-action-320-large-dark');
    expect(_key('support-submit').hitTestable(), findsOneWidget);
    expect(repository.submissions, isEmpty);
  });
}
