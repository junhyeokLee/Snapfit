import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';

class MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  for (final reason in [
    'DIGITAL_ITEM_PURCHASE',
    'AI_ALBUM_DRAFT_CHARGE',
    'AI_ALBUM_DRAFT_FREE',
  ]) {
    test('ledger shows stored title for $reason', () {
      final entry = PointLedgerEntry.fromJson({
        'id': 12,
        'amount_delta': -450,
        'reason': reason,
        'metadata': {'title': '  여행의 결  '},
      });
      expect(entry.subtitle, '여행의 결');
    });
  }
  for (final metadata in [
    null,
    'invalid',
    [],
    {'title': 42},
    {'title': '  '},
  ]) {
    test('ledger keeps a useful fallback for metadata $metadata', () {
      final entry = PointLedgerEntry.fromJson({
        'id': 12,
        'amount_delta': -450,
        'reason': 'DIGITAL_ITEM_PURCHASE',
        'metadata': metadata,
      });
      expect(entry.subtitle, '구매한 상품은 계속 사용할 수 있어요');
    });
  }
  test('unrelated ledger metadata is not shown as a purchase title', () {
    final entry = PointLedgerEntry.fromJson({
      'id': 12,
      'amount_delta': 10,
      'reason': 'DAILY_ATTENDANCE',
      'metadata': {'title': '내부 처리 정보'},
    });
    expect(entry.subtitle, '오늘의 출석으로 받은 무료 포인트');
  });
  test(
    'earned attendance and signup points have distinct ledger descriptions',
    () {
      const entry = PointLedgerEntry(
        id: 1,
        createdAt: null,
        amountDelta: 10,
        reason: 'DAILY_ATTENDANCE',
      );
      expect(entry.title, '출석체크 적립');
      expect(entry.subtitle, '오늘의 출석으로 받은 무료 포인트');
      expect(entry.amountLabel, '+10P');
      const signup = PointLedgerEntry(
        id: 2,
        createdAt: null,
        amountDelta: 500,
        reason: 'SIGNUP_BONUS',
      );
      expect(signup.title, '가입 축하 포인트');
    },
  );

  test(
    'server protection errors are not incorrectly reported as insufficient points',
    () async {
      final repository = BillingRepository(
        tokenStorage: MockTokenStorage(),
        recordAiAlbumDraftSuccessRpc:
            ({required draftId, required pointCost}) async {
              throw const PostgrestException(
                message: 'ai_draft_not_reviewable',
                code: 'P0001',
              );
            },
      );
      await expectLater(
        repository.recordAiAlbumDraftSuccess(draftId: 'unverified'),
        throwsA(
          isA<AiAlbumDraftPointUsageException>().having(
            (e) => e.failure,
            'failure',
            AiAlbumDraftPointUsageFailure.unavailable,
          ),
        ),
      );
    },
  );
  test('records AI album draft success through injected recorder', () async {
    final tokenStorage = MockTokenStorage();
    final repository = BillingRepository(
      tokenStorage: tokenStorage,
      recordAiAlbumDraftSuccessRpc:
          ({required draftId, required pointCost}) async {
            expect(draftId, 'draft-1');
            expect(pointCost, 300);
            return {
              'used_free_credit': false,
              'charged_points': 300,
              'remaining_balance': 900,
            };
          },
    );

    final result = await repository.recordAiAlbumDraftSuccess(
      draftId: 'draft-1',
      pointCost: 300,
    );

    expect(result.usedFreeCredit, isFalse);
    expect(result.chargedPoints, 300);
    expect(result.remainingBalance, 900);
  });

  test(
    'maps Supabase insufficient point errors into typed exception',
    () async {
      final tokenStorage = MockTokenStorage();
      final repository = BillingRepository(
        tokenStorage: tokenStorage,
        recordAiAlbumDraftSuccessRpc:
            ({required draftId, required pointCost}) async {
              throw const PostgrestException(
                message: 'insufficient points for AI album draft',
                code: 'P0001',
              );
            },
      );

      await expectLater(
        repository.recordAiAlbumDraftSuccess(
          draftId: 'draft-2',
          pointCost: 300,
        ),
        throwsA(
          isA<AiAlbumDraftPointUsageException>().having(
            (error) => error.failure,
            'failure',
            AiAlbumDraftPointUsageFailure.insufficientPoints,
          ),
        ),
      );
    },
  );

  test(
    'maps AI album draft insufficient points into typed exception',
    () async {
      final tokenStorage = MockTokenStorage();
      final repository = BillingRepository(
        tokenStorage: tokenStorage,
        recordAiAlbumDraftSuccessRpc:
            ({required draftId, required pointCost}) async {
              throw const AiAlbumDraftPointUsageException(
                AiAlbumDraftPointUsageFailure.insufficientPoints,
              );
            },
      );

      await expectLater(
        repository.recordAiAlbumDraftSuccess(
          draftId: 'draft-2',
          pointCost: 300,
        ),
        throwsA(
          isA<AiAlbumDraftPointUsageException>().having(
            (error) => error.failure,
            'failure',
            AiAlbumDraftPointUsageFailure.insufficientPoints,
          ),
        ),
      );
    },
  );

  test('AI album draft success requires a non-empty draft id', () async {
    final tokenStorage = MockTokenStorage();
    final repository = BillingRepository(tokenStorage: tokenStorage);

    await expectLater(
      repository.recordAiAlbumDraftSuccess(draftId: '', pointCost: 300),
      throwsArgumentError,
    );
  });

  test('reads point wallet balance through injected query', () async {
    final tokenStorage = MockTokenStorage();
    when(() => tokenStorage.getUserId()).thenAnswer((_) async => 'user-1');
    final repository = BillingRepository(
      tokenStorage: tokenStorage,
      pointBalanceQuery: () async => {'balance': 2500},
    );

    final balance = await repository.getMyPointBalance();

    expect(balance, 2500);
  });

  test('parses duplicate point purchase verification result', () {
    final result = StorePointPurchaseResult.fromJson({
      'productId': 'snapfit_points_2500',
      'grantedPoints': 0,
      'remainingBalance': 2500,
      'alreadyGranted': true,
    });

    expect(result.productId, 'snapfit_points_2500');
    expect(result.grantedPoints, 0);
    expect(result.remainingBalance, 2500);
    expect(result.alreadyGranted, isTrue);
  });

  test('reads recent point ledger through injected query', () async {
    final tokenStorage = MockTokenStorage();
    when(() => tokenStorage.getUserId()).thenAnswer((_) async => 'user-1');
    final repository = BillingRepository(
      tokenStorage: tokenStorage,
      pointLedgerQuery: ({required userId, required limit}) async {
        expect(userId, 'user-1');
        expect(limit, 3);
        return [
          {
            'id': 11,
            'created_at': '2026-09-06T04:00:00Z',
            'amount_delta': 2500,
            'reason': 'POINT_PURCHASE',
          },
          {
            'id': 10,
            'created_at': '2026-09-06T03:00:00Z',
            'amount_delta': -700,
            'reason': 'AI_ALBUM_DRAFT_CHARGE',
          },
        ];
      },
    );

    final ledger = await repository.getMyPointLedger(limit: 3);

    expect(ledger, hasLength(2));
    expect(ledger.first.title, '포인트 충전');
    expect(ledger.first.amountLabel, '+2500P');
    expect(ledger.last.title, 'AI 템플릿 사용');
    expect(ledger.last.amountLabel, '-700P');
  });

  test('referral rewards have distinct inviter and invitee ledger labels', () {
    final inviter = PointLedgerEntry.fromJson({
      'id': 31,
      'amount_delta': 100,
      'reason': 'REFERRAL_INVITER',
    });
    final invitee = PointLedgerEntry.fromJson({
      'id': 32,
      'amount_delta': 100,
      'reason': 'REFERRAL_INVITEE',
    });
    expect(inviter.title, '친구 초대 적립');
    expect(invitee.title, '초대 코드 등록 적립');
    expect(inviter.amountLabel, '+100P');
    expect(invitee.amountLabel, '+100P');
    expect(inviter.subtitle, contains('친구가 코드를 등록'));
    expect(invitee.subtitle, contains('친구의 초대 코드를 등록'));
  });

  test('preflightStorage requires a Supabase client', () async {
    final tokenStorage = MockTokenStorage();
    final repository = BillingRepository(tokenStorage: tokenStorage);

    when(() => tokenStorage.getUserId()).thenAnswer((_) async => '1958142146');
    await expectLater(
      repository.preflightStorage(incomingBytes: 300),
      throwsA(isA<Exception>()),
    );
  });
}
