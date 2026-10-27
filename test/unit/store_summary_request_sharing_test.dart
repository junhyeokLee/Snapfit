import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/store/data/repositories/supabase_template_repository.dart';
import 'package:snap_fit/features/store/domain/entities/template_summary_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Tokens extends TokenStorage {}

Map<String, Object> _row(int id, {String? likedBy}) => {
  'id': id,
  'title': 'Design $id',
  'is_active': true,
  'page_count': 12,
  'template_likes': [
    if (likedBy != null) {'user_id': likedBy},
  ],
};

class _Read {
  _Read(this.request);
  final http.Request request;
  final response = Completer<http.Response>();

  void complete(Object? body, {int status = 200}) => response.complete(
    http.Response(
      jsonEncode(body),
      status,
      request: request,
      headers: {'content-type': 'application/json'},
    ),
  );
}

class _Fixture {
  final reads = <_Read>[];
  bool failLike = false;
  int likesWritten = 0;
  int albumsCreated = 0;
  int countsIncremented = 0;
  late final client = SupabaseClient(
    'https://fixture.invalid',
    'public-test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/templates') && request.method == 'GET') {
        if (request.url.queryParameters.containsKey('id')) {
          return _response(request, _row(88001));
        }
        final read = _Read(request);
        reads.add(read);
        return read.response.future;
      }
      if (path.endsWith('/template_likes')) {
        if (request.method == 'GET') return _response(request, null);
        if (failLike) {
          return _response(request, {
            'message': 'Expected failure',
          }, status: 400);
        }
        likesWritten++;
        return _response(request, null, status: 201);
      }
      if (path.endsWith('/albums') && request.method == 'POST') {
        albumsCreated++;
        return _response(request, {
          'id': 88002,
          'owner_id': 'account-a',
          'title': 'Design 88001',
          'total_pages': 12,
          'target_pages': 12,
          'sort_order': 0,
        });
      }
      if (path.endsWith('/rpc/increment_template_user_count')) {
        countsIncremented++;
        return _response(request, null);
      }
      throw StateError('Unexpected fixture request ${request.method} $path');
    }),
  );
  late final repository = SupabaseTemplateRepository(
    client,
    tokenStorage: _Tokens(),
  );

  static http.Response _response(
    http.Request request,
    Object? body, {
    int status = 200,
  }) => http.Response(
    jsonEncode(body),
    status,
    request: request,
    headers: {'content-type': 'application/json'},
  );

  Future<void> waitForReads(int count) async {
    for (var attempt = 0; reads.length < count && attempt < 200; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(reads, hasLength(count));
  }

  Future<void> session(String account, {String version = '1'}) async {
    String encode(Object json) =>
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    final token =
        '${encode({'alg': 'none'})}.'
        '${encode({'sub': account, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600, 'session_id': version})}.fixture';
    await client.auth.setInitialSession(
      jsonEncode({
        'access_token': token,
        'refresh_token': 'fixture-refresh-$version',
        'token_type': 'bearer',
        'user': {'id': account, 'aud': 'authenticated', 'app_metadata': {}},
      }),
    );
  }

  Future<void> dispose() async {
    for (final read in reads) {
      if (!read.response.isCompleted) read.complete([]);
    }
    await client.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Fixture fixture;
  setUp(() {
    fixture = _Fixture();
    addTearDown(fixture.dispose);
  });

  test(
    'equivalent pending summaries share one transport and parsed result',
    () async {
      final first = fixture.repository.getTemplateSummaries();
      final other = fixture.repository.getTemplateSummaries(category: '전체');
      final empty = fixture.repository.getTemplateSummaries(
        category: '',
        query: '',
      );
      expect(other, same(first));
      expect(empty, same(first));
      await fixture.waitForReads(1);
      fixture.reads.single.complete([_row(88001)]);
      final results = await Future.wait([first, other, empty]);
      expect(results[1], same(results[0]));
      expect(results[2].content.single.id, 88001);
      expect(
        () => results.first.content[0] = results.first.content.single,
        throwsUnsupportedError,
      );
      expect(
        fixture.reads.single.request.url.queryParameters,
        containsPair('limit', '20'),
      );
    },
  );

  test(
    'page, size, category, search and price scopes stay independent',
    () async {
      final requests = [
        fixture.repository.getTemplateSummaries(),
        fixture.repository.getTemplateSummaries(page: 1),
        fixture.repository.getTemplateSummaries(size: 12),
        fixture.repository.getTemplateSummaries(category: '여행'),
        fixture.repository.getTemplateSummaries(query: '오후'),
        fixture.repository.getTemplateSummaries(query: ' 오후 '),
        fixture.repository.getTemplateSummaries(isPaid: true),
        fixture.repository.getTemplateSummaries(isPaid: false),
      ];
      await fixture.waitForReads(requests.length);
      final queries = fixture.reads
          .map((read) => read.request.url.queryParameters)
          .toList();
      expect(queries[1], containsPair('offset', '20'));
      expect(queries[2], containsPair('limit', '12'));
      expect(queries[3], containsPair('category', 'eq.여행'));
      expect(queries[4], containsPair('title', 'ilike.%오후%'));
      expect(queries[5], containsPair('title', 'ilike.% 오후 %'));
      expect(queries[6], containsPair('is_premium', 'eq.true'));
      expect(queries[7], containsPair('is_premium', 'eq.false'));
      for (var i = fixture.reads.length - 1; i >= 0; i--) {
        fixture.reads[i].complete([_row(88000 + i)]);
      }
      final results = await Future.wait(requests);
      expect(results.map((page) => page.content.single.id), [
        for (var i = 0; i < requests.length; i++) 88000 + i,
      ]);
      expect(results[1].page, 1);
      expect(results[2].size, 12);
    },
  );

  test(
    'completed summaries are released and a refresh reads fresh rows',
    () async {
      Future<TemplateSummaryPage>? previous;
      for (var visit = 0; visit < 8; visit++) {
        final request = fixture.repository.getTemplateSummaries();
        expect(request, isNot(same(previous)));
        final joined = fixture.repository.getTemplateSummaries();
        expect(joined, same(request));
        await fixture.waitForReads(visit + 1);
        fixture.reads.last.complete([_row(88000 + visit)]);
        expect((await request).content.single.id, 88000 + visit);
        previous = request;
      }
    },
  );

  test(
    'shared failure reaches all callers and retry starts one new request',
    () async {
      final first = fixture.repository.getTemplateSummaries();
      final joined = fixture.repository.getTemplateSummaries();
      final errors = Future.wait([
        expectLater(first, throwsA(isA<PostgrestException>())),
        expectLater(joined, throwsA(isA<PostgrestException>())),
      ]);
      await fixture.waitForReads(1);
      fixture.reads.single.complete({
        'message': 'Expected failure',
      }, status: 400);
      await errors;
      final retry = fixture.repository.getTemplateSummaries();
      expect(retry, isNot(same(first)));
      expect(fixture.repository.getTemplateSummaries(), same(retry));
      await fixture.waitForReads(2);
      fixture.reads.last.complete([_row(88002)]);
      expect((await retry).content.single.id, 88002);
    },
  );

  test(
    'anonymous, changed accounts and restored same-account sessions never join',
    () async {
      final anonymous = fixture.repository.getTemplateSummaries();
      await fixture.waitForReads(1);
      final requests = [anonymous];
      for (final account in [
        'account-a',
        'account-b',
        'account-a',
        'account-a',
      ]) {
        // The last restoration uses equal token contents but a new SDK session.
        await fixture.session(account);
        final request = fixture.repository.getTemplateSummaries();
        expect(fixture.repository.getTemplateSummaries(), same(request));
        requests.add(request);
        await fixture.waitForReads(requests.length);
      }
      fixture.reads.first.complete([_row(88001, likedBy: 'account-a')]);
      expect((await anonymous).content.single.isLiked, isFalse);
      // Old completion must not remove the latest account's pending entry.
      expect(fixture.repository.getTemplateSummaries(), same(requests.last));
      for (var i = 1; i < fixture.reads.length; i++) {
        fixture.reads[i].complete([_row(88001, likedBy: 'account-a')]);
      }
      final results = await Future.wait(requests);
      expect(results.map((page) => page.content.single.isLiked), [
        false,
        true,
        false,
        true,
        true,
      ]);
    },
  );

  test(
    'a successful like invalidates sharing and old completion cannot evict its replacement',
    () async {
      await fixture.session('account-a');
      final old = fixture.repository.getTemplateSummaries();
      await fixture.waitForReads(1);
      await fixture.repository.likeTemplate(88001);
      expect(fixture.likesWritten, 1);
      final fresh = fixture.repository.getTemplateSummaries();
      await fixture.waitForReads(2);
      fixture.reads.first.complete([_row(88001)]);
      expect((await old).content.single.isLiked, isFalse);
      expect(fixture.repository.getTemplateSummaries(), same(fresh));
      expect(fixture.reads, hasLength(2));
      fixture.reads.last.complete([_row(88001, likedBy: 'account-a')]);
      expect((await fresh).content.single.isLiked, isTrue);
    },
  );

  test('a rejected like keeps the pending read reusable', () async {
    await fixture.session('account-a');
    final pending = fixture.repository.getTemplateSummaries();
    await fixture.waitForReads(1);
    fixture.failLike = true;
    await expectLater(
      fixture.repository.likeTemplate(88001),
      throwsA(isA<PostgrestException>()),
    );
    expect(fixture.repository.getTemplateSummaries(), same(pending));
    fixture.reads.single.complete([_row(88001)]);
    await pending;
  });

  test('album creation invalidates pre-write user-count summaries', () async {
    await fixture.session('account-a');
    final old = fixture.repository.getTemplateSummaries();
    await fixture.waitForReads(1);
    final album = await fixture.repository.createAlbumFromTemplate(88001);
    expect(album.id, 88002);
    expect(fixture.albumsCreated, 1);
    expect(fixture.countsIncremented, 1);
    final fresh = fixture.repository.getTemplateSummaries();
    await fixture.waitForReads(2);
    fixture.reads.first.complete([_row(88001)]);
    await old;
    expect(fixture.repository.getTemplateSummaries(), same(fresh));
    fixture.reads.last.complete([
      {..._row(88001), 'user_count': 1},
    ]);
    expect((await fresh).content.single.userCount, 1);
  });
}
