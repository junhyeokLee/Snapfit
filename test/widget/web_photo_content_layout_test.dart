import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moments_widgets.dart';
import 'package:snap_fit/features/moments/presentation/widgets/web_moments_journal_layout.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_profile_widgets.dart';
import 'package:snap_fit/shared/web/web_photo_layout.dart';

void main() {
  testWidgets('web photograph columns preserve two readable desktop cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WebPhotoColumns(
            children: [
              for (var i = 0; i < 4; i++)
                SizedBox(
                  key: ValueKey('tile-$i'),
                  height: 200,
                  child: Text('사진 $i'),
                ),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const ValueKey('tile-0'))).width, 586);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('tile-0'))).dy,
      tester.getTopLeft(find.byKey(const ValueKey('tile-1'))).dy,
    );
    expect(tester.getTopLeft(find.byKey(const ValueKey('tile-2'))).dy, 228);
    expect(tester.takeException(), isNull);
  });

  testWidgets('web columns become one reading column at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: WebPhotoColumns(
              children: [
                for (var i = 0; i < 2; i++)
                  SizedBox(key: ValueKey('tile-$i'), height: 200),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const ValueKey('tile-0'))).width, 1000);
    expect(tester.getTopLeft(find.byKey(const ValueKey('tile-1'))).dy, 228);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop journal places progress beside photos, compact after first photo',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [1100.0, 390.0]) {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: WebMomentsJournalLayout(
                  monthNavigation: const Text('2026년 10월'),
                  records: const [
                    SizedBox(key: ValueKey('photo'), height: 300),
                    SizedBox(height: 200),
                  ],
                  weekly: const SizedBox(key: ValueKey('weekly'), height: 100),
                ),
              ),
            ),
          ),
        );
        final photo = tester.getTopLeft(find.byKey(const ValueKey('photo')));
        final week = tester.getTopLeft(find.byKey(const ValueKey('weekly')));
        if (width > 880) {
          expect(week.dx, greaterThan(photo.dx + 300));
        } else {
          expect(week.dy, greaterThan(photo.dy + 299));
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'web profile keeps relationship actions accessible at narrow large text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var followers = 0;
      var following = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: SocialProfileIdentity(
                  webLayout: true,
                  name: '오래 간직할 순간을 기록하는 사람',
                  handle: 'my.archive',
                  bio: '사진으로 천천히 모으는 나의 일상',
                  worksCount: 12,
                  followersCount: 38,
                  followingCount: 25,
                  onFollowers: () => followers++,
                  onFollowing: () => following++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('팔로워 38'));
      await tester.tap(find.text('팔로워 38'));
      await tester.ensureVisible(find.text('팔로잉 25'));
      await tester.tap(find.text('팔로잉 25'));
      expect(followers, 1);
      expect(following, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'desktop photograph height is bounded without changing native ratio',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final record = MomentRecord(
        id: 'portrait',
        recordDate: DateTime.utc(2026, 10, 26),
        caption: '',
        photos: const [
          MomentPhoto(
            id: 'photo',
            path: 'fixture/photo.jpg',
            url: 'asset:assets/cover/cover1.png',
            width: 600,
            height: 800,
          ),
        ],
        revision: 1,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MomentRecordCard(
                record: record,
                onEdit: () {},
                maxPhotoHeight: 560,
              ),
            ),
          ),
        ),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('moment-photo-frame-portrait')))
            .height,
        closeTo(560, .1),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 390,
                child: MomentRecordCard(record: record, onEdit: () {}),
              ),
            ),
          ),
        ),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('moment-photo-frame-portrait')))
            .height,
        closeTo(520, .1),
      );
    },
  );
}
