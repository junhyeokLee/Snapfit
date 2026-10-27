import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/referral/domain/referral_status.dart';

Map<String, dynamic> _wire({bool redeemed = false, bool claimed = false}) => {
  'ownCode': 'ABCD2345XY',
  'inviterPoints': 100,
  'inviteePoints': 100,
  'registrationWindowDays': 7,
  'rewardLimit': 20,
  'monthlyRewardedCount': 2,
  'remaining': 18,
  'invitedCount': 5,
  'totalEarned': redeemed ? 600 : 500,
  'balance': redeemed ? 600 : 500,
  'canRedeem': !redeemed,
  'redeemed': redeemed,
  'eligibleUntil': '2026-10-30T03:00:00Z',
  'serverTime': '2026-10-26T03:00:00Z',
  'claimed': claimed,
  'awardedPoints': claimed ? 100 : 0,
  'rewardMonth': '2026-10',
  'timezone': 'Asia/Seoul',
  'ineligibleReason': redeemed ? 'already_redeemed' : null,
};

void main() {
  test(
    'eligible state exposes server rewards and remaining monthly capacity',
    () {
      final status = ReferralStatus.fromJson(_wire());
      expect(status.ownCode, 'ABCD2345XY');
      expect(status.code, status.ownCode);
      expect(status.inviterPoints, 100);
      expect(status.inviteePoints, 100);
      expect(status.registrationWindowDays, 7);
      expect(status.rewardLimit, 20);
      expect(status.monthlyRewardedCount, 2);
      expect(status.remaining, 18);
      expect(status.invitedCount, 5);
      expect(status.totalEarned, 500);
      expect(status.canRedeem, isTrue);
      expect(status.eligibleUntil, DateTime.utc(2026, 10, 30, 3));
    },
  );

  test('a first registration and an already-paid retry stay distinct', () {
    final credited = ReferralStatus.fromJson(
      _wire(redeemed: true, claimed: true),
    );
    final repeated = ReferralStatus.fromJson(_wire(redeemed: true));
    expect(credited.redeemed, isTrue);
    expect(credited.claimed, isTrue);
    expect(credited.canRedeem, isFalse);
    expect(credited.awardedPoints, 100);
    expect(credited.balance, 600);
    expect(repeated.redeemed, isTrue);
    expect(repeated.claimed, isFalse);
    expect(repeated.awardedPoints, 0);
    expect(repeated.balance, credited.balance);
  });

  test('existing debt from purchase refunds is preserved after a referral', () {
    final wire = _wire(redeemed: true, claimed: true)..['balance'] = -150;
    expect(ReferralStatus.fromJson(wire).balance, -150);
  });

  test(
    'a registration deadline is exact and never grants local eligibility',
    () {
      final wire = _wire()
        ..['canRedeem'] = false
        ..['eligibleUntil'] = '2026-10-26T03:00:00Z'
        ..['ineligibleReason'] = 'expired';
      final expired = ReferralStatus.fromJson(wire);
      expect(expired.canRedeem, isFalse);
      expect(expired.redeemed, isFalse);
      expect(expired.eligibleUntil, expired.serverTime);
      expect(expired.ineligibleReason, 'expired');
      for (final deadline in ['2026-10-26T03:00:00Z', '2026-10-25T03:00:00Z']) {
        expect(
          () => ReferralStatus.fromJson(_wire()..['eligibleUntil'] = deadline),
          throwsFormatException,
        );
      }
    },
  );

  test('the monthly count resets with the Korean month at UTC 15:00', () {
    final wire = _wire()
      ..['serverTime'] = '2026-10-31T15:00:00Z'
      ..['eligibleUntil'] = '2026-11-02T03:00:00Z'
      ..['rewardMonth'] = '2026-11'
      ..['monthlyRewardedCount'] = 0
      ..['remaining'] = 20;
    final status = ReferralStatus.fromJson(wire);
    expect(status.rewardMonth, '2026-11');
    expect(status.remaining, 20);
    expect(status.invitedCount, 5);
    expect(status.totalEarned, 500);
    expect(
      () => ReferralStatus.fromJson(wire..['rewardMonth'] = '2026-10'),
      throwsFormatException,
    );
  });

  test('explicit timezone offsets describe the same authoritative instant', () {
    final wire = _wire()
      ..['serverTime'] = '2026-10-26T12:00:00+09:00'
      ..['eligibleUntil'] = '2026-10-30T12:00:00+09:00';
    final status = ReferralStatus.fromJson(wire);
    expect(status.serverTime, DateTime.utc(2026, 10, 26, 3));
    expect(status.eligibleUntil, DateTime.utc(2026, 10, 30, 3));
    for (final key in ['serverTime', 'eligibleUntil']) {
      expect(
        () => ReferralStatus.fromJson(_wire()..[key] = '2026-10-26T03:00:00'),
        throwsFormatException,
      );
    }
  });

  test('server balances, reward values and booleans are not coerced', () {
    for (final patch in <Map<String, dynamic>>[
      {'balance': '500'},
      {'balance': 500.5},
      {'balance': double.infinity},
      {'inviterPoints': 0},
      {'inviteePoints': -100},
      {'registrationWindowDays': 0},
      {'rewardLimit': 0},
      {'totalEarned': -1},
      {'canRedeem': 1},
      {'claimed': 'true'},
      {'redeemed': null},
      {'ownCode': 'ABCD2345X0'},
      {'ownCode': 'abcd2345xy'},
      {
        'ineligibleReason': ['internal-details'],
      },
    ]) {
      expect(
        () => ReferralStatus.fromJson(_wire()..addAll(patch)),
        throwsFormatException,
        reason: patch.toString(),
      );
    }
  });

  test('a partial or contradictory monthly limit never becomes an offer', () {
    final full = _wire()
      ..['monthlyRewardedCount'] = 20
      ..['remaining'] = 0
      ..['invitedCount'] = 25;
    expect(ReferralStatus.fromJson(full).remaining, 0);
    for (final patch in <Map<String, dynamic>>[
      {'monthlyRewardedCount': 21, 'remaining': 0, 'invitedCount': 21},
      {'monthlyRewardedCount': -1, 'remaining': 21},
      {'monthlyRewardedCount': 2, 'remaining': 19},
      {'monthlyRewardedCount': 2, 'invitedCount': 1},
      {'timezone': 'UTC'},
      {'rewardMonth': '2026-9'},
    ]) {
      expect(
        () => ReferralStatus.fromJson(_wire()..addAll(patch)),
        throwsFormatException,
        reason: patch.toString(),
      );
    }
  });

  test(
    'unregistered or duplicate responses cannot masquerade as fresh credits',
    () {
      for (final wire in [
        _wire()..['claimed'] = true,
        _wire()..['awardedPoints'] = 100,
        _wire(redeemed: true)..['awardedPoints'] = 100,
        _wire(redeemed: true, claimed: true)..['awardedPoints'] = 200,
        _wire(redeemed: true)..['canRedeem'] = true,
        _wire()..['ineligibleReason'] = 'expired',
      ]) {
        expect(() => ReferralStatus.fromJson(wire), throwsFormatException);
      }
    },
  );
}
