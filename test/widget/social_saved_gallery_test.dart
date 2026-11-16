import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/social/data/social_repository.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_saved_works_screen.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SocialWork _work(
  String id, {
  double ratio = 1.5,
  String status = 'published',
}) => SocialWork(
  id: id,
  title: '저장한 기록 $id',
  author: const SocialProfile(
    userId: 'creator',
    displayName: '사진으로 남긴 하루',
    handle: 'daily.frames',
  ),
  createdAt: DateTime(2026, 10, 26),
  aspectRatio: ratio,
  status: status,
);

class _SavedRepository extends SocialRepository {
  _SavedRepository()
    : super(
        SupabaseClient(
          'https://fixture.invalid',
          'test-public-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final offsets = <int>[];
  final writes = <String>[];
  final saveStates = <bool>[];
  final removedWorks = <String, SocialWork>{};
  final pages = <int, SocialWorkPage>{};
  final readBarriers = <Completer<SocialWorkPage>>[];
  final writeBarriers = <Completer<void>>[];
  final failedOffsets = <int>{};
  bool removeOnSuccess = false;

  @override
  Future<SocialWorkPage> fetchSavedWorksPage({
    int offset = 0,
    int limit = 12,
  }) async {
    offsets.add(offset);
    if (readBarriers.isNotEmpty) {
      return readBarriers.removeAt(0).future;
    }
    if (failedOffsets.remove(offset))
      throw StateError('Synthetic page failure');
    return pages[offset] ??
        const SocialWorkPage(items: [], hasMore: false, nextOffset: 0);
  }

  @override
  Future<bool> setSaved(String id, bool saved) async {
    writes.add(id);
    saveStates.add(saved);
    if (writeBarriers.isNotEmpty) await writeBarriers.removeAt(0).future;
    if (removeOnSuccess && saved) {
      final work = removedWorks.remove(id);
      if (work != null) {
        final page = pages[0]!;
        pages[0] = SocialWorkPage(
          items: [work, ...page.items],
          hasMore: page.hasMore,
          nextOffset: page.nextOffset,
        );
      }
    } else if (removeOnSuccess) {
      for (final offset in pages.keys.toList()) {
        final page = pages[offset]!;
        for (final work in page.items.where((work) => work.id == id)) {
          removedWorks[id] = work;
        }
        pages[offset] = SocialWorkPage(
          items: page.items.where((work) => work.id != id).toList(),
          hasMore: page.hasMore,
          nextOffset: page.nextOffset,
        );
      }
    }
    return saved;
  }
}

SocialWorkPage _page(
  List<SocialWork> items, {
  bool more = false,
  int next = 12,
}) => SocialWorkPage(items: items, hasMore: more, nextOffset: next);

Widget _app(
  _SavedRepository repository, {
  String? Function()? actor,
  bool dark = false,
  double scale = 1,
}) => ProviderScope(
  overrides: [
    socialCurrentUserIdProvider.overrideWith(
      (_) => actor == null ? 'viewer' : actor(),
    ),
    socialAuthStateProvider.overrideWith((_) => const Stream<String?>.empty()),
    socialRepositoryProvider.overrideWithValue(repository),
  ],
  child: MaterialApp(
    theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: const SocialSavedWorksScreen(),
  ),
);

Future<void> _size(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Finder _card(String id) => find.byKey(ValueKey('social-saved-card-$id'));

Future<void> _more(WidgetTester tester) async {
  final more = find.widgetWithText(OutlinedButton, '기록·앨범 더 보기');
  await tester.scrollUntilVisible(
    more,
    500,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 30,
  );
  await tester.ensureVisible(more);
  await tester.pumpAndSettle();
  await tester.tap(more);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'phone artwork uses the full available width and original ratio',
    (tester) async {
      await _size(tester, const Size(390, 1100));
      final repository = _SavedRepository()..pages[0] = _page([_work('a')]);
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      final tile = find.byType(SocialWorkTile);
      expect(tester.getSize(tile).width, 358);
      final image = find.descendant(
        of: tile,
        matching: find.byType(AspectRatio),
      );
      expect(tester.widget<AspectRatio>(image).aspectRatio, 1.5);
      expect(tester.getSize(image).height, closeTo(358 / 1.5, .1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('phone collection keeps one title and compact privacy guidance', (
    tester,
  ) async {
    await _size(tester, const Size(390, 844));
    final repository = _SavedRepository()..pages[0] = _page([_work('a')]);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    expect(find.text('저장한 기록·앨범'), findsOneWidget);
    expect(find.text('나에게만 보여요 · 공개가 종료된 기록과 앨범은 표시하지 않아요.'), findsOneWidget);
    expect(tester.getTopLeft(_card('a')).dy, lessThan(180));
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide gallery has two large columns and builds rows lazily', (
    tester,
  ) async {
    await _size(tester, const Size(1280, 900));
    final repository = _SavedRepository()
      ..pages[0] = _page(List.generate(30, (i) => _work('$i')));
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_card('0')).dy, tester.getTopLeft(_card('1')).dy);
    expect(tester.getSize(_card('0')).width, greaterThan(500));
    expect(
      tester.getTopLeft(_card('1')).dx,
      greaterThan(tester.getTopLeft(_card('0')).dx),
    );
    expect(find.byType(SocialWorkTile).evaluate().length, lessThan(12));
    expect(_card('29'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'narrow dark gallery supports large text without clipping controls',
    (tester) async {
      await _size(tester, const Size(320, 900));
      final repository = _SavedRepository()..pages[0] = _page([_work('a')]);
      await tester.pumpWidget(_app(repository, dark: true, scale: 2.2));
      await tester.pumpAndSettle();
      final remove = find.byKey(const ValueKey('social-saved-remove-a'));
      await tester.ensureVisible(remove);
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(remove).onPressed, isNotNull);
      expect(tester.getSize(_card('a')).width, 288);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'gallery respects server offsets and filters duplicates and private works',
    (tester) async {
      await _size(tester, const Size(1280, 1400));
      final repository = _SavedRepository()
        ..pages[0] = _page(
          [_work('a'), _work('private', status: 'withdrawn')],
          more: true,
          next: 37,
        )
        ..pages[37] = _page([_work('a'), _work('b')], next: 73);
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      final more = find.widgetWithText(OutlinedButton, '기록·앨범 더 보기');
      final request = tester.widget<OutlinedButton>(more).onPressed!;
      request();
      request();
      await tester.pumpAndSettle();
      expect(repository.offsets, [0, 37]);
      expect(_card('a'), findsOneWidget);
      expect(_card('b'), findsOneWidget);
      expect(_card('private'), findsNothing);
      expect(more, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('later page can retry without losing already saved photos', (
    tester,
  ) async {
    await _size(tester, const Size(1280, 1400));
    final repository = _SavedRepository()
      ..pages[0] = _page([_work('a')], more: true, next: 40)
      ..pages[40] = _page([_work('b')])
      ..failedOffsets.add(40);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await _more(tester);
    expect(_card('a'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(_card('a'), findsOneWidget);
    expect(_card('b'), findsOneWidget);
    expect(repository.offsets, [0, 40, 40]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'new account never sees cached works while its collection loads',
    (tester) async {
      await _size(tester, const Size(390, 1100));
      String? actor = 'first';
      final repository = _SavedRepository()..pages[0] = _page([_work('first')]);
      await tester.pumpWidget(_app(repository, actor: () => actor));
      await tester.pumpAndSettle();
      expect(_card('first'), findsOneWidget);
      final next = Completer<SocialWorkPage>();
      repository.readBarriers.add(next);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SocialSavedWorksScreen)),
      );
      actor = 'second';
      container.invalidate(socialCurrentUserIdProvider);
      // Riverpod invalidation is lazy. Commit the new observed identity before
      // asserting the first frame of that account's pending collection.
      expect(container.read(socialCurrentUserIdProvider), 'second');
      await tester.pump();
      expect(_card('first'), findsNothing);
      next.complete(_page([_work('second')]));
      await tester.pumpAndSettle();
      expect(_card('first'), findsNothing);
      expect(_card('second'), findsOneWidget);
      actor = null;
      container.invalidate(socialCurrentUserIdProvider);
      expect(container.read(socialCurrentUserIdProvider), isNull);
      await tester.pumpAndSettle();
      expect(_card('second'), findsNothing);
      expect(find.text('나만 보는 기록·앨범 보관함'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late collection response stays isolated from the next account', (
    tester,
  ) async {
    String? actor = 'first';
    final first = Completer<SocialWorkPage>();
    final second = Completer<SocialWorkPage>();
    final repository = _SavedRepository()..readBarriers.addAll([first, second]);
    await tester.pumpWidget(_app(repository, actor: () => actor));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SocialSavedWorksScreen)),
    );
    actor = 'second';
    container.invalidate(socialCurrentUserIdProvider);
    await tester.pump();
    first.complete(_page([_work('private-first')]));
    await tester.pump();
    expect(_card('private-first'), findsNothing);
    second.complete(_page([_work('second')]));
    await tester.pumpAndSettle();
    expect(_card('private-first'), findsNothing);
    expect(_card('second'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'save removal runs once and refreshes the confirmed empty collection',
    (tester) async {
      await _size(tester, const Size(390, 1100));
      final pending = Completer<void>();
      final repository = _SavedRepository()
        ..pages[0] = _page([_work('a')])
        ..removeOnSuccess = true
        ..writeBarriers.add(pending);
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      final remove = find.byKey(const ValueKey('social-saved-remove-a'));
      final request = tester.widget<TextButton>(remove).onPressed!;
      request();
      request();
      await tester.pumpAndSettle();
      expect(repository.writes, ['a']);
      expect(tester.widget<TextButton>(remove).onPressed, isNull);
      pending.complete();
      await tester.pumpAndSettle();
      expect(_card('a'), findsNothing);
      expect(find.text('아직 저장한 기록이나 앨범이 없어요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'save removal can be undone after the card leaves the collection',
    (tester) async {
      await _size(tester, const Size(390, 1100));
      final repository = _SavedRepository()
        ..pages[0] = _page([_work('a')])
        ..removeOnSuccess = true;
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('social-saved-remove-a')));
      await tester.pumpAndSettle();
      expect(_card('a'), findsNothing);
      expect(find.text('저장을 해제했어요'), findsOneWidget);
      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(_card('a'), findsOneWidget);
      expect(repository.saveStates, [false, true]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed save restoration keeps the collection empty and reports it',
    (tester) async {
      final repository = _SavedRepository()
        ..pages[0] = _page([_work('a')])
        ..removeOnSuccess = true;
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      final remove = find.byKey(const ValueKey('social-saved-remove-a'));
      await tester.ensureVisible(remove);
      await tester.pumpAndSettle();
      expect(remove.hitTestable(), findsOneWidget);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      final pending = Completer<void>();
      repository.writeBarriers.add(pending);
      await tester.tap(find.text('되돌리기'));
      await tester.pump();
      pending.completeError(StateError('Synthetic restoration failure'));
      await tester.pumpAndSettle();
      expect(_card('a'), findsNothing);
      expect(find.text('처리하지 못했어요. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late undo response does not refresh the next account collection',
    (tester) async {
      String? actor = 'first';
      final repository = _SavedRepository()
        ..pages[0] = _page([_work('a')])
        ..removeOnSuccess = true;
      await tester.pumpWidget(_app(repository, actor: () => actor));
      await tester.pumpAndSettle();
      final remove = find.byKey(const ValueKey('social-saved-remove-a'));
      await tester.ensureVisible(remove);
      await tester.pumpAndSettle();
      expect(remove.hitTestable(), findsOneWidget);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      final pending = Completer<void>();
      repository.writeBarriers.add(pending);
      await tester.tap(find.text('되돌리기'));
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SocialSavedWorksScreen)),
      );
      actor = 'second';
      repository.pages[0] = _page([_work('second')]);
      container.invalidate(socialCurrentUserIdProvider);
      await tester.pumpAndSettle();
      final reads = repository.offsets.length;
      pending.complete();
      await tester.pumpAndSettle();
      expect(repository.offsets.length, reads);
      expect(_card('second'), findsOneWidget);
      expect(_card('a'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'old undo never restores a work for another account or after dispose',
    (tester) async {
      String? actor = 'first';
      final repository = _SavedRepository()
        ..pages[0] = _page([_work('a')])
        ..removeOnSuccess = true;
      await tester.pumpWidget(_app(repository, actor: () => actor));
      await tester.pumpAndSettle();
      final remove = find.byKey(const ValueKey('social-saved-remove-a'));
      await tester.ensureVisible(remove);
      await tester.pumpAndSettle();
      expect(remove.hitTestable(), findsOneWidget);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      final undo = tester
          .widget<SnackBarAction>(find.byType(SnackBarAction))
          .onPressed;
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SocialSavedWorksScreen)),
      );
      actor = 'second';
      container.invalidate(socialCurrentUserIdProvider);
      await tester.pumpAndSettle();
      expect(find.text('저장을 해제했어요'), findsNothing);
      undo();
      await tester.pumpAndSettle();
      expect(repository.saveStates, [false]);
      await tester.pumpWidget(const SizedBox.shrink());
      undo();
      await tester.pumpAndSettle();
      expect(repository.saveStates, [false]);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('rapid removals do not leave a queued undo for the previous account', (
    tester,
  ) async {
    await _size(tester, const Size(1280, 1400));
    String? actor = 'first';
    final repository = _SavedRepository()
      ..pages[0] = _page([_work('a'), _work('b')])
      ..removeOnSuccess = true;
    await tester.pumpWidget(_app(repository, actor: () => actor));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SocialSavedWorksScreen)),
    );
    await tester.tap(find.byKey(const ValueKey('social-saved-remove-a')));
    await tester.pumpAndSettle();
    expect(find.text('저장을 해제했어요'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('social-saved-remove-b')));
    // Switch accounts before the first notice's reverse animation could finish.
    await tester.pump();
    actor = 'second';
    repository.pages[0] = _page([_work('second')]);
    container.invalidate(socialCurrentUserIdProvider);
    await tester.pumpAndSettle();
    expect(find.text('저장을 해제했어요'), findsNothing);
    expect(find.text('되돌리기'), findsNothing);
    expect(_card('second'), findsOneWidget);
    expect(repository.saveStates, [false, false]);
    expect(tester.takeException(), isNull);
  });

}
