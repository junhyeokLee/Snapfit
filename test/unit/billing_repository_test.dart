import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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

  test('AI album draft success requires a non-empty draft id', () async {
    final tokenStorage = MockTokenStorage();
    final repository = BillingRepository(tokenStorage: tokenStorage);

    await expectLater(
      repository.recordAiAlbumDraftSuccess(draftId: '', pointCost: 300),
      throwsArgumentError,
    );
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
