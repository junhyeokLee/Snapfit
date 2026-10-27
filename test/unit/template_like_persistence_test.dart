import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';

const _key = 'template_like_state_v1';

class _ControlledStore extends InMemorySharedPreferencesStore {
  _ControlledStore({this.blockFirst = false, this.failFirst = false})
    : super.withData({});
  final bool blockFirst;
  final bool failFirst;
  final firstWrite = Completer<void>();
  int calls = 0;
  int active = 0;
  int peakActive = 0;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    final call = ++calls;
    active++;
    if (active > peakActive) peakActive = active;
    try {
      if (call == 1 && blockFirst) await firstWrite.future;
      if (call == 1 && failFirst)
        throw StateError('Expected local write failure');
      return await super.setValue(type, key, value);
    } finally {
      active--;
    }
  }
}

PremiumTemplate _template(int id, {bool liked = true, int count = 1}) =>
    PremiumTemplate(
      id: id,
      title: 'Like persistence $id',
      coverImageUrl: '',
      previewImages: const [],
      pageCount: 12,
      userCount: 0,
      isLiked: liked,
      likeCount: count,
      documentBuilder: () => throw StateError('Persist only metadata'),
    );

Future<Map<String, dynamic>> _stored() async {
  final prefs = await SharedPreferences.getInstance();
  // Read back from the backing store, not just the process cache.
  await prefs.reload();
  return jsonDecode(prefs.getString(_key)!) as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      _key: jsonEncode({
        'account-a:id:440000': {'isLiked': true, 'likeCount': 9},
      }),
    });
    await SharedPreferences.getInstance();
  });

  test(
    'concurrent different-template likes preserve both and previous records',
    () async {
      await Future.wait([
        persistTemplateLikeState(_template(440001), userId: 'account-a'),
        persistTemplateLikeState(
          _template(440002, count: 2),
          userId: 'account-a',
        ),
      ]);
      final stored = await _stored();
      expect(
        stored.keys,
        containsAll([
          'account-a:id:440000',
          'account-a:id:440001',
          'account-a:id:440002',
        ]),
      );
      expect(stored['account-a:id:440002'], {'isLiked': true, 'likeCount': 2});
    },
  );

  test(
    'concurrent account and guest writes keep their separate scopes',
    () async {
      await Future.wait([
        persistTemplateLikeState(
          _template(440001, count: 4),
          userId: ' account-a ',
        ),
        persistTemplateLikeState(
          _template(440001, liked: false, count: 3),
          userId: 'account-b',
        ),
        persistTemplateLikeState(_template(440001, count: 2)),
      ]);
      final stored = await _stored();
      expect(stored['account-a:id:440001'], {'isLiked': true, 'likeCount': 4});
      expect(stored['account-b:id:440001'], {'isLiked': false, 'likeCount': 3});
      expect(stored['guest:id:440001'], {'isLiked': true, 'likeCount': 2});
    },
  );

  test(
    'rapid toggles keep the latest intent without losing another template',
    () async {
      await Future.wait([
        persistTemplateLikeState(_template(440001), userId: 'account-a'),
        persistTemplateLikeState(_template(440002), userId: 'account-a'),
        persistTemplateLikeState(
          _template(440001, liked: false, count: 0),
          userId: 'account-a',
        ),
        persistTemplateLikeState(
          _template(440001, count: 3),
          userId: 'account-a',
        ),
      ]);
      final stored = await _stored();
      expect(stored['account-a:id:440001'], {'isLiked': true, 'likeCount': 3});
      expect(stored['account-a:id:440002'], {'isLiked': true, 'likeCount': 1});
      expect(stored['account-a:id:440000'], {'isLiked': true, 'likeCount': 9});
    },
  );

  test(
    'cold preferences initialization cannot reorder rapid toggle intent',
    () async {
      SharedPreferences.setMockInitialValues({});
      await Future.wait([
        persistTemplateLikeState(_template(440001), userId: 'account-a'),
        persistTemplateLikeState(_template(440002), userId: 'account-a'),
        persistTemplateLikeState(
          _template(440001, liked: false, count: 0),
          userId: 'account-a',
        ),
        persistTemplateLikeState(
          _template(440001, count: 3),
          userId: 'account-a',
        ),
      ]);
      final stored = await _stored();
      expect(stored['account-a:id:440001'], {'isLiked': true, 'likeCount': 3});
      expect(stored['account-a:id:440002'], {'isLiked': true, 'likeCount': 1});
    },
  );

  test(
    'a delayed earlier backing-store write cannot overwrite a later record',
    () async {
      final previous = SharedPreferencesStorePlatform.instance;
      final store = _ControlledStore(blockFirst: true);
      SharedPreferencesStorePlatform.instance = store;
      addTearDown(() => SharedPreferencesStorePlatform.instance = previous);
      final first = persistTemplateLikeState(
        _template(440001),
        userId: 'account-a',
      );
      final second = persistTemplateLikeState(
        _template(440002),
        userId: 'account-a',
      );
      try {
        for (var i = 0; store.calls == 0 && i < 100; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        await Future<void>.delayed(Duration.zero);
        expect(
          store.calls,
          1,
          reason: 'Only one backing-store update may be active',
        );
      } finally {
        store.firstWrite.complete();
        await Future.wait([first, second]);
      }
      expect(store.peakActive, 1);
      final stored = await _stored();
      expect(
        stored.keys,
        containsAll(['account-a:id:440001', 'account-a:id:440002']),
      );
    },
  );

  test(
    'a failed write does not poison the queue or prevent subsequent writes',
    () async {
      final previous = SharedPreferencesStorePlatform.instance;
      final store = _ControlledStore(failFirst: true);
      SharedPreferencesStorePlatform.instance = store;
      addTearDown(() => SharedPreferencesStorePlatform.instance = previous);
      await Future.wait([
        persistTemplateLikeState(_template(440001), userId: 'account-a'),
        persistTemplateLikeState(
          _template(440002, count: 4),
          userId: 'account-b',
        ),
      ]);
      await persistTemplateLikeState(
        _template(440003, count: -1),
        userId: 'account-b',
      );
      final stored = await _stored();
      expect(stored['account-b:id:440002'], {'isLiked': true, 'likeCount': 4});
      expect(stored['account-b:id:440003'], {'isLiked': true, 'likeCount': 1});
      expect(store.active, 0);
    },
  );
}
