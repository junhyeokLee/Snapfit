import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/album/printing/print_album_document.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Tokens extends Mock implements TokenStorage {}

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late OrderRepository repo;
  late Map<String, dynamic> album;
  late List<String> paths;
  setUp(() async {
    paths = [];
    album = {
      'id': 7,
      'ratio': '1.4',
      'cover_theme': 'classic',
      'cover_layers_json': jsonEncode({
        'pages': [
          {'index': 0, 'isCover': true, 'layers': []},
          {'index': 1, 'isCover': false, 'layers': []},
        ],
      }),
    };
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      paths.add(request.uri.path);
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(
          request.uri.path.endsWith('/albums')
              ? album
              : [
                  {
                    'page_index': 0,
                    'page_number': 1,
                    'layers_json': jsonEncode({'layers': []}),
                  },
                ],
        ),
      );
      await request.response.close();
    });
    client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-key');
    final tokens = _Tokens();
    when(() => tokens.getResolvedUserId()).thenAnswer((_) async => 'owner');
    repo = OrderRepository(tokenStorage: tokens, supabase: client);
  });
  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });
  test(
    'full document preserves cover theme without reading stale legacy pages',
    () async {
      final snapshot = await repo.fetchPrintPreviewSnapshot(albumId: 7);
      expect((snapshot['album'] as Map)['cover_theme'], 'classic');
      expect(paths, ['/rest/v1/albums']);
      expect(PrintAlbumDocument.fromSnapshot(snapshot).interiors.length, 1);
    },
  );
  test(
    'legacy album fetches persisted pages so preview cannot omit photos',
    () async {
      album['cover_layers_json'] = jsonEncode({'layers': []});
      final snapshot = await repo.fetchPrintPreviewSnapshot(albumId: 7);
      expect(paths, ['/rest/v1/albums', '/rest/v1/album_pages']);
      final document = PrintAlbumDocument.fromSnapshot(snapshot);
      expect(document.interiors.length, 1);
      expect(document.interiors.single.index, 1);
    },
  );
}
