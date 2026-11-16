import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moment_monthly_album_entry.dart';

void main() {
  testWidgets(
    'a saved monthly album stays reachable without remaining photos',
    (tester) async {
      var opens = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: SnapFitTheme.light(),
          home: Scaffold(
            body: MomentMonthlyAlbumEntry(
              journal: MomentJournal(
                today: DateTime.utc(2026, 11, 11),
                weekStart: DateTime.utc(2026, 11, 9),
                month: DateTime.utc(2026, 10),
                records: const [],
                weekPhotoCount: 0,
                monthlyAlbumId: 73,
              ),
              onPreview: () => opens++,
            ),
          ),
        ),
      );

      expect(find.text('모은 순간을 한 권의 앨범으로'), findsOneWidget);
      expect(find.text('10월의 앨범을 이어서 살펴보세요.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-monthly-album-entry')));
      expect(opens, 1);
    },
  );
}
