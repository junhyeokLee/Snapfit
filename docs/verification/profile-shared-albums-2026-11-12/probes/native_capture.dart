// 실제 마이 위젯을 가상 계정과 메모리 상태로 캡처한다. 서버에는 연결하지 않는다.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/social/presentation/views/social_profile_screen.dart';

import '../../../../test/widget/social_profile_personal_area_test.dart'
    show profilePersonalReviewOverrides, profilePersonalReviewApp;

class _CaptureBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _Home extends HomeViewModel {
  _Home(this.scene);
  final String scene;
  final pending = Completer<List<Album>>();

  @override
  FutureOr<List<Album>> build() {
    if (scene == 'loading') return pending.future;
    if (scene == 'error') throw StateError('fixture unavailable');
    return const [
      Album(id: 1, userId: 'friend-a', title: '함께 남긴 여행'),
      Album(id: 2, userId: 'owner-a', title: '나의 앨범'),
      Album(id: 3, userId: 'friend-b', title: '우리의 주말'),
    ];
  }
}

void _repaint(RenderObject node) {
  node.visitChildren(_repaint);
  if (node.attached) node.markNeedsPaint();
}

void main() {
  _CaptureBinding();
  for (final scene in ['loading', 'error', 'success']) {
    for (final large in [false, true]) {
      testWidgets('capture profile shared albums $scene large=$large', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 2;
        tester.view.physicalSize = Size(large ? 640 : 780, 1688);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        for (final (family, paths) in [
          ('MaterialIcons', ['fonts/MaterialIcons-Regular.otf']),
          (
            'NotoSans',
            [
              'assets/fonts/NotoSansKR-Regular.ttf',
              'assets/fonts/NotoSansKR-SemiBold.ttf',
              'assets/fonts/NotoSansKR-Bold.ttf',
            ],
          ),
        ]) {
          final loader = FontLoader(family);
          for (final path in paths) {
            loader.addFont(rootBundle.load(path));
          }
          await loader.load();
        }
        final home = _Home(scene);
        final container = ProviderContainer(
          overrides: profilePersonalReviewOverrides(home: home),
        );
        addTearDown(container.dispose);
        final key = GlobalKey();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: RepaintBoundary(
              key: key,
              child: profilePersonalReviewApp(
                const SocialProfileScreen(),
                dark: large,
                scale: large ? 1.8 : 1,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final row = find.byKey(const ValueKey('profile-shared-albums'));
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        expect(row.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        for (final view in tester.binding.renderViews) {
          _repaint(view);
        }
        await tester.pump(const Duration(milliseconds: 32));
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final root = Platform.environment['PROFILE_QA_DIR']!;
            final file = File('$root/$scene${large ? '-large-dark' : ''}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
