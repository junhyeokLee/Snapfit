import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/utils/saved_album_experience.dart';
import 'package:snap_fit/features/album/presentation/views/album_saved_experience_screen.dart';
import 'package:snap_fit/features/album/printing/print_album_document.dart';
import '../helpers/load_moment_capture_fonts.dart';

Album savedAlbum({String revision = 'revision-1', bool complete = false}) =>
    Album(
      id: 45,
      userId: 'owner',
      title: '오래 기억할 여름',
      ratio: '1',
      updatedAt: revision,
      targetPages: 2,
      totalPages: 2,
      coverLayersJson: jsonEncode({
        'pages': [
          for (var index = 0; index < 3; index++)
            {
              'index': index,
              'isCover': index == 0,
              'backgroundColor': index == 0 ? 0xffe9e6df : 0xfffffdf8,
              'layers': [
                if (index == 0)
                  {
                    'id': 'cover-photo',
                    'type': 'IMAGE',
                    'x': .04,
                    'y': .04,
                    'width': .92,
                    'height': .92,
                    'scale': 1,
                    'zIndex': 0,
                    'payload': {
                      'originalUrl': 'asset:assets/snapfit_home_square.jpg',
                    },
                  },
                if (index != 2 || complete)
                  {
                    'id': 'page-$index',
                    'type': 'TEXT',
                    'templateContent': false,
                    'x': .12,
                    'y': .15,
                    'width': .75,
                    'height': .5,
                    'scale': 1,
                    'zIndex': 1,
                    'payload': {
                      'text': index == 0
                          ? 'OUR\nSUMMER'
                          : '다시 꺼내 보고 싶은\n우리의 작은 날들',
                      'textStyle': {
                        'fontFamily': 'NotoSans',
                        'fontSizeRatio': .06,
                        'color': index == 0 ? '#FFFFFFFF' : '#FF263D35',
                      },
                    },
                  },
              ],
            },
        ],
      }),
    );

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  setUpAll(() async {
    if (Platform.environment['SNAPFIT_CAPTURE_SAVED_ALBUM'] != null) {
      await loadMomentCaptureFonts();
    }
  });
  Future<void> launch(
    WidgetTester tester, {
    required SavedAlbumLoader load,
    SavedAlbumPageRenderer? render,
    SavedAlbumImageWriter? write,
    Stream<String?> changes = const Stream.empty(),
    String? Function()? owner,
    Size size = const Size(390, 844),
    ThemeMode theme = ThemeMode.light,
    GlobalKey? captureKey,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          albumEditorOwnerReaderProvider.overrideWithValue(
            owner ?? () => 'owner',
          ),
          albumEditorOwnerChangesProvider.overrideWith((ref) => changes),
          savedAlbumLoaderProvider.overrideWithValue(load),
          if (render != null)
            savedAlbumPageRendererProvider.overrideWithValue(render),
          if (write != null)
            savedAlbumImageWriterProvider.overrideWithValue(write),
        ],
        child: MaterialApp(
          theme: SnapFitTheme.light(),
          darkTheme: SnapFitTheme.dark(),
          themeMode: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: captureKey,
            child: const AlbumSavedExperienceScreen(
              albumId: 45,
              ownerId: 'owner',
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets(
    'chosen page alone is rendered and shared after permission recheck',
    (tester) async {
      final rendered = <PrintAlbumPage>[];
      final names = <String>[];
      var reads = 0;
      await launch(
        tester,
        load: (_) async {
          reads++;
          return savedAlbum();
        },
        render: (page, theme) async {
          rendered.add(page);
          return Uint8List.fromList([1, 2, 3]);
        },
        write: (bytes, name, origin) async {
          expect(bytes, [1, 2, 3]);
          names.add(name);
        },
      );
      expect(find.text('1/2쪽 작성 · 언제든 이어 만들 수 있어요'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('saved-album-thumbnail-1')),
      );
      await tester.tap(find.byKey(const ValueKey('saved-album-thumbnail-1')));
      await settle(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('saved-album-export')),
      );
      await tester.tap(find.byKey(const ValueKey('saved-album-export')));
      await settle(tester);
      expect(rendered.map((p) => p.index), [1]);
      expect(names, ['snapfit-album-45-page-1.png']);
      expect(reads, 3); // open, before render, after render
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('changed saved revision requires another explicit page choice', (
    tester,
  ) async {
    var reads = 0, renders = 0, writes = 0;
    await launch(
      tester,
      load: (_) async =>
          savedAlbum(revision: ++reads == 1 ? 'revision-1' : 'revision-2'),
      render: (_, _) async {
        renders++;
        return Uint8List(1);
      },
      write: (_, _, _) async {
        writes++;
      },
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('saved-album-export')),
    );
    await tester.tap(find.byKey(const ValueKey('saved-album-export')));
    await settle(tester);
    expect(renders, 0);
    expect(writes, 0);
    expect(find.textContaining('공유할 페이지를 다시 골라'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account change discards a late private album response', (
    tester,
  ) async {
    final response = Completer<Album>();
    final changes = StreamController<String?>();
    addTearDown(changes.close);
    String? owner = 'owner';
    await launch(
      tester,
      load: (_) => response.future,
      changes: changes.stream,
      owner: () => owner,
    );
    owner = 'other';
    changes.add(owner);
    await settle(tester);
    response.complete(savedAlbum());
    await settle(tester);
    expect(find.text('오래 기억할 여름'), findsNothing);
    expect(find.textContaining('계정이 변경되었어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'sign out then back in during export never shares old photo bytes',
    (tester) async {
      final pending = Completer<Uint8List>();
      final changes = StreamController<String?>();
      addTearDown(changes.close);
      String? owner = 'owner';
      var writes = 0;
      await launch(
        tester,
        load: (_) async => savedAlbum(),
        changes: changes.stream,
        owner: () => owner,
        render: (_, _) => pending.future,
        write: (_, _, _) async {
          writes++;
        },
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('saved-album-export')),
      );
      await tester.tap(find.byKey(const ValueKey('saved-album-export')));
      await settle(tester);
      owner = null;
      changes.add(null);
      await settle(tester);
      owner = 'owner';
      changes.add(owner);
      await settle(tester);
      pending.complete(Uint8List.fromList([1]));
      await settle(tester);
      expect(writes, 0);
      expect(find.textContaining('계정이 변경되었어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('access revoked during rendering prevents the image sheet', (
    tester,
  ) async {
    var reads = 0, writes = 0;
    await launch(
      tester,
      load: (_) async {
        if (++reads == 3) throw StateError('access revoked');
        return savedAlbum();
      },
      render: (_, _) async => Uint8List(1),
      write: (_, _, _) async {
        writes++;
      },
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('saved-album-export')),
    );
    await tester.tap(find.byKey(const ValueKey('saved-album-export')));
    await settle(tester);
    expect(writes, 0);
    expect(find.textContaining('이미지를 준비하지 못했어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('load failure can retry without touching the editor', (
    tester,
  ) async {
    var reads = 0;
    await launch(
      tester,
      load: (_) async {
        if (++reads == 1) throw StateError('offline');
        return savedAlbum();
      },
    );
    expect(find.text('다시 불러오기'), findsOneWidget);
    await tester.tap(find.text('다시 불러오기'));
    await settle(tester);
    expect(find.text('오래 기억할 여름'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final entry in <(String, Size, ThemeMode)>[
    ('compact-light', const Size(320, 720), ThemeMode.light),
    ('phone-dark', const Size(390, 844), ThemeMode.dark),
    ('desktop-light', const Size(1365, 950), ThemeMode.light),
  ]) {
    testWidgets('saved album appreciation layout ${entry.$1}', (tester) async {
      final key = GlobalKey();
      await launch(
        tester,
        load: (_) async => savedAlbum(complete: true),
        size: entry.$2,
        theme: entry.$3,
        captureKey: key,
      );
      expect(find.text('한 권의 기록, 완성'), findsOneWidget);
      expect(find.byKey(const ValueKey('saved-album-gallery')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('saved-album-open')).hitTestable(),
        findsOneWidget,
      );
      if (entry.$2.width < 850) {
        final gallery = tester.getSize(
          find.byKey(const ValueKey('saved-album-gallery')),
        );
        expect(gallery.height, lessThanOrEqualTo(gallery.width + 50));
      }
      expect(tester.takeException(), isNull);
      final directory = Platform.environment['SNAPFIT_CAPTURE_SAVED_ALBUM'];
      if (directory != null) {
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File('$directory/saved-album-${entry.$1}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      }
    });
  }

  testWidgets(
    'landscape and large text keep the single primary action reachable',
    (tester) async {
      await launch(
        tester,
        load: (_) async => savedAlbum(),
        size: const Size(720, 390),
        textScale: 2.2,
      );
      expect(
        find.byKey(const ValueKey('saved-album-open')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
