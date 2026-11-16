import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/social/data/social_repository.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_work_detail_screen.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_comment_widgets.dart';

class _Repository extends Mock implements SocialRepository {}

class _Viewer extends Notifier<String?> {
  @override
  String? build() => 'me';
  void change(String? actor) => state = actor;
}

final _viewer = NotifierProvider<_Viewer, String?>(_Viewer.new);

const _author = SocialProfile(
  userId: 'author',
  displayName: '윤슬',
  handle: 'yoon.seul',
);
const _friend = SocialProfile(
  userId: 'friend',
  displayName: '민서',
  handle: 'minseo.day',
);

SocialComment _comment(
  String id, {
  String body = '햇살이 참 좋네요.',
  int minute = 0,
  String? parent,
  String? root,
  SocialProfile? parentAuthor,
  List<SocialProfile> mentions = const [],
}) => SocialComment(
  id: id,
  author: _friend,
  body: body,
  createdAt: DateTime.utc(2026, 11, 3, 2, minute),
  parentCommentId: parent,
  rootCommentId: root,
  parentAuthor: parentAuthor,
  mentions: mentions,
);

Future<ProviderContainer> _mount(
  WidgetTester tester,
  _Repository repository, {
  List<SocialComment>? comments,
  bool dark = false,
  double scale = 1,
  Size size = const Size(390, 844),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final items = comments ?? [_comment('root')];
  final container = ProviderContainer(
    overrides: [
      socialCurrentUserIdProvider.overrideWith((ref) => ref.watch(_viewer)),
      socialAuthStateProvider.overrideWith((_) => const Stream.empty()),
      socialRepositoryProvider.overrideWithValue(repository),
      socialWorkProvider.overrideWith(
        (_, _) async => SocialWork(
          id: 'work',
          author: _author,
          title: '산책하다 잠깐',
          caption: '집에 가는 길에 빛이 좋아서 한 장.',
          createdAt: DateTime.utc(2026, 11, 3),
          kind: 'moment',
          commentCount: items.length,
        ),
      ),
      socialCommentsPageProvider.overrideWith(
        (_, _) async => SocialCommentPage(
          items: items.reversed.toList(),
          hasMore: false,
          nextOffset: items.length,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const SocialWorkDetailScreen(workId: 'work'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await _show(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'mention tokens share server punctuation, email, and length boundaries',
    () {
      ({String query, TextRange range})? token(String text, [int? caret]) =>
          socialMentionToken(
            TextEditingValue(
              text: text,
              selection: TextSelection.collapsed(offset: caret ?? text.length),
            ),
          );
      expect(token('(@minseo.old),다음', 5)?.query, 'min');
      expect(
        token('(@minseo.old),다음', 5)?.range,
        const TextRange(start: 1, end: 12),
      );
      expect(token('이야기,@min')?.query, 'min');
      expect(token('mail@min'), isNull);
      expect(token('@@min'), isNull);
      expect(token('@abcdefghijklmnopqrstuvwxyz'), isNull);
      expect(
        socialMentionToken(
          const TextEditingValue(
            text: '@min',
            selection: TextSelection(baseOffset: 1, extentOffset: 4),
          ),
        ),
        isNull,
      );
      expect(token('@'), isNotNull);
      expect(token(''), isNull);
    },
  );

  testWidgets(
    'reply composer stays usable with large text on a narrow dark screen',
    (tester) async {
      await _mount(
        tester,
        _Repository(),
        dark: true,
        scale: 1.8,
        size: const Size(320, 568),
      );
      await _tap(tester, 'social-comment-reply-root');
      final input = find.byKey(const ValueKey('social-comment-input'));
      await _show(tester, input);
      await tester.enterText(input, '오래 간직하고 싶은 장면이에요.');
      await tester.pumpAndSettle();
      await _show(tester, find.byKey(const ValueKey('social-comment-send')));
      expect(find.text('답글 보내기').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'loaded roots keep replies together and missing parents stay usable',
    (tester) async {
      await _mount(
        tester,
        _Repository(),
        comments: [
          _comment('root'),
          _comment('other-root', minute: 1),
          _comment(
            'reply',
            minute: 2,
            parent: 'root',
            root: 'root',
            parentAuthor: _friend,
          ),
          _comment(
            'orphan',
            minute: 3,
            parent: 'deleted-parent',
            root: 'deleted-root',
          ),
        ],
      );
      final tiles = tester.widgetList<SocialCommentTile>(
        find.byType(SocialCommentTile),
      );
      expect(tiles.map((tile) => tile.comment.id), [
        'root',
        'reply',
        'other-root',
        'orphan',
      ]);
      expect(find.text('@minseo.day님에게 답글'), findsOneWidget);
      expect(find.text('이전 댓글에 남긴 답글'), findsOneWidget);
      await _tap(tester, 'social-comment-reply-orphan');
      expect(
        find.byKey(const ValueKey('social-comment-reply-target')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'lost reply response reuses its request and cancelling preserves the draft',
    (tester) async {
      final repository = _Repository();
      final requests = <String?>[];
      var calls = 0;
      when(
        () => repository.addComment(
          'work',
          '저도 이 길 좋아해요.',
          requestId: any(named: 'requestId'),
          parentCommentId: 'root',
        ),
      ).thenAnswer((invocation) async {
        requests.add(invocation.namedArguments[#requestId] as String?);
        if (calls++ == 0) throw StateError('response lost');
        return _comment('sent', parent: 'root', root: 'root');
      });
      await _mount(tester, repository);
      await _tap(tester, 'social-comment-reply-root');
      final input = find.byKey(const ValueKey('social-comment-input'));
      await tester.enterText(input, '저도 이 길 좋아해요.');
      await tester.pumpAndSettle();
      await _tap(tester, 'social-comment-send');
      expect(
        find.byKey(const ValueKey('social-comment-reply-target')),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(input).controller!.text, '저도 이 길 좋아해요.');
      await _tap(tester, 'social-comment-send');
      expect(requests, hasLength(2));
      expect(requests.first, isNotNull);
      expect(requests.toSet(), hasLength(1));
      expect(tester.widget<TextField>(input).controller!.text, isEmpty);
      expect(
        find.byKey(const ValueKey('social-comment-reply-target')),
        findsNothing,
      );
      await _tap(tester, 'social-comment-reply-root');
      await tester.enterText(input, '아직 쓰고 있는 답글');
      await tester.pumpAndSettle();
      await _tap(tester, 'social-comment-cancel-reply');
      expect(tester.widget<TextField>(input).controller!.text, '아직 쓰고 있는 답글');
      expect(find.text('댓글 남기기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an unavailable remote parent clears only the reply target and keeps the draft',
    (tester) async {
      final repository = _Repository();
      when(
        () => repository.addComment(
          'work',
          '계속 작성하던 이야기',
          requestId: any(named: 'requestId'),
          parentCommentId: 'root',
        ),
      ).thenThrow(
        const SocialActionException(
          '답글을 달 댓글을 찾을 수 없어요. 댓글 목록을 새로 확인해 주세요.',
          code: 'social_comment_parent_unavailable',
        ),
      );
      await _mount(tester, repository);
      await _tap(tester, 'social-comment-reply-root');
      final input = find.byKey(const ValueKey('social-comment-input'));
      await tester.enterText(input, '계속 작성하던 이야기');
      await tester.pumpAndSettle();
      await _tap(tester, 'social-comment-send');
      expect(
        find.byKey(const ValueKey('social-comment-reply-target')),
        findsNothing,
      );
      expect(tester.widget<TextField>(input).controller!.text, '계속 작성하던 이야기');
      expect(find.text('댓글 남기기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mention search replaces the active token and ignores an old account result',
    (tester) async {
      final repository = _Repository();
      final pending = Completer<List<SocialProfile>>();
      when(
        () => repository.searchProfiles('min'),
      ).thenAnswer((_) async => [_friend]);
      when(
        () => repository.searchProfiles('late'),
      ).thenAnswer((_) => pending.future);
      final container = await _mount(tester, repository);
      final input = find.byKey(const ValueKey('social-comment-input'));
      await _show(tester, input);
      await tester.enterText(input, '여기 @min');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));
      await tester.pumpAndSettle();
      await _tap(tester, 'social-mention-friend');
      expect(
        tester.widget<TextField>(input).controller!.text,
        '여기 @minseo.day ',
      );
      expect(
        find.byKey(const ValueKey('social-mention-suggestions')),
        findsNothing,
      );
      await tester.enterText(input, '(@minseo.old),다음');
      tester.widget<TextField>(input).controller!.selection =
          const TextSelection.collapsed(offset: 5);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));
      await tester.pumpAndSettle();
      await _tap(tester, 'social-mention-friend');
      expect(
        tester.widget<TextField>(input).controller!.text,
        '(@minseo.day),다음',
      );
      expect(
        tester.widget<TextField>(input).controller!.selection.baseOffset,
        '(@minseo.day'.length,
      );
      await tester.enterText(input, '@late');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));
      container.read(_viewer.notifier).change('new-viewer');
      await tester.pump();
      pending.complete([_friend]);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).controller!.text, isEmpty);
      expect(
        find.byKey(const ValueKey('social-mention-suggestions')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('social-comment-reply-target')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'only resolved handles are links, including on a compact dark layout',
    (tester) async {
      final visited = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: SnapFitTheme.dark(),
          home: Scaffold(
            body: SizedBox(
              width: 280,
              child: SocialCommentTile(
                comment: _comment(
                  'reply',
                  body:
                      '@yoon.seul 여기 좋아요. @unknown은 일반 글이에요. '
                      '@@yoon.seul mail@yoon.seul',
                  parent: 'root',
                  root: 'root',
                  parentAuthor: _author,
                  mentions: [_author],
                ),
                workAuthorId: 'author',
                onProfile: (profile) => visited.add(profile.userId),
                onReply: () {},
                action: const SizedBox(width: 40),
              ),
            ),
          ),
        ),
      );
      final body = tester.widget<Text>(
        find.descendant(
          of: find.byType(SocialCommentBody),
          matching: find.byType(Text),
        ),
      );
      final spans = (body.textSpan! as TextSpan).children!
          .whereType<TextSpan>();
      final links = spans
          .where((span) => span.recognizer is TapGestureRecognizer)
          .toList();
      expect(links, hasLength(1));
      expect(links.single.text, '@yoon.seul');
      (links.single.recognizer! as TapGestureRecognizer).onTap!();
      expect(visited, ['author']);
      expect(tester.takeException(), isNull);
    },
  );
}
