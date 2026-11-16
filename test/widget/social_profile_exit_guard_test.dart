import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/social/data/social_repository.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_profile_edit_screen.dart';

const profileExitOwner = 'profile-exit-owner';
const profileExitInitial = SocialProfile(
  userId: profileExitOwner,
  displayName: '나의 공개 기록',
  handle: 'my.public',
  bio: '공개한 소개만 표시합니다.',
);

class _Actor extends Notifier<String?> {
  @override
  String? build() => profileExitOwner;
  void update(String? value) => state = value;
}

final _actor = NotifierProvider<_Actor, String?>(_Actor.new);

class _GuestAuth extends AuthViewModel {
  @override
  FutureOr<UserInfo?> build() => null;
}

class _Repository extends Mock implements SocialRepository {}

/// 캡처와 회귀 모두 실제 프로필 입력·내비게이션을 사용한다.
class ProfileExitFixture {
  ProfileExitFixture() {
    when(
      () => repository.upsertOwnProfile(
        displayName: any(named: 'displayName'),
        handle: any(named: 'handle'),
        bio: any(named: 'bio'),
      ),
    ).thenAnswer((_) async {
      saves++;
      return pendingSave == null
          ? profileExitInitial
          : await pendingSave!.future;
    });
  }

  final repository = _Repository();
  final navigator = GlobalKey<NavigatorState>();
  late ProviderContainer container;
  Completer<SocialProfile>? pendingSave;
  int saves = 0;

  void owner(String? value) => container.read(_actor.notifier).update(value);

  Future<void> open(WidgetTester tester) async {
    unawaited(
      navigator.currentState!.push<bool>(
        MaterialPageRoute(builder: (_) => const SocialProfileEditScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> mountProfileExit(
  WidgetTester tester,
  ProfileExitFixture fixture, {
  Size size = const Size(390, 844),
  double scale = 1,
  GlobalKey? capture,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  fixture.container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      authViewModelProvider.overrideWith(_GuestAuth.new),
      socialCurrentUserIdProvider.overrideWith((ref) => ref.watch(_actor)),
      socialRepositoryProvider.overrideWithValue(fixture.repository),
      ownSocialProfileProvider.overrideWith((ref) async {
        final actor = ref.watch(_actor);
        if (actor == null) return null;
        return actor == profileExitOwner
            ? profileExitInitial
            : SocialProfile(
                userId: actor,
                displayName: '다른 계정',
                handle: 'other.public',
                bio: '다른 계정의 공개 소개',
              );
      }),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    fixture.container.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: fixture.container,
      child: MaterialApp(
        navigatorKey: fixture.navigator,
        theme: SnapFitTheme.light().copyWith(
          splashFactory: NoSplash.splashFactory,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: capture == null
              ? child!
              : RepaintBoundary(key: capture, child: child!),
        ),
        home: const Scaffold(body: Center(child: Text('프로필 검토 시작'))),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await fixture.open(tester);
}

Finder _field(String name) => find.byKey(ValueKey('social-profile-$name'));

Future<void> _edit(WidgetTester tester, String name, String value) async {
  await tester.ensureVisible(_field(name));
  await tester.pumpAndSettle();
  await tester.enterText(_field(name), value);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

VoidCallback _back(WidgetTester tester) => tester
    .widget<IconButton>(
      find
          .ancestor(
            of: find.byTooltip('뒤로가기'),
            matching: find.byType(IconButton),
          )
          .first,
    )
    .onPressed!;

Future<void> _choose(WidgetTester tester, String label) async {
  final action = find.widgetWithText(TextButton, label);
  await tester.ensureVisible(action);
  await tester.tap(action);
  await tester.pumpAndSettle();
}

void main() {
  for (final entry in [
    ('name', '저장 전 바꾼 이름'),
    ('handle', 'changed.public'),
    ('bio', '저장 전 작성하던 공개 소개입니다.'),
  ]) {
    testWidgets(
      'recovery regression: profile ${entry.$1} back preserves unsaved text',
      (tester) async {
        final fixture = ProfileExitFixture();
        await mountProfileExit(tester, fixture);
        await _edit(tester, entry.$1, entry.$2);
        _back(tester)();
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await _choose(tester, '계속 수정');
        expect(find.byType(SocialProfileEditScreen), findsOneWidget);
        expect(
          tester.widget<TextFormField>(_field(entry.$1)).controller!.text,
          entry.$2,
        );
        expect(fixture.saves, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'recovery regression: profile system back can discard explicitly',
    (tester) async {
      final fixture = ProfileExitFixture();
      await mountProfileExit(tester, fixture);
      await _edit(tester, 'bio', '뒤로 가기 전에 확인할 소개');
      await fixture.navigator.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await _choose(tester, '나가기');
      expect(find.byType(SocialProfileEditScreen), findsNothing);
      expect(find.text('프로필 검토 시작'), findsOneWidget);
      await fixture.open(tester);
      expect(
        tester.widget<TextFormField>(_field('bio')).controller!.text,
        profileExitInitial.bio,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final revert in [false, true]) {
    testWidgets(
      'recovery regression: profile unchanged or reverted exits immediately revert=$revert',
      (tester) async {
        final fixture = ProfileExitFixture();
        await mountProfileExit(tester, fixture);
        if (revert) {
          for (final field in [
            ('name', profileExitInitial.displayName),
            ('handle', profileExitInitial.handle),
            ('bio', profileExitInitial.bio),
          ]) {
            await _edit(tester, field.$1, '임시로 바꾼 값');
            await _edit(tester, field.$1, field.$2);
          }
        }
        _back(tester)();
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(SocialProfileEditScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'recovery regression: profile repeated back opens a single confirmation',
    (tester) async {
      final fixture = ProfileExitFixture();
      await mountProfileExit(tester, fixture);
      await _edit(tester, 'bio', '변경한 소개');
      final back = _back(tester);
      back();
      back();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await _choose(tester, '계속 수정');
      expect(find.byType(SocialProfileEditScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'recovery regression: profile save is busy then closes without discard prompt',
    (tester) async {
      final fixture = ProfileExitFixture()
        ..pendingSave = Completer<SocialProfile>();
      await mountProfileExit(tester, fixture);
      await _edit(tester, 'bio', '계정에 저장할 소개');
      final save = find.widgetWithText(FilledButton, '프로필 저장');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump(const Duration(milliseconds: 100));
      _back(tester)();
      await fixture.navigator.currentState!.maybePop();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SocialProfileEditScreen), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      fixture.pendingSave!.complete(profileExitInitial);
      await tester.pumpAndSettle();
      expect(find.byType(SocialProfileEditScreen), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(fixture.saves, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final actor in <String?>[null, 'profile-other']) {
    testWidgets(
      'recovery regression: profile identity change dismisses stale exit confirmation actor=$actor',
      (tester) async {
        final fixture = ProfileExitFixture();
        await mountProfileExit(tester, fixture);
        await _edit(tester, 'bio', '이전 계정이 작성한 비공개 초안');
        _back(tester)();
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        final discard = tester
            .widget<TextButton>(find.widgetWithText(TextButton, '나가기'))
            .onPressed!;
        fixture.owner(actor);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('이전 계정이 작성한 비공개 초안'), findsNothing);
        discard();
        await tester.pumpAndSettle();
        expect(find.byType(SocialProfileEditScreen), findsOneWidget);
        await fixture.navigator.currentState!.maybePop();
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(SocialProfileEditScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'recovery regression: profile draft confirmation fits narrow large text',
    (tester) async {
      final fixture = ProfileExitFixture();
      await mountProfileExit(
        tester,
        fixture,
        size: const Size(320, 568),
        scale: 1.8,
      );
      await _edit(tester, 'bio', '좁은 화면에서도 보존할 작성 중인 소개');
      _back(tester)();
      await tester.pumpAndSettle();
      for (final label in ['계속 수정', '나가기']) {
        final action = find.widgetWithText(TextButton, label);
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        expect(action.hitTestable(), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
