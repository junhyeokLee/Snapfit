import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Tokens extends Mock implements TokenStorage {}

class _Auth extends Mock implements GoTrueClient {}

// Keep the installed Supabase/PostgREST request builders real; only HTTP is fake.
class _Client extends SupabaseClient {
  _Client(this.fixtureAuth, http.Client transport)
    : super(
        'https://fixture.supabase.co',
        'fixture-public-key',
        httpClient: transport,
        accessToken: () async => 'fixture-session',
      );

  final GoTrueClient fixtureAuth;

  @override
  GoTrueClient get auth => fixtureAuth;
}

const _owner = '11111111-1111-4111-8111-111111111111';
const _other = '22222222-2222-4222-8222-222222222222';
const _createdAt = '2026-11-11T12:34:56.123456Z';

Map<String, dynamic> _row(int id, {int amount = 10}) => {
  'id': id,
  'created_at': _createdAt,
  'amount_delta': amount,
  'reason': amount < 0 ? 'AI_ALBUM_DRAFT_CHARGE' : 'DAILY_ATTENDANCE',
  'related_entity_type': null,
  'related_entity_id': null,
};

_Tokens _tokens([String? owner = _owner]) {
  final tokens = _Tokens();
  when(() => tokens.getUserId()).thenAnswer((_) async => owner);
  return tokens;
}

void main() {
  test(
    'history requests twenty rows plus one and returns its displayed edge',
    () async {
      var reads = 0;
      final repository = BillingRepository(
        tokenStorage: _tokens(),
        pointLedgerPageQuery:
            ({
              required userId,
              required filter,
              required limit,
              required before,
            }) async {
              reads++;
              expect(userId, _owner);
              expect(filter, PointLedgerFilter.all);
              expect(limit, 21);
              expect(before, isNull);
              return List.generate(21, (index) => _row(100 - index));
            },
      );

      final page = await repository.getMyPointLedgerPage();

      expect(reads, 1);
      expect(
        page.entries.map((entry) => entry.id),
        List.generate(20, (i) => 100 - i),
      );
      expect(page.nextCursor, isNotNull);
      expect(page.nextCursor!.id, 81);
      expect(page.nextCursor!.createdAtUtc, DateTime.parse(_createdAt));
      expect(page.nextCursor!.createdAtUtc.isUtc, isTrue);
    },
  );

  for (final count in [0, 20]) {
    test('a terminal page containing $count rows has no next cursor', () async {
      final repository = BillingRepository(
        tokenStorage: _tokens(),
        pointLedgerPageQuery:
            ({
              required userId,
              required filter,
              required limit,
              required before,
            }) async => List.generate(count, (index) => _row(100 - index)),
      );

      final page = await repository.getMyPointLedgerPage();

      expect(page.entries, hasLength(count));
      expect(page.nextCursor, isNull);
    });
  }

  for (final limits in [(requested: 0, size: 1), (requested: 999, size: 50)]) {
    test(
      'history clamps ${limits.requested} to ${limits.size} before lookahead',
      () async {
        final repository = BillingRepository(
          tokenStorage: _tokens(),
          pointLedgerPageQuery:
              ({
                required userId,
                required filter,
                required limit,
                required before,
              }) async {
                expect(limit, limits.size + 1);
                return List.generate(limit, (index) => _row(100 - index));
              },
        );

        final page = await repository.getMyPointLedgerPage(
          limit: limits.requested,
        );

        expect(page.entries, hasLength(limits.size));
        expect(page.nextCursor!.id, 101 - limits.size);
      },
    );
  }

  test(
    'history passes its filter and exact cursor through the injected seam',
    () async {
      final before = PointLedgerCursor(
        createdAtUtc: DateTime.parse(_createdAt),
        id: 81,
      );
      final repository = BillingRepository(
        tokenStorage: _tokens(),
        pointLedgerPageQuery:
            ({
              required userId,
              required filter,
              required limit,
              required before,
            }) async {
              expect(userId, _owner);
              expect(filter, PointLedgerFilter.spent);
              expect(limit, 4);
              expect(before!.id, 81);
              expect(before.createdAtUtc, DateTime.parse(_createdAt));
              return [_row(80, amount: -700)];
            },
      );

      final page = await repository.getMyPointLedgerPage(
        filter: PointLedgerFilter.spent,
        limit: 3,
        before: before,
      );

      expect(page.entries.single.id, 80);
      expect(page.entries.single.amountDelta, -700);
      expect(page.nextCursor, isNull);
    },
  );

  test(
    'the recent summary keeps its existing five-row query contract',
    () async {
      var historyReads = 0;
      final repository = BillingRepository(
        tokenStorage: _tokens(),
        pointLedgerQuery: ({required userId, required limit}) async {
          expect(userId, _owner);
          expect(limit, 5);
          return List.generate(limit, (index) => _row(100 - index));
        },
        pointLedgerPageQuery:
            ({
              required userId,
              required filter,
              required limit,
              required before,
            }) async {
              historyReads++;
              return [];
            },
      );

      final recent = await repository.getMyPointLedger();

      expect(recent, hasLength(5));
      expect(historyReads, 0);
    },
  );

  for (final id in [0, -1]) {
    test('an invalid cursor id $id fails before the query', () async {
      var reads = 0;
      final repository = BillingRepository(
        tokenStorage: _tokens(),
        pointLedgerPageQuery:
            ({
              required userId,
              required filter,
              required limit,
              required before,
            }) async {
              reads++;
              return [];
            },
      );

      await expectLater(
        Future.sync(
          () => repository.getMyPointLedgerPage(
            before: PointLedgerCursor(
              createdAtUtc: DateTime.parse(_createdAt),
              id: id,
            ),
          ),
        ),
        throwsArgumentError,
      );
      expect(reads, 0);
    });
  }

  for (final invalid in [
    (name: 'missing id', row: {..._row(1)}..remove('id')),
    (name: 'zero id', row: {..._row(1), 'id': 0}),
    (name: 'missing timestamp', row: {..._row(1)}..remove('created_at')),
    (name: 'invalid timestamp', row: {..._row(1), 'created_at': 'not-a-date'}),
  ]) {
    test('history rejects a row with ${invalid.name}', () async {
      final repository = BillingRepository(
        tokenStorage: _tokens(),
        pointLedgerPageQuery:
            ({
              required userId,
              required filter,
              required limit,
              required before,
            }) async => [invalid.row],
      );

      await expectLater(
        repository.getMyPointLedgerPage(),
        throwsFormatException,
      );
    });
  }

  test('history does not query while signed out', () async {
    var reads = 0;
    final repository = BillingRepository(
      tokenStorage: _tokens(null),
      pointLedgerPageQuery:
          ({
            required userId,
            required filter,
            required limit,
            required before,
          }) async {
            reads++;
            return [];
          },
    );

    await expectLater(repository.getMyPointLedgerPage(), throwsException);
    expect(reads, 0);
  });

  group('real Supabase query builder', () {
    late _Client client;
    late BillingRepository repository;
    late List<http.Request> requests;
    late List<Map<String, dynamic>> rows;

    setUp(() {
      requests = [];
      rows = [_row(100)];
      final auth = _Auth();
      when(() => auth.currentUser).thenReturn(
        User(
          id: _owner,
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-11-11',
        ),
      );
      client = _Client(
        auth,
        MockClient((request) async {
          requests.add(request);
          expect(request.method, 'GET');
          expect(request.url.origin, 'https://fixture.supabase.co');
          expect(request.url.path, '/rest/v1/point_ledger');
          return http.Response(
            jsonEncode(rows),
            200,
            headers: {'content-type': 'application/json'},
            // The real transport attaches its request; PostgREST reads it.
            request: request,
          );
        }),
      );
      // SDK ownership must win over a stale secure-storage account.
      repository = BillingRepository(
        tokenStorage: _tokens(_other),
        supabase: client,
      );
    });

    tearDown(() async => client.dispose());

    for (final selection in [
      (filter: PointLedgerFilter.all, delta: null),
      (filter: PointLedgerFilter.received, delta: 'gt.0'),
      (filter: PointLedgerFilter.spent, delta: 'lt.0'),
    ]) {
      test(
        '${selection.filter.name} filters on the server before the limit',
        () async {
          await repository.getMyPointLedgerPage(filter: selection.filter);

          final params = requests.single.url.queryParameters;
          expect(params['user_id'], 'eq.$_owner');
          expect(params['select'], contains('metadata'));
          expect(params['amount_delta'], selection.delta);
          expect(params['limit'], '21');
          expect(params['offset'], isNull);
          expect(params['or'], isNull);
          expect(
            params['order'],
            'created_at.desc.nullslast,id.desc.nullslast',
          );
        },
      );
    }

    test('a tied timestamp uses its id as the next-page boundary', () async {
      rows = [_row(100), _row(99), _row(98)];
      final first = await repository.getMyPointLedgerPage(limit: 2);
      expect(first.entries.map((entry) => entry.id), [100, 99]);
      expect(first.nextCursor!.id, 99);

      // A newly inserted head must not shift the older page through an offset.
      rows = [_row(98), _row(97)];
      final second = await repository.getMyPointLedgerPage(
        limit: 2,
        before: first.nextCursor,
      );

      final params = requests.last.url.queryParameters;
      expect(params['user_id'], 'eq.$_owner');
      expect(params['select'], contains('metadata'));
      expect(
        params['or'],
        '(created_at.lt.$_createdAt,and(created_at.eq.$_createdAt,id.lt.99))',
      );
      expect(params['order'], 'created_at.desc.nullslast,id.desc.nullslast');
      expect(params['limit'], '3');
      expect(params['offset'], isNull);
      expect(second.entries.map((entry) => entry.id), [98, 97]);
      expect(second.nextCursor, isNull);
    });

    test(
      'recent summary still sends five without the history lookahead',
      () async {
        await repository.getMyPointLedger();

        final params = requests.single.url.queryParameters;
        expect(params['user_id'], 'eq.$_owner');
        expect(params['select'], contains('metadata'));
        expect(params['limit'], '5');
        expect(params['amount_delta'], isNull);
        expect(params['or'], isNull);
      },
    );
  });
}
