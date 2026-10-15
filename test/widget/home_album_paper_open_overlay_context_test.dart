import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_cover_thumbnail.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_paper_open_overlay.dart';
import '../helpers/fake_album.dart';

void main() {
  Future<GlobalKey<NavigatorState>> mount(WidgetTester tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => MaterialApp(
            navigatorKey: navigator,
            home: const Scaffold(body: Text('album home')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return navigator;
  }

  HomeAlbumPaperOpenOverlayController show(BuildContext context) =>
      HomeAlbumPaperOpenOverlay.show(
        context,
        album: fakeAlbum(id: 70, ratio: '1').copyWith(coverTheme: 'classic'),
        baseCanvasSize: const Size(500, 500),
        fallbackAsset: 'assets/snapfit_home_square.jpg',
      );

  testWidgets(
    'direct-link root Navigator context opens and dismisses album paper overlay',
    (tester) async {
      final navigator = await mount(tester);
      final rootContext = navigator.currentContext!;
      expect(Overlay.maybeOf(rootContext, rootOverlay: true), isNull);
      expect(
        Navigator.maybeOf(rootContext, rootNavigator: true),
        navigator.currentState,
      );
      final controller = show(rootContext);
      await tester.pumpAndSettle();
      expect(find.byType(HomeAlbumCoverThumbnail), findsOneWidget);
      expect(tester.takeException(), isNull);
      controller.dismiss();
      controller.dismiss();
      await tester.pumpAndSettle();
      expect(find.byType(HomeAlbumCoverThumbnail), findsNothing);
      expect(find.text('album home'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('normal route context keeps using its existing overlay', (
    tester,
  ) async {
    await mount(tester);
    final routeContext = tester.element(find.text('album home'));
    expect(Overlay.maybeOf(routeContext, rootOverlay: true), isNotNull);
    final controller = show(routeContext);
    await tester.pumpAndSettle();
    expect(find.byType(HomeAlbumCoverThumbnail), findsOneWidget);
    controller.dismiss();
    await tester.pumpAndSettle();
    expect(find.byType(HomeAlbumCoverThumbnail), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
