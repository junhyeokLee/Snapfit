import '../support/store_detail_loading.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/core/templates/retired_store_templates.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_access.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/data/repositories/supabase_template_repository.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

class _Tokens extends Mock implements TokenStorage {}

String _retiredDocument() => '{"templateId":"jeju_travel_v1"}';

PremiumTemplate _template(
  int id, {
  String title = '새로운 디자인',
  String? document,
}) => PremiumTemplate(
  id: id,
  title: title,
  coverImageUrl: '',
  previewImages: const [],
  pageCount: 12,
  userCount: 0,
  templateJson: document,
);

Map<String, dynamic> _row(
  int id, {
  String title = '새로운 디자인',
  Object? document,
}) => {'id': id, 'title': title, 'is_active': true, 'template_json': document};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('retirement keeps all 13 historical numeric identities explicit', () {
    expect(RetiredStoreTemplates.ids, {
      46,
      48,
      49,
      50,
      51,
      52,
      53,
      54,
      55,
      -1115056,
      -8006,
      -8007,
      -8008,
    });
    for (final id in RetiredStoreTemplates.ids) {
      expect(RetiredStoreTemplates.matches(id: id), isTrue, reason: '$id');
    }
  });

  for (final title in RetiredStoreTemplates.titles) {
    test('renumbering cannot restore retired title $title', () {
      expect(
        RetiredStoreTemplates.matches(
          id: 2000,
          title: ' ${title.toUpperCase()} ',
        ),
        isTrue,
      );
    });
  }

  for (final stem in RetiredStoreTemplates.stems) {
    test('renaming cannot restore retired document $stem', () {
      for (final id in [stem, '${stem}_v1', '${stem.toUpperCase()}-v12']) {
        expect(RetiredStoreTemplates.matches(templateId: id), isTrue);
        expect(
          RetiredStoreTemplates.matches(
            id: 2000,
            title: '새로운 제목',
            templateJson: jsonEncode({'templateId': id}),
          ),
          isTrue,
        );
      }
    });
  }

  test(
    'document identities include metadata and the old imported document',
    () {
      for (final document in [
        {'id': 'figma_import_1775063050456'},
        {
          'metadata': {'templateId': 'jeju_travel_v1'},
        },
        {
          'metadata': {'id': 'save_the_date_v1'},
        },
      ]) {
        expect(
          RetiredStoreTemplates.matches(templateJson: jsonEncode(document)),
          isTrue,
        );
      }
    },
  );

  test(
    'shared assets, saved layer captions and new identities are not retired',
    () {
      for (final document in [
        '{bad',
        '[]',
        jsonEncode({'templateId': 'jeju_travel_v1_new_edition'}),
        jsonEncode({
          'id': 'snapfit_original_journey_square',
          'layers': [
            {
              'text': 'SAVE THE DATE',
              'imageUrl':
                  'asset:assets/templates/jeju_travel/images/approved_stock/cover.png',
            },
          ],
        }),
      ]) {
        expect(
          RetiredStoreTemplates.matches(
            id: 2000,
            title: '새로운 여행',
            templateJson: document,
          ),
          isFalse,
        );
      }
    },
  );

  test(
    'all current designs remain eligible without building their documents',
    () {
      expect(publishedCreationTemplates, isNotEmpty);
      expect(
        publishedCreationTemplates.map((t) => t.id).toSet(),
        hasLength(publishedCreationTemplates.length),
      );
      for (final template in publishedCreationTemplates) {
        expect(
          isRetiredStoreTemplate(template),
          isFalse,
          reason: template.title,
        );
      }
    },
  );

  test(
    'bulk catalog checks never evaluate valid or already retired lazy books',
    () {
      var builds = 0;
      final templates = [
        for (var i = 0; i < 36; i++)
          PremiumTemplate(
            id: 2000 + i,
            title: 'New design $i',
            coverImageUrl: '',
            previewImages: const [],
            pageCount: 12,
            userCount: 0,
            documentBuilder: () {
              builds++;
              return '{"templateId":"new_design_v1"}';
            },
          ),
        PremiumTemplate(
          id: 46,
          title: 'Renamed retired design',
          coverImageUrl: '',
          previewImages: const [],
          pageCount: 12,
          userCount: 0,
          documentBuilder: () {
            builds++;
            throw StateError(
              'An old numeric identity needs no document lookup',
            );
          },
        ),
      ];
      final merged = mergeTemplatesWithServer(templates, templates);
      expect(merged, hasLength(36));
      expect(merged.any((template) => template.id == 46), isFalse);
      expect(builds, 0);
      final scope = ProviderContainer(
        overrides: [mockTemplateList(() => templates)],
      );
      addTearDown(scope.dispose);
      scope.read(templateListProvider);
      expect(scope.read(storeTemplateFeedProvider).items, hasLength(36));
      expect(builds, 0);
    },
  );

  test('direct inspection rejects a renamed retired lazy document', () {
    var builds = 0;
    final template = PremiumTemplate(
      id: 2000,
      title: 'Renamed design',
      coverImageUrl: '',
      previewImages: const [],
      pageCount: 12,
      userCount: 0,
      documentBuilder: () {
        builds++;
        return '{"templateId":"jeju_travel_v1"}';
      },
    );
    expect(isRetiredStoreTemplate(template), isFalse);
    expect(builds, 0);
    expect(isRetiredStoreTemplate(template, inspectLazyDocument: true), isTrue);
    expect(builds, 1);
  });

  test(
    'merge rejects retired local and server rows but preserves valid unknown products',
    () {
      final current = publishedCreationTemplates.first;
      final valid = _template(2000);
      final retired = [
        _template(46),
        _template(2001, title: 'SAVE THE DATE'),
        _template(2002, document: '{"templateId":"jeju_travel_v1"}'),
      ];
      final merged = mergeTemplatesWithServer(
        [...publishedCreationTemplates, ...retired],
        [...retired, valid, current.copyWith(likeCount: 9, userCount: 17)],
      );
      expect(merged, hasLength(publishedCreationTemplates.length + 1));
      expect(merged.first.id, valid.id);
      expect(merged.any(isRetiredStoreTemplate), isFalse);
      final retained = merged.singleWhere((item) => item.id == current.id);
      expect(retained.likeCount, 9);
      expect(retained.userCount, 17);
      expect(retained.documentBuilder, same(current.documentBuilder));
      expect(merged.map((item) => item.id).toSet(), {
        ...publishedCreationTemplates.map((item) => item.id),
        2000,
      });
    },
  );

  test(
    'feed initial state removes retired rows from a synchronous catalog',
    () {
      final scope = ProviderContainer(
        overrides: [
          mockTemplateList(() => [_template(46), _template(2000)]),
        ],
      );
      addTearDown(scope.dispose);
      // Resolve the synchronous catalog override before the feed reads it.
      scope.read(templateListProvider);
      final feed = scope.read(storeTemplateFeedProvider);
      expect(feed.items.map((item) => item.id), [2000]);
    },
  );

  group('repository entry points', () {
    late SupabaseClient client;
    late SupabaseTemplateRepository repository;
    late List<http.Request> requests;
    late Object response;

    setUp(() {
      response = [];
      requests = [];
      client = SupabaseClient(
        'https://fixture.invalid',
        'public-test-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode(response),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      repository = SupabaseTemplateRepository(client, tokenStorage: _Tokens());
      addTearDown(client.dispose);
    });

    test('list filters IDs, normalized titles and JSONB identities', () async {
      response = [
        _row(46),
        _row(2001, title: ' Save-the-date '),
        _row(2002, document: {'templateId': 'film_diary_v1'}),
        _row(2000, document: {'templateId': 'new_design_v1', 'pages': []}),
      ];
      final items = await repository.getTemplates();
      expect(items.map((item) => item.id), [2000]);
      expect(jsonDecode(items.single.templateJson!), {
        'templateId': 'new_design_v1',
        'pages': [],
      });
      expect(requests.single.url.queryParameters['is_active'], 'eq.true');
    });

    test('retired full page does not hide a later valid page', () async {
      response = [_row(46), _row(49)];
      final page = await repository.getTemplateSummaries(size: 2);
      expect(page.content, isEmpty);
      expect(page.hasNext, isTrue);
    });

    test('detail rejects every old ID before making a request', () async {
      for (final id in RetiredStoreTemplates.ids) {
        await expectLater(repository.getTemplate(id), throwsStateError);
      }
      expect(requests, isEmpty);
    });

    test(
      'detail requires active data and rejects renamed retired JSONB',
      () async {
        response = _row(2000, document: {'templateId': 'soft_babybook_v1'});
        await expectLater(repository.getTemplate(2000), throwsStateError);
        expect(requests.single.url.queryParameters['is_active'], 'eq.true');
        expect(requests.single.url.queryParameters['id'], 'eq.2000');
      },
    );

    test(
      'valid unknown detail remains available with normalized JSONB',
      () async {
        response = _row(2000, document: {'templateId': 'new_design_v1'});
        final template = await repository.getTemplate(2000);
        expect(template.id, 2000);
        expect(jsonDecode(template.templateJson!), {
          'templateId': 'new_design_v1',
        });
      },
    );

    test(
      'stale likes and album creation cannot restore an old numeric ID',
      () async {
        await expectLater(repository.likeTemplate(46), throwsStateError);
        await expectLater(
          repository.createAlbumFromTemplate(46),
          throwsException,
        );
        expect(requests, isEmpty);
      },
    );
  });

  storeDetailTestWidgets(
    'direct detail checks lazy document identity before rendering',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProviderScope(
            child: TemplateDetailScreen(
              template: PremiumTemplate(
                id: 2000,
                title: 'Renamed design',
                coverImageUrl: '',
                previewImages: const [],
                pageCount: 12,
                userCount: 0,
                documentBuilder: _retiredDocument,
              ),
            ),
          ),
        ),
      );
      await settleStoreDetail(tester);
      expect(find.text('이전 디자인은 더 이상 제공하지 않아요.'), findsOneWidget);
      expect(find.byType(TemplatePageRenderer), findsNothing);
      expect(find.byKey(const ValueKey('template-detail-use')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final selectForCreation in [false, true]) {
    storeDetailTestWidgets(
      'stale direct detail cannot preview or select old artwork: chooser=$selectForCreation',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        var requests = 0;
        var access = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              templateRepositoryProvider.overrideWith((ref) {
                requests++;
                throw StateError('Retired detail must not query server');
              }),
              pointShopAccessGateProvider.overrideWithValue((
                context,
                ref, {
                required productKey,
                required title,
              }) async {
                access++;
                return true;
              }),
            ],
            child: MaterialApp(
              home: TemplateDetailScreen(
                template: _template(46, title: '제주의 기록'),
                selectForCreation: selectForCreation,
              ),
            ),
          ),
        );
        await settleStoreDetail(tester);
        expect(find.text('이전 디자인은 더 이상 제공하지 않아요.'), findsOneWidget);
        expect(find.text('돌아가기').hitTestable(), findsOneWidget);
        expect(find.byType(TemplatePageRenderer), findsNothing);
        expect(find.byKey(const ValueKey('template-detail-use')), findsNothing);
        expect(find.text('이 디자인 선택'), findsNothing);
        expect(requests, 0);
        expect(access, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
