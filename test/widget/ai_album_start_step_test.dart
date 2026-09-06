import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_start_step.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets(
    'guides manual album creation toward AI template start without photo-library generation copy',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var aiTapped = false;
      var manualTapped = false;

      await tester.pumpWidget(
        _wrap(
          AiAlbumStartStep(
            aiPointCost: 300,
            onAiStart: () => aiTapped = true,
            onManualStart: () => manualTapped = true,
          ),
        ),
      );

      expect(find.text('앨범 만들기'), findsOneWidget);
      expect(find.text('먼저 앨범 틀을 고르고, 사진은 직접 넣어요'), findsOneWidget);
      expect(find.text('직접 만들기'), findsOneWidget);
      expect(find.textContaining('빈 앨범부터 차근차근'), findsOneWidget);
      expect(find.text('AI 템플릿으로 시작'), findsOneWidget);
      expect(find.text('분위기에 맞춰 사진 슬롯과 문구를 잡아드려요.'), findsOneWidget);
      expect(find.text('사진은 직접 고르고 바꿀 수 있어요'), findsOneWidget);
      expect(find.text('첫 템플릿 무료'), findsOneWidget);
      expect(find.text('사진첩 자동 생성'), findsNothing);
      expect(find.text('AI 초안'), findsNothing);
      expect(find.textContaining('AI가 사진첩'), findsNothing);
      expect(find.textContaining('사진을 골라'), findsNothing);
      expect(find.textContaining('포인트'), findsNothing);
      expect(find.textContaining('300P'), findsNothing);

      expect(find.text('어떤 앨범을 만들까요?'), findsNothing);
      expect(find.text('여행'), findsNothing);
      expect(find.text('커플'), findsNothing);
      expect(find.text('가족'), findsNothing);

      await tester.tap(find.text('AI 템플릿으로 시작'));
      await tester.pump();
      expect(aiTapped, isTrue);

      await tester.tap(find.text('직접 만들기'));
      await tester.pump();
      expect(manualTapped, isTrue);
    },
  );
}
