import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';

class MockTokenStorage extends Mock implements TokenStorage {}

void main() {
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
    expect(ledger.last.title, 'AI 초안 사용');
    expect(ledger.last.amountLabel, '-700P');
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
