import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_builder.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_interaction_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _SavedPhotoText extends ConsumerWidget {
  const _SavedPhotoText(this.source);
  final String source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interaction = LayerInteractionManager(
      ref: ref,
      coverKey: GlobalKey(),
      setState: (_) {},
      getCoverSize: () => const Size(500, 500),
      onEditText: (_) {},
    );
    return Stack(
      children: [
        LayerBuilder(interaction, () => const Size(500, 500)).buildText(
          LayerModel(
            id: 'saved-photo-text',
            type: LayerType.text,
            position: const Offset(10, 10),
            width: 300,
            height: 80,
            text: '우리의 사진',
            textFillMode: 'imageclip',
            textFillImageUrl: source,
            textStyle: const TextStyle(fontSize: 30),
          ),
        ),
      ],
    );
  }
}

void main() {
  final requests = <http.Request>[];
  var denyPhoto = false;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://saved-photo-text.invalid',
      anonKey: 'test',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(
            denyPhoto
                ? {'message': 'access denied'}
                : {
                    'signedURL':
                        '/object/sign/album-assets/photo.jpg?token=test',
                  },
          ),
          denyPhoto ? 403 : 200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
  });

  tearDownAll(() async => Supabase.instance.dispose());

  setUp(() {
    requests.clear();
    denyPhoto = false;
  });

  testWidgets('reopened photo-filled text authorizes its private saved photo', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 500,
              child: _SavedPhotoText(
                'supabase://album-assets/owner/albums/images/photo_preview.jpg',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(requests, hasLength(1));
    expect(
      requests.single.url.path,
      '/storage/v1/object/sign/album-assets/owner/albums/images/photo_preview.jpg',
    );
    expect(requests.single.method, 'POST');
    expect(find.text('우리의 사진'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'private photo denial leaves readable text without an async error',
    (tester) async {
      denyPhoto = true;
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 500,
                height: 500,
                child: _SavedPhotoText(
                  'supabase://album-assets/denied-owner/photo.jpg',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      expect(find.text('우리의 사진'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
