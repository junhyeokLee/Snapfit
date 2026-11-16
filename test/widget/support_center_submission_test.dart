import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/profile/domain/support_inquiry.dart';
import 'package:snap_fit/features/profile/presentation/views/support_inquiry_screen.dart';

import 'support_center_screen_test.dart'
    show
        SupportCenterFixture,
        SupportHistoryMemoryRepository,
        mountSupportCenter,
        supportHistoryInquiry;

Finder _key(String value) => find.byKey(ValueKey(value));

VoidCallback _action(WidgetTester tester, String key) {
  final widget = tester.widget(_key(key));
  if (widget is ButtonStyleButton) return widget.onPressed!;
  if (widget is IconButton) return widget.onPressed!;
  throw StateError('검증할 실제 버튼이 아닙니다: $key');
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key));
  await tester.pumpAndSettle();
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

Future<VoidCallback> _prepareSubmission(WidgetTester tester) async {
  // 초기 목록이 계속 로딩 중이어도 작성은 가능하다. 탭 전에 settle하지 않는다.
  await tester.ensureVisible(_key('support-history-new'));
  await tester.tap(_key('support-history-new'));
  await tester.pumpAndSettle();
  expect(find.byType(SupportInquiryScreen), findsOneWidget);
  await tester.enterText(_key('support-subject'), '접수 뒤 다시 확인할 문의');
  await tester.enterText(_key('support-message'), '보낸 내용과 접수 상태를 다시 확인하고 싶어요.');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(_key('support-submit'));
  return _action(tester, 'support-submit');
}

void main() {
  testWidgets(
    'a saved inquiry stays acknowledged when the following history read fails',
    (tester) async {
      final repository = SupportHistoryMemoryRepository();
      repository.onRead = (_) {
        if (repository.reads.length == 1) {
          return const SupportInquiryPage(items: [], hasMore: false);
        }
        if (repository.reads.length == 2) {
          throw StateError('confirmed submission history read unavailable');
        }
        return SupportInquiryPage(
          items: List.of(repository.inquiries),
          hasMore: false,
        );
      };
      await mountSupportCenter(
        tester,
        SupportCenterFixture(repository: repository),
      );
      final staleSubmit = await _prepareSubmission(tester);
      staleSubmit();
      await tester.pumpAndSettle();
      expect(find.byType(SupportInquiryScreen), findsNothing);
      expect(find.text('문의 내역을 불러오지 못했어요'), findsOneWidget);
      expect(_key('support-history-retry'), findsOneWidget);

      // 일시적인 snackbar가 사라진 뒤에도 접수 성공은 실패와 구분돼야 한다.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.textContaining('접수'), findsOneWidget);
      staleSubmit();
      await tester.pumpAndSettle();
      expect(repository.submissions.length, 1);

      await _tap(tester, 'support-history-retry');
      expect(find.text('접수 뒤 다시 확인할 문의'), findsOneWidget);
      expect(_key('support-inquiry-101'), findsOneWidget);
      expect(_key('support-history-retry'), findsNothing);
      expect(repository.submissions.length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a failed refresh keeps the expanded inquiry until a retry replaces it',
    (tester) async {
      final repository = SupportHistoryMemoryRepository();
      repository.onRead = (_) {
        if (repository.reads.length == 2) {
          throw StateError('refresh unavailable');
        }
        return SupportInquiryPage(
          items: [
            supportHistoryInquiry(repository.reads.length == 1 ? 60 : 61),
          ],
          hasMore: false,
        );
      };
      await mountSupportCenter(
        tester,
        SupportCenterFixture(repository: repository),
      );
      await _tap(tester, 'support-inquiry-60');
      expect(_key('support-inquiry-body-60').hitTestable(), findsOneWidget);
      _action(tester, 'support-history-refresh')();
      await tester.pumpAndSettle();
      expect(find.text('문의 내역을 불러오지 못했어요'), findsOneWidget);
      expect(_key('support-inquiry-60'), findsOneWidget);
      await tester.ensureVisible(_key('support-inquiry-body-60'));
      await tester.pumpAndSettle();
      expect(_key('support-inquiry-body-60').hitTestable(), findsOneWidget);
      expect(find.text('사진을 프레임에 넣을 때 확인할 내용 60'), findsWidgets);

      await _tap(tester, 'support-history-retry');
      expect(_key('support-inquiry-61'), findsOneWidget);
      expect(_key('support-inquiry-60'), findsNothing);
      expect(_key('support-inquiry-body-60'), findsNothing);
      expect(repository.reads.map((read) => read.beforeId), [null, null, null]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a pending initial read cannot overwrite history reloaded after submission',
    (tester) async {
      final initialRead = Completer<SupportInquiryPage>();
      final repository = SupportHistoryMemoryRepository(
        inquiries: [supportHistoryInquiry(60)],
      );
      repository.onRead = (_) {
        if (repository.reads.length == 1) return initialRead.future;
        return SupportInquiryPage(
          items: repository.inquiries.reversed.toList(),
          hasMore: false,
        );
      };
      await mountSupportCenter(
        tester,
        SupportCenterFixture(repository: repository),
        settle: false,
      );
      final submit = await _prepareSubmission(tester);
      submit();
      await tester.pumpAndSettle();
      expect(find.byType(SupportInquiryScreen), findsNothing);
      expect(_key('support-inquiry-101'), findsOneWidget);
      expect(find.text('접수 뒤 다시 확인할 문의'), findsOneWidget);
      expect(repository.reads.length, 2);

      // 새 문의 접수 이전에 시작한 스냅샷이 뒤늦게 와도 최신 결과를 덮지 않는다.
      initialRead.complete(
        SupportInquiryPage(items: [supportHistoryInquiry(60)], hasMore: false),
      );
      await tester.pumpAndSettle();
      expect(_key('support-inquiry-101'), findsOneWidget);
      expect(find.text('접수 뒤 다시 확인할 문의'), findsOneWidget);
      expect(repository.submissions.length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'system back after an offstage submission still refreshes confirmed history',
    (tester) async {
      final accepted = Completer<void>();
      final repository = SupportHistoryMemoryRepository()
        ..pendingSubmission = accepted.future;
      await mountSupportCenter(
        tester,
        SupportCenterFixture(repository: repository),
      );
      final submit = await _prepareSubmission(tester);
      submit();
      await tester.pump(const Duration(milliseconds: 100));
      final navigator = Navigator.of(
        tester.element(find.byType(SupportInquiryScreen)),
      );
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(
            builder: (_) =>
                const Scaffold(body: Center(child: Text('별도로 열린 검토 화면'))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      accepted.complete();
      await tester.pumpAndSettle();
      expect(find.text('별도로 열린 검토 화면'), findsOneWidget);
      expect(repository.submissions.length, 1);

      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.byType(SupportInquiryScreen), findsOneWidget);
      // 완료 버튼의 true 결과 대신 Android 뒤로 가기의 null 결과를 재현한다.
      expect(await navigator.maybePop(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(SupportInquiryScreen), findsNothing);
      expect(find.text('접수 뒤 다시 확인할 문의'), findsOneWidget);
      expect(_key('support-inquiry-101'), findsOneWidget);
      expect(repository.submissions.length, 1);
      expect(repository.reads.length, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
