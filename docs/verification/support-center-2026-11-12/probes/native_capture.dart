// 실제 고객센터 위젯과 메모리 자료로 확인한다. 문의를 외부로 발송하지 않는다.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/profile/domain/support_inquiry.dart';

import '../../../../test/widget/support_center_screen_test.dart';

class _CaptureBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

void _repaint(RenderObject object) {
  object.visitChildren(_repaint);
  if (object.attached) object.markNeedsPaint();
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  for (final view in tester.binding.renderViews) {
    _repaint(view);
  }
  await tester.pump(const Duration(milliseconds: 32));
  expect(tester.takeException(), isNull);
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('${Platform.environment['SUPPORT_QA_DIR']}/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

List<SupportInquiry> _samples() => [
  supportHistoryInquiry(
    104,
    subject: '프레임을 바꾼 뒤 사진 위치가 달라졌어요',
    message:
        '여행 앨범의 사진을 다른 프레임에 넣었는데 위치가 달라졌어요.\n'
        '직접 조정해 저장하면 되는지 확인 부탁드려요.',
    status: 'IN_PROGRESS',
  ),
  supportHistoryInquiry(
    103,
    subject: '인쇄한 앨범의 배송 상태가 궁금해요',
    message: '주문 내역에서 배송 정보를 확인하는 방법이 궁금해요.',
    category: 'DELIVERY',
  ),
  supportHistoryInquiry(
    102,
    subject: '소장한 디자인을 다시 적용하고 싶어요',
    message: '다른 앨범에 소장한 디자인을 적용하는 방법을 문의드려요.',
    category: 'PAYMENT',
    status: 'RESOLVED',
  ),
];

void main() {
  _CaptureBinding();
  setUpAll(() async {
    for (final (family, assets) in [
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
      for (final path in assets) {
        loader.addFont(rootBundle.load(path));
      }
      await loader.load();
    }
  });

  for (final scene in [
    'list',
    'empty',
    'error',
    'submitted',
    'large',
    'landscape',
  ]) {
    testWidgets('capture support center $scene', (tester) async {
      final key = GlobalKey();
      final repository = SupportHistoryMemoryRepository(
        inquiries: scene == 'empty' || scene == 'submitted' ? [] : _samples(),
      );
      if (scene == 'error') {
        repository.onRead = (_) => throw StateError('fixture offline');
      }
      await mountSupportCenter(
        tester,
        SupportCenterFixture(repository: repository),
        size: scene == 'large'
            ? const Size(320, 568)
            : scene == 'landscape'
            ? const Size(640, 320)
            : const Size(390, 844),
        dark: scene == 'large',
        scale: scene == 'large' ? 1.8 : 1,
        capture: key,
      );
      if (scene == 'submitted') {
        await tester.tap(find.byKey(const ValueKey('support-history-new')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('support-subject')),
          '앨범에 사진을 추가할 때 문의드려요',
        );
        await tester.enterText(
          find.byKey(const ValueKey('support-message')),
          '사진을 선택한 뒤 프레임에 넣었는데 적용되지 않아요. 확인 부탁드려요.',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await _capture(tester, key, '05-compose');
        final submit = find.byKey(const ValueKey('support-submit'));
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(repository.submissions.length, 1);
        expect(find.text('앨범에 사진을 추가할 때 문의드려요'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('support-inquiry-101')));
        await tester.pumpAndSettle();
        await _capture(tester, key, '06-submitted-history');
      } else {
        await _capture(tester, key, switch (scene) {
          'list' => '01-history',
          'empty' => '03-empty',
          'error' => '04-error',
          'large' => '07-large-dark',
          _ => '08-landscape',
        });
        if (scene == 'list') {
          await tester.tap(find.byKey(const ValueKey('support-inquiry-104')));
          await tester.pumpAndSettle();
          expect(
            find
                .byKey(const ValueKey('support-inquiry-body-104'))
                .hitTestable(),
            findsOneWidget,
          );
          await _capture(tester, key, '02-inquiry-content');
        }
      }
    });
  }
}
