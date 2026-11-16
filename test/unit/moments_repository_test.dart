import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/domain/repositories/album_repository.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';
import 'package:snap_fit/features/billing/domain/entities/storage_preflight.dart';
import 'package:snap_fit/features/moments/data/moment_photo_codec.dart';
import 'package:snap_fit/features/moments/data/moments_repository.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/domain/moment_photo_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _a = '11111111-1111-4111-8111-111111111111';
const _b = '22222222-2222-4222-8222-222222222222';
const _id = '33333333-3333-4333-8333-333333333333';
const _photoId = '44444444-4444-4444-8444-444444444444';
const _removedPhotoId = '55555555-5555-4555-8555-555555555555';
const _path = '$_a/moments/$_id/$_photoId.png';
const _removedPath = '$_a/moments/$_id/$_removedPhotoId.png';

class _Auth extends Mock implements GoTrueClient {}

class _Albums extends Mock implements AlbumRepository {}

class _Billing extends Mock implements BillingRepository {}

class _Client extends SupabaseClient {
  _Client(this.fixtureAuth, http.Client transport)
    : super(
        'https://fixture.supabase.co',
        'fixture-key',
        httpClient: transport,
        accessToken: () async => 'fixture-token',
      );
  final GoTrueClient fixtureAuth;
  @override
  GoTrueClient get auth => fixtureAuth;
}

User _user(String id) => User(
  id: id,
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-10-26T00:00:00Z',
);
Map<String, dynamic> _record() => {
  'id': _id,
  'record_date': '2026-10-26',
  'caption': '가을 산책',
  'photos': [
    {'id': _photoId, 'path': _path, 'width': 1920, 'height': 1280},
  ],
  'revision': 1,
};
Map<String, dynamic> _journal({List<dynamic> records = const []}) => {
  'today': '2026-11-01',
  'weekStart': '2026-10-26',
  'month': '2026-11-01',
  'records': records,
  'weekPhotoCount': 3,
  'monthlyAlbumId': null,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth auth;
  late _Client client;
  late SupabaseMomentsRepository repository;
  late _Billing billing;
  late _Albums albums;
  late StreamController<AuthState> events;
  late String? actor;
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) respond;
  late Future<void> Function() prepareMonthlyFonts;
  http.Response response(Object value, [int status = 200]) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json'},
  );
  void change(String? id) {
    actor = id;
    events.add(
      AuthState(
        id == null ? AuthChangeEvent.signedOut : AuthChangeEvent.signedIn,
        id == null
            ? null
            : Session(
                accessToken: 'fixture-token',
                tokenType: 'bearer',
                user: _user(id),
              ),
      ),
    );
  }

  setUp(() {
    actor = _a;
    requests = [];
    auth = _Auth();
    events = StreamController<AuthState>.broadcast(sync: true);
    when(
      () => auth.currentUser,
    ).thenAnswer((_) => actor == null ? null : _user(actor!));
    when(() => auth.onAuthStateChange).thenAnswer((_) => events.stream);
    respond = (_) async => response(_journal());
    client = _Client(
      auth,
      MockClient((request) async {
        requests.add(request);
        final result = await respond(request);
        return http.Response.bytes(
          result.bodyBytes,
          result.statusCode,
          headers: result.headers,
          request: request,
        );
      }),
    );
    billing = _Billing();
    albums = _Albums();
    prepareMonthlyFonts = () async {};
    repository = SupabaseMomentsRepository(
      client,
      albums: albums,
      billing: billing,
      prepareMonthlyFonts: () => prepareMonthlyFonts(),
    );
  });

  test('current journal omits device month and uses the server day', () async {
    final journal = await repository.listMonth(null);
    final request = requests.single;
    expect(jsonDecode(request.body), {'p_month': null});
    expect(journal.today, DateTime.utc(2026, 11, 1));
    expect(journal.month, DateTime.utc(2026, 11, 1));
  });
  tearDown(() async {
    repository.dispose();
    await events.close();
    await client.dispose();
  });

  test(
    'journal uses normalized month and server cross-month weekly total',
    () async {
      final result = await repository.listMonth(DateTime(2026, 11, 19));
      expect(jsonDecode(requests.single.body), {'p_month': '2026-11-01'});
      expect(result.weekStart, DateTime.utc(2026, 10, 26));
      expect(result.weekPhotoCount, 3);
      expect(result.records, isEmpty);
    },
  );
  test('signed-out request never reaches API', () async {
    change(null);
    await expectLater(
      repository.listMonth(DateTime.utc(2026, 11)),
      throwsA(isA<MomentException>()),
    );
    expect(requests, isEmpty);
  });
  test('A to B to A cannot show response from previous session', () async {
    final pending = Completer<http.Response>();
    respond = (_) => pending.future;
    final result = repository.listMonth(DateTime.utc(2026, 11));
    await Future<void>.delayed(Duration.zero);
    change(_b);
    change(_a);
    pending.complete(response(_journal()));
    await expectLater(result, throwsA(isA<MomentException>()));
  });
  test(
    'save sends stable identifiers and expected revision, no display URLs',
    () async {
      respond = (request) async => request.url.path.contains('/rest/v1/')
          ? response(_record())
          : response([
              {
                'path': _path,
                'signedURL': '/object/sign/album-assets/$_path?token=fixture',
              },
            ]);
      final record = MomentRecord.fromJson(_record());
      await repository.save(
        id: _id,
        recordDate: record.recordDate,
        caption: ' 가을 산책 ',
        existingPhotos: record.photos,
        uploads: [],
        expectedRevision: 1,
      );
      final body = jsonDecode(requests.first.body) as Map;
      expect(body['p_id'], _id);
      expect(body['p_expected_revision'], 1);
      expect(body['p_caption'], '가을 산책');
      expect(body['p_photos'], _record()['photos']);
      expect(body.containsKey('owner_id'), isFalse);
      expect(
        requests.where(
          (request) =>
              request.method == 'POST' &&
              request.url.path.contains('save_weekly_moment'),
        ),
        hasLength(1),
      );
    },
  );
  test(
    'saving edited retained photos preserves private layers without reuploading originals',
    () async {
      final design = MomentPhotoDesign.fromJson({
        'version': 1,
        'canvas': {'width': 500, 'height': 400},
        'backgroundColor': '#fff8edda',
        'layers': [
          {
            'id': 'original',
            'type': 'IMAGE',
            'zIndex': 0,
            'x': 0,
            'y': 0,
            'width': 1,
            'height': 1,
            'rotation': 0,
            'payload': {
              'originalUrl': momentPhotoOriginalSource,
              'imageTemplate': 'free',
            },
          },
        ],
      });
      final photo = MomentPhoto.fromJson((_record()['photos'] as List).single)
          .withUrl('https://private.invalid/signed?token=secret')
          .withDesign(design);
      respond = (request) async {
        if (request.url.path.contains('/rest/v1/')) {
          final body = jsonDecode(request.body) as Map;
          return response({
            ..._record(),
            'photos': body['p_photos'],
            'revision': 2,
          });
        }
        return response([]);
      };
      final saved = await repository.save(
        id: _id,
        recordDate: DateTime.utc(2026, 10, 26),
        caption: '피드에만 남긴 글',
        existingPhotos: [photo],
        uploads: [],
        expectedRevision: 1,
      );
      final body = jsonDecode(requests.first.body) as Map;
      expect(body['p_photos'][0]['design'], design.toJson());
      expect(saved.photos.single.design!.toJson(), design.toJson());
      expect(jsonEncode(body['p_photos']), isNot(contains('token=secret')));
      expect(jsonEncode(body['p_photos']), isNot(contains('피드에만')));
      verifyNever(
        () => billing.preflightStorage(
          incomingBytes: any(named: 'incomingBytes'),
        ),
      );
      expect(
        requests.where((r) => r.url.path.contains('/storage/v1/object/')),
        isEmpty,
      );
    },
  );
  test(
    'invalid photo count and duplicate selection fail before upload',
    () async {
      final photo = MomentPhoto.fromJson((_record()['photos'] as List).single);
      for (final photos in <List<MomentPhoto>>[
        [],
        [photo, photo],
        [photo, photo, photo, photo],
      ]) {
        await expectLater(
          repository.save(
            id: _id,
            recordDate: DateTime.utc(2026, 10, 26),
            caption: '',
            existingPhotos: photos,
            uploads: [],
          ),
          throwsA(isA<MomentException>()),
        );
      }
      expect(requests, isEmpty);
    },
  );
  test(
    'optimistic edit conflict is surfaced without retrying an overwrite',
    () async {
      respond = (_) async => response({
        'message': 'moment_revision_conflict',
        'code': 'PT409',
      }, 409);
      final record = MomentRecord.fromJson(_record());
      await expectLater(
        repository.save(
          id: _id,
          recordDate: record.recordDate,
          caption: '수정',
          existingPhotos: record.photos,
          uploads: [],
          expectedRevision: 1,
        ),
        throwsA(
          isA<MomentException>().having(
            (error) => error.message,
            'message',
            contains('다른 곳'),
          ),
        ),
      );
      expect(requests, hasLength(1));
    },
  );
  test('confirmed save remains success if preview URL refresh fails', () async {
    respond = (request) async => request.url.path.contains('/rest/v1/')
        ? response(_record())
        : response({'message': 'unavailable'}, 503);
    final record = MomentRecord.fromJson(_record());
    final saved = await repository.save(
      id: _id,
      recordDate: record.recordDate,
      caption: record.caption,
      existingPhotos: record.photos,
      uploads: [],
      expectedRevision: 1,
    );
    expect(saved.id, _id);
    expect(saved.photos.single.url, isEmpty);
  });
  test(
    'delete commits the journal mutation before guarded photo cleanup',
    () async {
      respond = (request) async => request.method == 'DELETE'
          ? response({
              'statusCode': 403,
              'error': 'Forbidden',
              'message': 'MOMENTS_PHOTO_IN_USE',
            }, 403)
          : response(true);
      await repository.delete(MomentRecord.fromJson(_record()));
      expect(requests, hasLength(2));
      expect(requests.first.method, 'POST');
      expect(requests.first.url.path, '/rest/v1/rpc/delete_weekly_moment');
      expect(jsonDecode(requests.first.body), {
        'p_id': _id,
        'p_expected_revision': 1,
      });
      expect(requests.last.method, 'DELETE');
      expect(requests.last.url.path, '/storage/v1/object/album-assets');
      expect(jsonDecode(requests.last.body), {
        'prefixes': [_path],
      });
    },
  );

  test(
    'successful edit only cleans originals absent from the saved record',
    () async {
      final record = MomentRecord.fromJson(_record());
      const removed = MomentPhoto(
        id: _removedPhotoId,
        path: _removedPath,
        width: 600,
        height: 800,
      );
      respond = (request) async =>
          request.method == 'DELETE' ? response([]) : response(_record());
      final saved = await repository.save(
        id: _id,
        recordDate: record.recordDate,
        caption: record.caption,
        existingPhotos: record.photos,
        originalPhotos: [...record.photos, removed],
        uploads: [],
        expectedRevision: 1,
      );
      expect(saved.photos.single.path, _path);
      expect(requests.map((request) => request.method), ['POST', 'DELETE']);
      expect(requests.first.url.path, '/rest/v1/rpc/save_weekly_moment');
      final cleanup = jsonDecode(requests.last.body) as Map;
      expect(cleanup['prefixes'], [_removedPath]);
      expect(cleanup['prefixes'], isNot(contains(_path)));
    },
  );

  test(
    'failed save preserves its original error when upload cleanup fails',
    () async {
      final input = img.encodePng(img.Image(width: 2, height: 2));
      when(
        () => billing.preflightStorage(
          incomingBytes: any(named: 'incomingBytes'),
        ),
      ).thenAnswer(
        (_) async => const StoragePreflightStatus(
          userId: _a,
          planCode: 'FREE',
          incomingBytes: 100,
          usedBytes: 0,
          projectedBytes: 100,
          hardLimitBytes: 1000,
          remainingBytes: 1000,
          allowed: true,
          reason: 'OK',
        ),
      );
      respond = (request) async {
        if (request.method == 'DELETE') {
          return response({
            'statusCode': 503,
            'error': 'Unavailable',
            'message': 'cleanup unavailable',
          }, 503);
        }
        if (request.url.path.contains('/rest/v1/')) {
          return response({
            'message': 'moment_revision_conflict',
            'code': 'PT409',
          }, 409);
        }
        return response({'Key': 'album-assets/$_path', 'Id': _photoId});
      };
      await expectLater(
        repository.save(
          id: _id,
          recordDate: DateTime.utc(2026, 10, 26),
          caption: '',
          existingPhotos: [],
          originalPhotos: [
            const MomentPhoto(
              id: _removedPhotoId,
              path: _removedPath,
              width: 600,
              height: 800,
            ),
          ],
          uploads: [
            MomentUpload(id: _photoId, bytes: input, filename: 'photo.png'),
          ],
          expectedRevision: 1,
        ),
        throwsA(
          isA<MomentException>().having(
            (error) => error.message,
            'original save error',
            contains('다른 곳'),
          ),
        ),
      );
      expect(requests.map((request) => request.method), [
        'POST',
        'POST',
        'DELETE',
      ]);
      expect(requests[1].url.path, '/rest/v1/rpc/save_weekly_moment');
      expect(jsonDecode(requests.last.body), {
        'prefixes': [_path],
      });
      expect(
        requests.where((request) => request.method == 'DELETE').single.body,
        isNot(contains(_removedPath)),
      );
    },
  );

  for (final returnToOriginal in [false, true]) {
    test(
      'changed ${returnToOriginal ? 'A to B to A' : 'A to B'} session skips failed upload cleanup',
      () async {
        final input = img.encodePng(img.Image(width: 2, height: 2));
        when(
          () => billing.preflightStorage(
            incomingBytes: any(named: 'incomingBytes'),
          ),
        ).thenAnswer(
          (_) async => const StoragePreflightStatus(
            userId: _a,
            planCode: 'FREE',
            incomingBytes: 100,
            usedBytes: 0,
            projectedBytes: 100,
            hardLimitBytes: 1000,
            remainingBytes: 1000,
            allowed: true,
            reason: 'OK',
          ),
        );
        respond = (request) async {
          if (request.url.path.contains('/rest/v1/')) {
            change(_b);
            if (returnToOriginal) change(_a);
            return response({
              'message': 'moment_revision_conflict',
              'code': 'PT409',
            }, 409);
          }
          return response({'Key': 'album-assets/$_path', 'Id': _photoId});
        };
        await expectLater(
          repository.save(
            id: _id,
            recordDate: DateTime.utc(2026, 10, 26),
            caption: '',
            existingPhotos: [],
            uploads: [
              MomentUpload(id: _photoId, bytes: input, filename: 'photo.png'),
            ],
          ),
          throwsA(
            isA<MomentException>().having(
              (error) => error.message,
              'session error',
              contains('계정이 변경'),
            ),
          ),
        );
        expect(requests, hasLength(2));
        expect(requests.map((request) => request.method), ['POST', 'POST']);
        expect(requests.last.url.path, '/rest/v1/rpc/save_weekly_moment');
        expect(
          requests.where((request) => request.method == 'DELETE'),
          isEmpty,
        );
      },
    );
  }
  test(
    'a full quota still permits retrying an identical already-uploaded photo',
    () async {
      final input = img.encodePng(img.Image(width: 2, height: 2));
      final prepared = await prepareMomentPhoto(input);
      final design = MomentPhotoDesign.fromJson({
        'version': 1,
        'canvas': {'width': 100, 'height': 100},
        'backgroundColor': '#ffffffff',
        'layers': [
          {
            'id': 'original',
            'type': 'IMAGE',
            'x': 0,
            'y': 0,
            'width': 1,
            'height': 1,
            'rotation': 0,
            'payload': {'originalUrl': momentPhotoOriginalSource},
          },
        ],
      });
      when(
        () => billing.preflightStorage(
          incomingBytes: any(named: 'incomingBytes'),
        ),
      ).thenAnswer(
        (_) async => const StoragePreflightStatus(
          userId: _a,
          planCode: 'FREE',
          incomingBytes: 100,
          usedBytes: 100,
          projectedBytes: 200,
          hardLimitBytes: 100,
          remainingBytes: 0,
          allowed: false,
          reason: 'HARD_LIMIT',
        ),
      );
      respond = (request) async {
        if (request.method == 'GET')
          return http.Response.bytes(prepared.bytes, 200);
        if (request.url.path.contains('/rest/v1/')) return response(_record());
        return response([
          {
            'path': _path,
            'signedURL': '/object/sign/album-assets/$_path?token=fixture',
          },
        ]);
      };
      final saved = await repository.save(
        id: _id,
        recordDate: DateTime.utc(2026, 10, 26),
        caption: '',
        existingPhotos: [],
        uploads: [
          MomentUpload(
            id: _photoId,
            bytes: input,
            filename: 'photo.png',
            design: design,
          ),
        ],
      );
      expect(saved.id, _id);
      final request = requests.singleWhere(
        (r) => r.url.path.contains('save_weekly_moment'),
      );
      expect(
        jsonDecode(request.body)['p_photos'][0]['design'],
        design.toJson(),
      );
      expect(
        requests.where(
          (request) =>
              request.url.path.contains('/storage/v1/object/') &&
              request.method == 'POST',
        ),
        isEmpty,
      );
      expect(
        requests.where(
          (request) => request.url.path.contains('save_weekly_moment'),
        ),
        hasLength(1),
      );
    },
  );

  test(
    'a full quota cannot reuse an object containing different photo bytes',
    () async {
      final input = img.encodePng(img.Image(width: 2, height: 2));
      when(
        () => billing.preflightStorage(
          incomingBytes: any(named: 'incomingBytes'),
        ),
      ).thenAnswer(
        (_) async => const StoragePreflightStatus(
          userId: _a,
          planCode: 'FREE',
          incomingBytes: 100,
          usedBytes: 100,
          projectedBytes: 200,
          hardLimitBytes: 100,
          remainingBytes: 0,
          allowed: false,
          reason: 'HARD_LIMIT',
        ),
      );
      respond = (request) async => request.method == 'DELETE'
          ? response({
              'statusCode': 403,
              'error': 'Forbidden',
              'message': 'MOMENTS_PHOTO_IN_USE',
            }, 403)
          : http.Response.bytes([1, 2, 3], 200);
      await expectLater(
        repository.save(
          id: _id,
          recordDate: DateTime.utc(2026, 10, 26),
          caption: '',
          existingPhotos: [],
          uploads: [
            MomentUpload(id: _photoId, bytes: input, filename: 'photo.png'),
          ],
        ),
        throwsA(
          isA<MomentException>().having(
            (error) => error.message,
            'message',
            contains('저장 공간'),
          ),
        ),
      );
      expect(requests.map((request) => request.method), ['GET', 'DELETE']);
      expect(requests.last.url.path, '/storage/v1/object/album-assets');
      expect(jsonDecode(requests.last.body), {
        'prefixes': [_path],
      });
      expect(
        requests.where((request) => request.url.path.contains('/rest/v1/')),
        isEmpty,
      );
    },
  );

  test(
    'journal parses cross-month week records independently of browsed month',
    () async {
      respond = (_) async => response({
        ..._journal(),
        'weekRecords': [_record()],
        'monthlyAlbumPhotoIds': [_photoId],
      });
      final result = await repository.listMonth(DateTime.utc(2026, 11));
      expect(result.records, isEmpty);
      expect(
        result.currentWeekRecords.single.recordDate,
        DateTime.utc(2026, 10, 26),
      );
      expect(result.monthlyAlbumPhotoIds, [_photoId]);
      expect(result.withRecords([]).currentWeekRecords.single.id, _id);
    },
  );
  test(
    'legacy journal fallback filters current-week dates rather than monthly count',
    () {
      final data = {
        ..._journal(records: [_record()]),
        'weekStart': '2026-10-27',
      };
      final result = MomentJournal.fromJson(data);
      expect(result.currentWeekRecords, isEmpty);
      expect(result.monthlyAlbumPhotoIds, isEmpty);
    },
  );
  test(
    'append sends new inner pages and current revision without existing album changes',
    () async {
      const initial = Album(
        id: 42,
        title: 'My edited title',
        ratio: '4/3',
        updatedAt: '2026-10-26T03:00:00Z',
        coverLayersJson: '{"private":"preserve"}',
      );
      const saved = Album(
        id: 42,
        title: 'My edited title',
        updatedAt: '2026-10-26T03:00:01Z',
      );
      var reads = 0;
      when(
        () => albums.fetchAlbum('42'),
      ).thenAnswer((_) async => reads++ == 0 ? initial : saved);
      respond = (request) async =>
          request.url.path.endsWith('get_moment_journal')
          ? response({..._journal(), 'monthlyAlbumId': 42})
          : response({'albumId': 42, 'appended': true});
      final result = await repository.appendMonthlyAlbum(
        month: DateTime.utc(2026, 10),
        selectedRecords: [MomentRecord.fromJson(_record())],
        selectedPhotoIds: [_photoId],
      );
      expect(result, saved);
      final body = jsonDecode(requests.last.body) as Map;
      expect(body['p_expected_updated_at'], initial.updatedAt);
      expect(body['p_album_id'], 42);
      expect(body['p_photo_ids'], [_photoId]);
      expect(body.keys.toSet(), {
        'p_month',
        'p_album_id',
        'p_photo_ids',
        'p_pages',
        'p_expected_updated_at',
      });
      final pages = body['p_pages'] as List;
      expect(pages, hasLength(1));
      expect((pages.single as Map)['isCover'], false);
      expect(jsonEncode(pages), contains('supabase://album-assets/$_path'));
      expect(jsonEncode(body), isNot(contains('My edited title')));
      final canvas = coverCanvasBaseSize(initial.physicalCoverSize);
      final layers = ((pages.single as Map)['layers'] as List).map(
        (value) => LayerExportMapper.fromJson(
          Map<String, dynamic>.from(value as Map),
          canvasSize: canvas,
        ),
      );
      final photo = layers.singleWhere(
        (layer) => layer.type == LayerType.image,
      );
      expect(photo.width / photo.height, closeTo(1920 / 1280, .0001));
      expect(photo.imageZoom, 1);
    },
  );
  test(
    'new monthly album waits for original fonts before measuring or mutating',
    () async {
      final fonts = Completer<void>();
      prepareMonthlyFonts = () => fonts.future;
      when(
        () => albums.fetchAlbum('42'),
      ).thenAnswer((_) async => const Album(id: 42));
      respond = (_) async => response({'albumId': 42});
      final pending = repository.createMonthlyAlbum(
        month: DateTime.utc(2026, 10),
        selectedRecords: [MomentRecord.fromJson(_record())],
        selectedPhotoIds: [_photoId],
        title: '가을의 기록',
      );
      await Future<void>.delayed(Duration.zero);
      expect(requests, isEmpty);
      verifyNever(() => albums.fetchAlbum(any()));
      fonts.complete();
      expect((await pending).id, 42);
      expect(
        requests.single.url.path,
        '/rest/v1/rpc/create_moment_month_album',
      );
      final body = jsonDecode(requests.single.body) as Map;
      expect(jsonEncode(body['p_album']), contains('Eulyoo'));
      expect(body['p_photo_ids'], [_photoId]);
    },
  );

  for (final backToOriginal in [false, true]) {
    test(
      'monthly creation cancels after ${backToOriginal ? 'A to B to A' : 'A to B'} during font loading',
      () async {
        final fonts = Completer<void>();
        prepareMonthlyFonts = () => fonts.future;
        final pending = repository.createMonthlyAlbum(
          month: DateTime.utc(2026, 10),
          selectedRecords: [MomentRecord.fromJson(_record())],
          selectedPhotoIds: [_photoId],
          title: '가을의 기록',
        );
        change(_b);
        if (backToOriginal) change(_a);
        fonts.complete();
        await expectLater(pending, throwsA(isA<MomentException>()));
        expect(requests, isEmpty);
        verifyNever(() => albums.fetchAlbum(any()));
      },
    );
  }

  test(
    'failed monthly font preparation leaves no album request and can retry',
    () async {
      var attempts = 0;
      prepareMonthlyFonts = () async {
        if (++attempts == 1) throw StateError('font download failed');
      };
      when(
        () => albums.fetchAlbum('42'),
      ).thenAnswer((_) async => const Album(id: 42));
      respond = (_) async => response({'albumId': 42});
      Future<Album> create() => repository.createMonthlyAlbum(
        month: DateTime.utc(2026, 10),
        selectedRecords: [MomentRecord.fromJson(_record())],
        selectedPhotoIds: [_photoId],
        title: '가을의 기록',
      );
      await expectLater(create(), throwsStateError);
      expect(requests, isEmpty);
      expect((await create()).id, 42);
      expect(requests, hasLength(1));
    },
  );

  test('monthly append rechecks session after waiting for fonts', () async {
    final fonts = Completer<void>();
    final preparing = Completer<void>();
    prepareMonthlyFonts = () {
      preparing.complete();
      return fonts.future;
    };
    when(() => albums.fetchAlbum('42')).thenAnswer(
      (_) async => const Album(id: 42, updatedAt: '2026-10-26T03:00:00Z'),
    );
    respond = (_) async => response({..._journal(), 'monthlyAlbumId': 42});
    final pending = repository.appendMonthlyAlbum(
      month: DateTime.utc(2026, 10),
      selectedRecords: [MomentRecord.fromJson(_record())],
      selectedPhotoIds: [_photoId],
    );
    await preparing.future;
    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/rest/v1/rpc/get_moment_journal');
    change(_b);
    change(_a);
    fonts.complete();
    await expectLater(pending, throwsA(isA<MomentException>()));
    expect(requests, hasLength(1));
  });
  test(
    'append opens existing album without mutation when selected photos were imported',
    () async {
      const initial = Album(id: 42, updatedAt: '2026-10-26T03:00:00Z');
      when(() => albums.fetchAlbum('42')).thenAnswer((_) async => initial);
      respond = (_) async => response({
        ..._journal(),
        'monthlyAlbumId': 42,
        'monthlyAlbumPhotoIds': [_photoId],
      });
      expect(
        await repository.appendMonthlyAlbum(
          month: DateTime.utc(2026, 10),
          selectedRecords: [MomentRecord.fromJson(_record())],
          selectedPhotoIds: [_photoId],
        ),
        initial,
      );
      expect(requests, hasLength(1));
    },
  );
  test(
    'append cancels before mutation if account switches during album fetch',
    () async {
      when(() => albums.fetchAlbum('42')).thenAnswer((_) async {
        change(_b);
        change(_a);
        return const Album(id: 42, updatedAt: '2026-10-26T03:00:00Z');
      });
      respond = (_) async => response({..._journal(), 'monthlyAlbumId': 42});
      await expectLater(
        repository.appendMonthlyAlbum(
          month: DateTime.utc(2026, 10),
          selectedRecords: [MomentRecord.fromJson(_record())],
          selectedPhotoIds: [_photoId],
        ),
        throwsA(isA<MomentException>()),
      );
      expect(requests, hasLength(1));
    },
  );

  test('KST calendar turns at 15 UTC and week handles year boundary', () {
    expect(
      momentToday(DateTime.utc(2026, 12, 31, 14, 59)),
      DateTime.utc(2026, 12, 31),
    );
    expect(
      momentToday(DateTime.utc(2026, 12, 31, 15)),
      DateTime.utc(2027, 1, 1),
    );
    expect(
      momentWeekStart(DateTime.utc(2027, 1, 1)),
      DateTime.utc(2026, 12, 28),
    );
  });
}
