import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/moments/data/moments_repository.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moment_document_font_entry.dart';

class _Repository extends Mock implements MomentsRepository {}

void main() {
  late _Repository repository;
  late String? actor;
  late StreamController<String?> auth;
  late Future<void> Function() prepare;
  late int mounts;

  setUp(() {
    actor = 'owner-a';
    auth = StreamController<String?>.broadcast(sync: true);
    repository = _Repository();
    when(() => repository.currentUserId).thenAnswer((_) => actor);
    when(() => repository.authChanges).thenAnswer((_) => auth.stream);
    mounts = 0;
  });
  tearDown(() async => auth.close());

  Widget screen() => ProviderScope(
    overrides: [
      momentsRepositoryProvider.overrideWithValue(repository),
      monthlyMomentFontPreparationProvider.overrideWithValue(() => prepare()),
    ],
    child: MaterialApp(
      home: MomentDocumentFontEntry(
        builder: (_) {
          mounts++;
          return const Scaffold(body: Text('Original monthly album is ready'));
        },
      ),
    ),
  );

  testWidgets(
    'monthly document state cannot mount or measure until fonts complete',
    (tester) async {
      final fonts = Completer<void>();
      prepare = () => fonts.future;
      await tester.pumpWidget(screen());
      await tester.pump();
      expect(mounts, 0);
      expect(find.text('앨범의 글꼴을 준비하고 있어요.'), findsOneWidget);
      fonts.complete();
      await tester.pumpAndSettle();
      expect(mounts, greaterThan(0));
      expect(find.text('Original monthly album is ready'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a failed font download offers retry without mounting fallback document state',
    (tester) async {
      var calls = 0;
      final retry = Completer<void>();
      prepare = () => ++calls == 1
          ? Future<void>.error(StateError('font network failed'))
          : retry.future;
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(mounts, 0);
      await tester.tap(find.text('앨범 글꼴 다시 불러오기'));
      await tester.pump();
      expect(calls, 2);
      expect(mounts, 0);
      retry.complete();
      await tester.pumpAndSettle();
      expect(mounts, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A to B to A during font preparation never mounts the previous session preview',
    (tester) async {
      final fonts = Completer<void>();
      prepare = () => fonts.future;
      await tester.pumpWidget(screen());
      await tester.pump();
      actor = 'owner-b';
      auth.add(actor);
      actor = 'owner-a';
      auth.add(actor);
      fonts.complete();
      await tester.pumpAndSettle();
      expect(mounts, 0);
      expect(find.textContaining('계정이 변경되었어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a disposed preview cannot mount after its fonts finish', (
    tester,
  ) async {
    final fonts = Completer<void>();
    prepare = () => fonts.future;
    await tester.pumpWidget(screen());
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    fonts.complete();
    await tester.pumpAndSettle();
    expect(mounts, 0);
    expect(tester.takeException(), isNull);
  });
}
