import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_comment_widgets.dart';

const _author = SocialProfile(
  userId: 'haerin',
  displayName: '해린의 여행 기록',
  handle: 'haerin.archive',
);

Future<void> _mount(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
  SocialProfile author = _author,
  bool reply = false,
  ValueChanged<SocialProfile>? onProfile,
  VoidCallback? onReply,
  VoidCallback? onAction,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: SnapFitTheme.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SocialCommentTile(
            comment: SocialComment(
              id: 'comment',
              author: author,
              body: '다음에는 숲길도 함께 걸어요.',
              createdAt: DateTime.now().subtract(const Duration(days: 1)),
              parentCommentId: reply ? 'root' : null,
              parentAuthor: reply ? _author : null,
            ),
            workAuthorId: author.userId,
            onProfile: onProfile ?? (_) {},
            onReply: onReply ?? () {},
            action: IconButton(
              tooltip: '댓글 신고',
              onPressed: onAction ?? () {},
              icon: const Icon(Icons.more_horiz_rounded, size: 19),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

RenderParagraph _paragraph(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text(text), matching: find.byType(RichText)),
    );

void main() {
  setUpAll(() async {
    // 실제 한글 글꼴로 이름이 확보한 폭과 말줄임 여부를 확인한다.
    await (FontLoader('NotoSans')
          ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/NotoSansKR-SemiBold.ttf'))
          ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Bold.ttf')))
        .load();
  });

  testWidgets('320 large text gives the author a readable header line', (
    tester,
  ) async {
    final visited = <String>[];
    var replies = 0;
    var actions = 0;
    await _mount(
      tester,
      size: const Size(320, 844),
      scale: 1.8,
      onProfile: (profile) => visited.add(profile.userId),
      onReply: () => replies++,
      onAction: () => actions++,
    );

    final author = _paragraph(tester, _author.displayName);
    expect(author.didExceedMaxLines, isFalse);
    expect(author.size.width, greaterThan(140));
    final authorRect = tester.getRect(find.text(_author.displayName));
    final badgeRect = tester.getRect(find.text('작성자'));
    final timeRect = tester.getRect(find.text('1일 전'));
    expect(badgeRect.top, greaterThanOrEqualTo(authorRect.bottom));
    expect(timeRect.top, greaterThanOrEqualTo(authorRect.bottom));
    expect(_paragraph(tester, '1일 전').didExceedMaxLines, isFalse);

    await tester.tap(find.text(_author.displayName));
    await tester.tap(find.text('답글 달기'));
    await tester.tap(find.byTooltip('댓글 신고'));
    expect(visited, ['haerin']);
    expect(replies, 1);
    expect(actions, 1);
    expect(tester.takeException(), isNull);
  });

  for (final (label, size, scale) in [
    ('390 default', const Size(390, 844), 1.0),
    ('landscape large text', const Size(844, 390), 1.8),
  ]) {
    testWidgets('$label keeps a fitting author and metadata inline', (
      tester,
    ) async {
      await _mount(tester, size: size, scale: scale);
      final author = tester.getRect(find.text(_author.displayName));
      final badge = tester.getRect(find.text('작성자'));
      final time = tester.getRect(find.text('1일 전'));
      expect(
        _paragraph(tester, _author.displayName).didExceedMaxLines,
        isFalse,
      );
      expect(badge.left, greaterThan(author.right));
      expect(time.left, greaterThan(badge.right));
      expect(badge.center.dy, closeTo(author.center.dy, 1));
      expect(time.center.dy, closeTo(author.center.dy, 1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('indented large text replies retain useful author width', (
    tester,
  ) async {
    const author = SocialProfile(
      userId: 'long-author',
      displayName: '해린의 길고 긴 여행과 일상 기록',
      handle: 'haerin.long.archive',
    );
    await _mount(
      tester,
      size: const Size(320, 844),
      scale: 1.8,
      author: author,
      reply: true,
    );
    expect(_paragraph(tester, author.displayName).size.width, greaterThan(130));
    expect(
      tester.getRect(find.text('작성자')).top,
      greaterThanOrEqualTo(
        tester.getRect(find.text(author.displayName)).bottom,
      ),
    );
    expect(find.text('@haerin.archive님에게 답글'), findsOneWidget);
    expect(find.text('다음에는 숲길도 함께 걸어요.'), findsOneWidget);
    expect(find.text('답글 달기'), findsOneWidget);
    expect(_paragraph(tester, '1일 전').didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
  });
}
