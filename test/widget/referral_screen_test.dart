import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/referral/data/pending_referral.dart';
import 'package:snap_fit/features/referral/data/referral_repository.dart';
import 'package:snap_fit/features/referral/domain/referral_link.dart';
import 'package:snap_fit/features/referral/domain/referral_status.dart';
import 'package:snap_fit/features/referral/presentation/providers/referral_providers.dart';
import 'package:snap_fit/features/referral/presentation/views/referral_screen.dart';
import 'package:snap_fit/features/referral/presentation/widgets/referral_widgets.dart';

const _ownCode = 'ABCDEFGH23';
const _friendCode = 'JKMNPQRS45';

ReferralStatus _status({
  bool redeemed = false,
  bool claimed = false,
  bool eligible = true,
  int balance = 500,
  int awarded = 0,
  String? reason,
  DateTime? serverTime,
  DateTime? eligibleUntil,
}) => ReferralStatus(
  ownCode: _ownCode,
  inviterPoints: 100,
  inviteePoints: 100,
  registrationWindowDays: 7,
  rewardLimit: 20,
  monthlyRewardedCount: 0,
  remaining: 20,
  invitedCount: 0,
  totalEarned: redeemed ? 100 : 0,
  balance: balance,
  canRedeem: eligible && !redeemed,
  redeemed: redeemed,
  eligibleUntil: eligibleUntil ?? DateTime.utc(2026, 11, 1, 3),
  serverTime: serverTime ?? DateTime.utc(2026, 10, 26, 3),
  claimed: claimed,
  awardedPoints: awarded,
  rewardMonth: '2026-10',
  timezone: 'Asia/Seoul',
  ineligibleReason: reason ?? (redeemed ? 'already_redeemed' : null),
);

class _Repository implements ReferralRepository {
  String? actor = 'owner-a';
  ReferralStatus status = _status();
  final _changes = StreamController<String?>.broadcast();
  Future<ReferralStatus> Function()? read;
  Future<ReferralStatus> Function(String)? register;
  final submitted = <String>[];
  int reads = 0;

  @override
  String? get currentUserId => actor;
  @override
  Stream<String?> get authChanges => _changes.stream;

  void changeAccount(String? value) {
    actor = value;
    _changes.add(value);
  }

  @override
  Future<ReferralStatus> fetchStatus() {
    reads++;
    return read?.call() ?? Future.value(status);
  }

  @override
  Future<ReferralStatus> redeem(String code) {
    submitted.add(code);
    return register?.call(code) ??
        Future.value(
          _status(redeemed: true, claimed: true, balance: 600, awarded: 100),
        );
  }

  Future<void> close() => _changes.close();
}

class _PendingStore extends PendingReferralStore {
  PendingReferral? value;
  @override
  Future<PendingReferral?> read() async => value;
  @override
  Future<void> write(PendingReferral? referral) async => value = referral;
}

Future<ProviderContainer> _mount(
  WidgetTester tester,
  _Repository repository, {
  String? initialCode,
  String? pendingCode,
  bool dark = false,
  double scale = 1,
  bool walletFails = false,
}) async {
  final container = ProviderContainer(
    overrides: [
      referralRepositoryProvider.overrideWithValue(repository),
      pendingReferralStoreProvider.overrideWithValue(_PendingStore()),
      myPointBalanceProvider.overrideWith((_) async {
        if (walletFails) throw StateError('Synthetic wallet read failure');
        return 500;
      }),
      myPointLedgerProvider.overrideWith((_) async {
        if (walletFails) throw StateError('Synthetic ledger read failure');
        return [];
      }),
    ],
  );
  if (pendingCode != null) {
    container
        .read(pendingReferralProvider.notifier)
        .receive(referralShareUri(pendingCode));
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: (dark ? SnapFitTheme.dark() : SnapFitTheme.light()).copyWith(
          splashFactory: NoSplash.splashFactory,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: ReferralScreen(initialCode: initialCode),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _unmount(
  WidgetTester tester,
  ProviderContainer container,
  _Repository repository,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  container.dispose();
  await repository.close();
  await tester.pumpAndSettle();
}

Finder get _input => find.byKey(const ValueKey('referral-code-input'));
Finder get _redeem => find.byKey(const ValueKey('referral-redeem'));

Future<void> _enter(WidgetTester tester, [String code = _friendCode]) async {
  await tester.ensureVisible(_input);
  await tester.pumpAndSettle();
  await tester.enterText(_input, code);
  await tester.pumpAndSettle();
  await tester.ensureVisible(_redeem);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'guest invite explains both rewards without a private lookup or award',
    (tester) async {
      final repository = _Repository()..actor = null;
      final container = await _mount(
        tester,
        repository,
        initialCode: _friendCode,
      );
      try {
        expect(find.text('친구가 초대장을 보냈어요'), findsOneWidget);
        expect(find.text(_friendCode), findsOneWidget);
        expect(find.text('+100P'), findsNWidgets(2));
        expect(find.byKey(const ValueKey('referral-login')), findsOneWidget);
        expect(_input, findsNothing);
        expect(repository.reads, 0);
        expect(repository.submitted, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await _unmount(tester, container, repository);
      }
    },
  );

  testWidgets(
    'opening a signed-in invite only prefills and requires an explicit tap',
    (tester) async {
      final repository = _Repository();
      final container = await _mount(
        tester,
        repository,
        initialCode: _friendCode.toLowerCase(),
      );
      try {
        expect(tester.widget<TextField>(_input).controller!.text, _friendCode);
        expect(repository.submitted, isEmpty);
        expect(find.text('보유 포인트 500P'), findsOneWidget);
        await tester.ensureVisible(_redeem);
        await tester.tap(_redeem);
        await tester.pumpAndSettle();
        expect(repository.submitted, [_friendCode]);
        expect(find.text('보유 포인트 600P'), findsOneWidget);
        expect(find.text('친구 초대 혜택을 받았어요'), findsOneWidget);
        expect(find.text('친구와 연결됐어요. 100P를 받았어요.'), findsOneWidget);
        expect(_redeem, findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await _unmount(tester, container, repository);
      }
    },
  );

  testWidgets(
    'a restored pending invite is prefilled and cleared after confirmed registration',
    (tester) async {
      final repository = _Repository();
      final container = await _mount(
        tester,
        repository,
        pendingCode: _friendCode,
      );
      try {
        expect(tester.widget<TextField>(_input).controller!.text, _friendCode);
        expect(repository.submitted, isEmpty);
        await tester.ensureVisible(_redeem);
        await tester.tap(_redeem);
        await tester.pumpAndSettle();
        expect(container.read(pendingReferralProvider), isNull);
        expect(find.text('친구 초대 혜택을 받았어요'), findsOneWidget);
      } finally {
        await _unmount(tester, container, repository);
      }
    },
  );

  testWidgets(
    'rapid taps send one registration and retain a newer pending invite',
    (tester) async {
      final pending = Completer<ReferralStatus>();
      final repository = _Repository()..register = (_) => pending.future;
      final container = await _mount(
        tester,
        repository,
        pendingCode: _friendCode,
      );
      try {
        await tester.ensureVisible(_redeem);
        await tester.tap(_redeem);
        await tester.tap(_redeem);
        await tester.pumpAndSettle();
        expect(repository.submitted, [_friendCode]);
        expect(find.text('코드 확인 중…'), findsOneWidget);
        container
            .read(pendingReferralProvider.notifier)
            .receive(referralShareUri('NPQRSTUV67'));
        pending.complete(
          _status(redeemed: true, claimed: true, balance: 600, awarded: 100),
        );
        await tester.pumpAndSettle();
        expect(container.read(pendingReferralProvider)?.code, 'NPQRSTUV67');
        expect(find.text('친구 초대 혜택을 받았어요'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await _unmount(tester, container, repository);
      }
    },
  );

  testWidgets(
    'a repeated server result confirms completion without claiming another award',
    (tester) async {
      final repository = _Repository()
        ..register = (_) async => _status(redeemed: true, balance: 600);
      final container = await _mount(tester, repository);
      try {
        await _enter(tester);
        await tester.tap(_redeem);
        await tester.pumpAndSettle();
        expect(find.text('친구 초대 혜택은 이미 받았어요.'), findsOneWidget);
        expect(find.text('친구 초대 혜택을 받았어요'), findsOneWidget);
        expect(find.textContaining('0P를 받았어요.'), findsNothing);
        expect(find.text('보유 포인트 600P'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await _unmount(tester, container, repository);
      }
    },
  );

  for (final data in [
    ('REFERRAL_INVALID_CODE', '코드를 찾지 못했어요. 친구에게 받은 코드를 다시 확인해 주세요.'),
    (
      'REFERRAL_LIMIT_REACHED',
      '이 친구의 이번 달 초대 혜택이 모두 사용됐어요. 다른 친구의 코드를 확인해 주세요.',
    ),
    ('REFERRAL_WINDOW_EXPIRED', '가입 후 코드 등록 기간이 지났어요. 내 코드로 친구를 초대해 보세요.'),
    (
      'REFERRAL_RECIPROCAL_NOT_ALLOWED',
      '이미 초대로 연결된 친구예요. 서로의 코드를 다시 등록할 수 없어요.',
    ),
  ]) {
    testWidgets(
      '${data.$1} displays a useful error without an optimistic award',
      (tester) async {
        final repository = _Repository()
          ..register = (_) async => throw StateError(data.$1);
        final container = await _mount(tester, repository);
        try {
          await _enter(tester);
          await tester.tap(_redeem);
          await tester.pumpAndSettle();
          expect(find.text(data.$2), findsOneWidget);
          expect(find.text('보유 포인트 500P'), findsOneWidget);
          expect(tester.widget<FilledButton>(_redeem).onPressed, isNotNull);
          expect(tester.takeException(), isNull);
        } finally {
          await _unmount(tester, container, repository);
        }
      },
    );
  }

  testWidgets(
    'own and incomplete codes show local guidance without a request',
    (tester) async {
      final repository = _Repository();
      final container = await _mount(tester, repository);
      try {
        await _enter(tester, _ownCode.toLowerCase());
        await tester.tap(_redeem);
        await tester.pumpAndSettle();
        expect(
          find.text('내 코드는 등록할 수 없어요. 친구에게 받은 코드를 입력해 주세요.'),
          findsOneWidget,
        );
        await _enter(tester, 'ABCD');
        await tester.tap(_redeem);
        await tester.pumpAndSettle();
        expect(
          find.text('10자리 초대 코드를 확인해 주세요. 영문과 숫자로 입력할 수 있어요.'),
          findsOneWidget,
        );
        expect(repository.submitted, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await _unmount(tester, container, repository);
      }
    },
  );

  testWidgets(
    'a lost response is retriable and never increments the local balance',
    (tester) async {
      final repository = _Repository();
      repository.register = (_) async {
        if (repository.submitted.length == 1)
          throw StateError('Synthetic response lost');
        return _status(redeemed: true, balance: 600);
      };
      final container = await _mount(tester, repository);
      try {
        await _enter(tester);
        await tester.tap(_redeem);
        await tester.pumpAndSettle();
        expect(
          find.text('등록 결과를 확인하지 못했어요. 같은 코드를 다시 눌러 확인해 주세요.'),
          findsOneWidget,
        );
        expect(find.text('보유 포인트 500P'), findsOneWidget);
        await tester.ensureVisible(_redeem);
        await tester.tap(_redeem);
        await tester.pumpAndSettle();
        expect(repository.submitted, [_friendCode, _friendCode]);
        expect(find.text('보유 포인트 600P'), findsOneWidget);
        expect(find.text('친구 초대 혜택을 받았어요'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await _unmount(tester, container, repository);
      }
    },
  );

  testWidgets('an initial lookup failure has an explicit retry', (
    tester,
  ) async {
    var fail = true;
    final repository = _Repository()
      ..read = () async {
        if (fail) throw StateError('Synthetic read failure');
        return _status();
      };
    final container = await _mount(tester, repository);
    try {
      expect(find.text('초대 기록을 불러오지 못했어요'), findsOneWidget);
      fail = false;
      await tester.tap(find.byKey(const ValueKey('referral-retry')));
      await tester.pumpAndSettle();
      expect(find.byType(ReferralShareCard), findsOneWidget);
      expect(_input, findsOneWidget);
      expect(repository.submitted, isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      await _unmount(tester, container, repository);
    }
  });

  testWidgets('logout ignores a late private registration response', (
    tester,
  ) async {
    final pending = Completer<ReferralStatus>();
    final repository = _Repository()..register = (_) => pending.future;
    final container = await _mount(tester, repository);
    try {
      await _enter(tester);
      await tester.tap(_redeem);
      await tester.pumpAndSettle();
      repository.changeAccount(null);
      await tester.pumpAndSettle();
      pending.complete(
        _status(redeemed: true, claimed: true, balance: 9999, awarded: 100),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('referral-login')), findsOneWidget);
      expect(find.text('보유 포인트 9,999P'), findsNothing);
      expect(find.text('친구와 연결됐어요. 100P를 받았어요.'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await _unmount(tester, container, repository);
    }
  });

  testWidgets('an A B A response cannot complete a new registration', (
    tester,
  ) async {
    final first = Completer<ReferralStatus>();
    final second = Completer<ReferralStatus>();
    final repository = _Repository();
    repository.register = (_) =>
        repository.submitted.length == 1 ? first.future : second.future;
    final container = await _mount(tester, repository);
    try {
      await _enter(tester);
      await tester.tap(_redeem);
      await tester.pumpAndSettle();
      repository.changeAccount('owner-b');
      await tester.pumpAndSettle();
      repository.changeAccount('owner-a');
      await tester.pumpAndSettle();
      await _enter(tester);
      await tester.tap(_redeem);
      await tester.pumpAndSettle();
      first.complete(
        _status(redeemed: true, claimed: true, balance: 9999, awarded: 100),
      );
      await tester.pumpAndSettle();
      expect(find.text('코드 확인 중…'), findsOneWidget);
      expect(find.text('보유 포인트 9,999P'), findsNothing);
      second.complete(
        _status(redeemed: true, claimed: true, balance: 600, awarded: 100),
      );
      await tester.pumpAndSettle();
      expect(find.text('보유 포인트 600P'), findsOneWidget);
      expect(repository.submitted.length, 2);
      expect(tester.takeException(), isNull);
    } finally {
      await _unmount(tester, container, repository);
    }
  });

  testWidgets('wallet refresh errors cannot replace confirmed registration', (
    tester,
  ) async {
    final repository = _Repository();
    final container = await _mount(tester, repository, walletFails: true);
    final balance = container.listen(myPointBalanceProvider, (_, _) {});
    final ledger = container.listen(myPointLedgerProvider, (_, _) {});
    try {
      await _enter(tester);
      await tester.tap(_redeem);
      await tester.pumpAndSettle();
      expect(find.text('친구 초대 혜택을 받았어요'), findsOneWidget);
      expect(find.text('보유 포인트 600P'), findsOneWidget);
      expect(find.byKey(const ValueKey('referral-redeem-error')), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      balance.close();
      ledger.close();
      await _unmount(tester, container, repository);
    }
  });

  testWidgets(
    'copy controls produce the exact code and canonical invitation URL',
    (tester) async {
      final copies = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData')
            copies.add((call.arguments as Map)['text'] as String);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final repository = _Repository();
      final container = await _mount(tester, repository);
      try {
        for (final key in ['referral-copy-code', 'referral-copy-link']) {
          final control = find.byKey(ValueKey(key));
          await tester.ensureVisible(control);
          await tester.tap(control);
          await tester.pumpAndSettle();
        }
        expect(copies, [
          _ownCode,
          'https://snapfit-c719d.web.app/friends/$_ownCode',
        ]);
        expect(repository.submitted, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await _unmount(tester, container, repository);
      }
    },
  );

  testWidgets(
    'returning to the app refreshes eligibility without registration',
    (tester) async {
      final repository = _Repository();
      final container = await _mount(tester, repository);
      try {
        final reads = repository.reads;
        repository.status = _status(eligible: false, reason: 'expired');
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pumpAndSettle();
        expect(repository.reads, greaterThan(reads));
        expect(find.text('이제 친구를 초대해 보세요'), findsOneWidget);
        expect(_input, findsNothing);
        expect(repository.submitted, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await _unmount(tester, container, repository);
      }
    },
  );

  testWidgets('an unverified account receives email verification guidance', (
    tester,
  ) async {
    final repository = _Repository()
      ..status = _status(eligible: false, reason: 'unverified');
    final container = await _mount(tester, repository);
    try {
      expect(find.text('이메일 인증이 필요해요'), findsOneWidget);
      expect(_redeem, findsNothing);
      expect(repository.submitted, isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      await _unmount(tester, container, repository);
    }
  });

  for (final width in [320.0, 390.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('invite stays usable at $width with text $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = _Repository();
        final container = await _mount(
          tester,
          repository,
          dark: scale > 1,
          scale: scale,
        );
        try {
          expect(find.byType(ReferralRewardCard), findsOneWidget);
          expect(find.byType(ReferralShareCard), findsOneWidget);
          expect(find.byType(ReferralSummaryCard), findsOneWidget);
          await _enter(tester);
          expect(_redeem.hitTestable(), findsOneWidget);
          expect(tester.getSize(_redeem).height, greaterThanOrEqualTo(54));
          await tester.ensureVisible(find.text('함께 쌓은 기록'));
          await tester.pumpAndSettle();
          expect(find.text('이번 달 초대 보상 0 / 20명'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await _unmount(tester, container, repository);
        }
      });
    }
  }
}
