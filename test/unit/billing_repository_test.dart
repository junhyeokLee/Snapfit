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
