import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/navigation/web_app_location.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/attendance/data/attendance_repository.dart';
import 'package:snap_fit/features/attendance/domain/attendance_status.dart';
import 'package:snap_fit/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:snap_fit/features/attendance/presentation/views/attendance_screen.dart';
import 'package:snap_fit/features/attendance/presentation/widgets/attendance_entry_card.dart';

class _Repository implements AttendanceRepository {
  int claims = 0;
  @override
  String get currentUserId => 'owner';
  @override
  Stream<String?> get authChanges => const Stream.empty();
  @override
  Future<AttendanceStatus> fetchStatus() async => AttendanceStatus.fromJson({
    'serverTime': '2026-10-26T00:00:00Z',
    'serverDate': '2026-10-26',
    'timezone': 'Asia/Seoul',
    'nextResetAt': '2026-10-26T15:00:00Z',
    'checkedInToday': false,
    'currentStreak': 0,
    'cycleDay': 1,
    'todayReward': 10,
    'weeklyRewards': [10, 10, 20, 10, 10, 10, 30],
    'month': '2026-10',
    'monthPoints': 0,
    'monthAttendanceCount': 0,
    'history': [],
    'claimed': false,
    'awardedPoints': 0,
    'balance': 500,
  });
  @override
  Future<AttendanceStatus> claim() {
    claims++;
    return fetchStatus();
  }
}

class _Observer extends NavigatorObserver {
  RouteSettings? latest;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      latest = route.settings;
}

void main() {
  testWidgets(
    'free-point entry opens the private attendance route without claiming',
    (tester) async {
      final repository = _Repository();
      final observer = _Observer();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            attendanceRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: SnapFitTheme.light(),
            navigatorObservers: [observer],
            home: const Scaffold(body: AttendanceEntryCard()),
          ),
        ),
      );
      await tester.tap(find.text('출석체크 · 무료 포인트'));
      await tester.pumpAndSettle();
      expect(find.byType(AttendanceScreen), findsOneWidget);
      expect(
        (observer.latest! as WebAppRouteSettings).location,
        WebAppLocation.attendance,
      );
      expect(WebAppLocation.attendance.isPublic, isFalse);
      expect(repository.claims, 0);
      expect(find.text('출석하고 10P 받기'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
