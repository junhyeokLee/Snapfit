// 웹용 실제 사진 선택 위젯을 로컬 대역으로 재현한다. 서버와 파일 선택창은 호출하지 않는다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/gallery/browser_gallery_repository.dart';
import 'package:snap_fit/features/album/data/gallery/browser_photo_files.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_plan.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';
import 'package:snap_fit/shared/widgets/browser_photo_selection_sheet.dart';

import 'file:///tmp/snapfit-next-ux-20261116/audit_support.dart';

class _PhotoOwner extends Notifier<String?> {
  @override
  String? build() => 'audit-owner-a';
  void change(String? value) => state = value;
}

final _photoOwner = NotifierProvider<_PhotoOwner, String?>(_PhotoOwner.new);

void main() {
  setUpAll(auditFonts);

  testWidgets('web photo selection order and account change capture', (
    tester,
  ) async {
    auditViewport(tester);
    final container = ProviderContainer(
      overrides: [
        visibleOrderOwnerProvider.overrideWith((ref) => ref.watch(_photoOwner)),
      ],
    );
    final repository = BrowserGalleryRepository(
      currentOwner: () => container.read(_photoOwner),
    );
    final images = [
      ('A-첫 장면.jpg', 'assets/snapfit_home_square.jpg'),
      ('B-중간 장면.jpg', 'assets/snapfit_home_landscape.jpg'),
      ('C-마지막 장면.jpg', 'assets/snapfit_home_portrait.jpg'),
    ];
    // 기존 보관 목록이 A, B, C인 상황을 만든다. 실제 사진 원본은 앱의 번들 자산이다.
    await tester.runAsync(() async {
      final files = <BrowserPhotoFile>[];
      for (final (name, path) in images) {
        final data = await rootBundle.load(path);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        files.add(
          BrowserPhotoFile(
            name: name,
            size: bytes.length,
            readBytes: () async => bytes,
          ),
        );
      }
      final result = await repository.importFiles(files);
      expect(result.messages, isEmpty);
      expect(result.added, hasLength(3));
    });
    final photos = repository.photos;
    List<AssetEntity>? returned;
    final photoScope = ProviderContainer(
      parent: container,
      overrides: [galleryRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(() {
      photoScope.dispose();
      container.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: photoScope,
        child: auditFrame(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: SnapFitTheme.light(),
            home: Scaffold(
              appBar: AppBar(title: const Text('앨범 만들기')),
              body: Builder(
                builder: (context) => Center(
                  child: FilledButton(
                    onPressed: () async {
                      returned = await showBrowserPhotosSelectionSheet(
                        context,
                        maxSelection: 10,
                      );
                    },
                    child: const Text('사진 추가'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('사진 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('browser-photo-${photos[2].id}')));
    await tester.tap(find.byKey(ValueKey('browser-photo-${photos[0].id}')));
    await tester.pumpAndSettle();
    expect(find.text('2장 선택 완료'), findsOneWidget);
    await auditCapture(tester, '07-web-photo-selection-order');
    await tester.tap(
      find.byKey(const ValueKey('confirm-browser-photo-selection')),
    );
    await tester.pumpAndSettle();
    // 실제 반환 순서가 탭한 C,A가 아닌 보관 순서 A,C임을 기록한다.
    expect(returned!.map((photo) => photo.title), [
      'A-첫 장면.jpg',
      'C-마지막 장면.jpg',
    ]);
    final plan = TemplatePhotoFillPlan.create(
      pages: [
        for (var index = 0; index < 2; index++)
          [
            LayerModel(
              id: 'empty-$index',
              type: LayerType.image,
              position: Offset.zero,
              width: 100,
              height: 100,
            ),
          ],
      ],
      photos: returned!,
    );
    expect(plan.placements.map((placement) => placement.photo.title), [
      'A-첫 장면.jpg',
      'C-마지막 장면.jpg',
    ]);
    // ignore: avoid_print
    print(
      'ORDER: tapped=C,A; returned=${returned!.map((photo) => photo.title).join(',')}; auto-fill=${plan.placements.map((placement) => placement.photo.title).join(',')}',
    );

    await tester.tap(find.text('사진 추가'));
    await tester.pumpAndSettle();
    container.read(_photoOwner.notifier).change('audit-owner-b');
    await tester.pumpAndSettle();
    expect(find.textContaining('사진 선택창을 닫고 다시 열어주세요'), findsOneWidget);
    expect(find.byTooltip('사진 선택 닫기'), findsNothing);
    expect(find.byType(Image), findsNothing);
    final modal = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
    expect(modal.dismissible, isFalse);
    await auditCapture(tester, '08-web-photo-account-changed');
    // 네이티브 테스트의 시스템 뒤로가기는 정리용이다. 브라우저 Escape 동작은 검증하지 않는다.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
