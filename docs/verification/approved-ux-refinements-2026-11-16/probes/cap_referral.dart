import 'audit_support.dart';
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
          child: auditFrame(child!),
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
  setUpAll(auditFonts);
  for(final eligible in [true,false]) {
    testWidgets('capture referral eligible=$eligible',(tester) async {
      auditViewport(tester);
      final repository=_Repository()..status=_status(eligible:eligible,serverTime:DateTime.utc(2026,11,16),eligibleUntil:DateTime.utc(2026,11,eligible?23:15));
      final container=await _mount(tester,repository);
      try {
        await auditCapture(tester,'referral-${eligible?'eligible':'expired'}');
        if(eligible){await tester.ensureVisible(_input);await tester.pumpAndSettle();await auditCapture(tester,'referral-code-entry');}
        expect(repository.submitted,isEmpty);
      }finally{await _unmount(tester,container,repository);}
    });
  }
  testWidgets('capture referral incoming link',(tester) async {
    auditViewport(tester);
    final repository=_Repository()..status=_status(serverTime:DateTime.utc(2026,11,16),eligibleUntil:DateTime.utc(2026,11,23));
    final container=await _mount(tester,repository,initialCode:_friendCode);
    try {
      await auditCapture(tester,'referral-incoming-link');
      expect(tester.widget<TextField>(_input).controller!.text,_friendCode);
      await tester.ensureVisible(_input);await tester.pumpAndSettle();
      await auditCapture(tester,'referral-incoming-entry');
      expect(repository.submitted,isEmpty);
    }finally{await _unmount(tester,container,repository);}
  });

}
