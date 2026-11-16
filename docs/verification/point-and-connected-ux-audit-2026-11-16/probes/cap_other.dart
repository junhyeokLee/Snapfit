// Read-only fixtures render the actual screens; no account, message or notification is sent.
import 'audit_support.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/notification/data/notification_repository.dart';
import 'package:snap_fit/features/notification/domain/entities/app_notification_item.dart';
import 'package:snap_fit/features/notification/presentation/providers/notification_provider.dart';
import 'package:snap_fit/features/notification/presentation/views/notification_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/support_center_screen.dart';

import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/support_center_screen_test.dart'
    as support;

class _AuditAuth extends AuthViewModel {
  @override
  Future<UserInfo?> build() async => const UserInfo(
    id: 'notification-audit-owner',
    name: '알림 검토 계정',
    email: 'notification-audit@example.test',
    provider: 'EMAIL',
  );
}

class _MemoryNotifications extends Fake implements NotificationRepository {
  _MemoryNotifications(this.rows);
  final List<AppNotificationItem> rows;
  int? requestedLimit;
  int markAllCalls = 0;

  @override
  Future<List<AppNotificationItem>> fetchInbox({int limit = 50}) async {
    requestedLimit = limit;
    return rows.take(limit).toList(growable: false);
  }

  @override
  Future<int> fetchUnreadCount() async =>
      rows.where((row) => !row.isRead).length;

  @override
  Future<int> fetchRetentionDays() async => 90;

  @override
  Future<void> markAllRead() async {
    markAllCalls++;
    throw StateError('This audit must not write notification state.');
  }
}

void main() {
  setUpAll(auditFonts);

  testWidgets(
    'audit other: unread beyond the real sixty-row inbox cannot be reached',
    (tester) async {
      auditViewport(tester);
      SharedPreferences.setMockInitialValues({});
      final now = DateTime.now();
      final repository = _MemoryNotifications(
        List.generate(
          61,
          (index) => AppNotificationItem(
            id: index + 1,
            type: 'album_comment',
            title: index < 60 ? '확인한 댓글 알림 ${index + 1}' : '이전의 읽지 않은 알림',
            body: '앨범에 남겨진 댓글을 확인해 보세요.',
            createdAt: now.subtract(Duration(minutes: index)),
            isRead: index < 60,
            userId: 'notification-audit-owner',
          ),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          authViewModelProvider.overrideWith(_AuditAuth.new),
          notificationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: SnapFitTheme.light(),
            builder: (_, child) => auditFrame(child!),
            home: const NotificationScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Use the actual provider, which requests 60 despite the repository's default of 50.
      expect(repository.requestedLimit, 60);
      expect(await container.read(notificationUnreadCountProvider.future), 1);
      expect(container.read(notificationInboxProvider).requireValue.length, 60);
      final markAll = find.byKey(const ValueKey('inbox-mark-all'));
      expect(tester.widget<TextButton>(markAll).onPressed, isNull);
      expect(find.text('이전 알림 더 보기'), findsNothing);
      await auditCapture(tester, 'other-inbox-sixty-read-top');
      final scroll = find
          .descendant(
            of: find.byKey(const PageStorageKey('inbox-list')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('inbox-item-60')),
        300,
        scrollable: scroll,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('inbox-item-61')), findsNothing);
      expect(repository.markAllCalls, 0);
      await auditCapture(tester, 'other-inbox-sixty-read-end');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'audit other: a resolved support row exposes the sent content but no result or reply',
    (tester) async {
      final fixture = support.SupportCenterFixture(
        repository: support.SupportHistoryMemoryRepository(
          inquiries: [
            support.supportHistoryInquiry(
              59,
              status: 'RESOLVED',
              category: 'PAYMENT',
              subject: '포인트 이용 문의',
              message: '포인트 이용 내역에 대해 문의했습니다. 처리 결과를 확인하고 싶어요.',
            ),
          ],
        ),
      );
      await support.mountSupportCenter(tester, fixture, capture: auditBoundary);
      expect(find.text('처리 완료'), findsOneWidget);
      final row = find.byKey(const ValueKey('support-inquiry-59'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('support-inquiry-body-59')).hitTestable(),
        findsOneWidget,
      );
      expect(find.text('답변'), findsNothing);
      expect(find.text('처리 결과'), findsNothing);
      await auditCapture(tester, 'other-support-resolved-own-message');
      expect(find.byType(SupportCenterScreen), findsOneWidget);
    },
  );
}
