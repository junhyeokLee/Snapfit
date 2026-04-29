import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';

class MockDio extends Mock implements Dio {}

class MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  test('preflightStorage calls API with userId and incomingBytes', () async {
    final dio = MockDio();
    final tokenStorage = MockTokenStorage();
    final repository = BillingRepository(dio: dio, tokenStorage: tokenStorage);

    when(() => tokenStorage.getUserId()).thenAnswer((_) async => '1958142146');
    when(
      () =>
          dio.post('/api/billing/storage/preflight', data: any(named: 'data')),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/api/billing/storage/preflight'),
        data: {
          'userId': '1958142146',
          'planCode': 'FREE',
          'incomingBytes': 300,
          'usedBytes': 100,
          'projectedBytes': 400,
          'hardLimitBytes': 1024,
          'remainingBytes': 924,
          'allowed': true,
          'reason': 'OK',
          'measuredAt': '2026-03-23T10:00:00',
        },
      ),
    );

    final result = await repository.preflightStorage(incomingBytes: 300);

    expect(result.allowed, isTrue);
    expect(result.userId, '1958142146');
    expect(result.projectedBytes, 400);
    verify(
      () => dio.post(
        '/api/billing/storage/preflight',
        data: {'userId': '1958142146', 'incomingBytes': 300},
      ),
    ).called(1);
  });
}
