// Temporary, local capture harness. Run one case in each fresh Flutter process:
// MONTH_AUDIT_CASE=phone flutter test --concurrency=1 <copied_test_path>
// MONTH_AUDIT_CASE=compact flutter test --concurrency=1 <copied_test_path>
// Product code and existing tests are deliberately left unchanged.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/moments/data/moment_engagement_repository.dart';
import 'package:snap_fit/features/moments/data/moment_publication_repository.dart';
import 'package:snap_fit/features/moments/data/moments_repository.dart';
import 'package:snap_fit/features/moments/data/private_moment_archive_repository.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/domain/monthly_album_builder.dart';
import 'package:snap_fit/features/moments/domain/private_moment_archive.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_engagement_providers.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_publication_providers.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/moments/presentation/providers/private_moment_archive_providers.dart';
import 'package:snap_fit/features/moments/presentation/views/monthly_moment_preview_screen.dart';
import 'package:snap_fit/shared/snapfit_image.dart';

final _month = DateTime.utc(2026, 10);
final _today = DateTime.utc(2026, 10, 18);
const _captureKey = ValueKey('month-audit-capture');
const _assets = [
  'assets/cover/cover1.png',
  'assets/cover/cover2.png',
  'assets/cover/cover3.png',
  'assets/cover/cover4.png',
  'assets/cover/cover5.png',
  'assets/cover/cover6.png',
];

// The local asset is the transport source, so no private-storage SDK/network
// lookup can occur while inspecting the real photo and album widgets.
class _AssetPhoto extends MomentPhoto {
  const _AssetPhoto({required super.id, required super.path, required super.url})
    : super(width: 1024, height: 1536);
  @override
  String get storageUri => url;
}

// Existing photographic assets are decoded from rootBundle, never replaced by
// boxes or mocked image bytes. Their real dimensions are 1024 × 1536.
List<MomentRecord> _records() => [
  for (var day = 1; day <= 18; day++)
    MomentRecord(
      id: 'audit-day-$day',
      recordDate: DateTime.utc(2026, 10, day),
      caption: '오늘 걸으며 만난 장면 $day',
      revision: 1,
      photos: [
        for (var index = 0; index < 2; index++)
          _AssetPhoto(
            id: 'audit-day-$day-photo-$index',
            path: 'owner/moments/audit-day-$day/photo-$index.png',
            url: 'asset:${_assets[((day - 1) * 2 + index) % _assets.length]}',
          ),
      ],
    ),
];

class _Repository implements MomentsRepository {
  final changes = StreamController<String?>.broadcast();
  int writes = 0;
  @override
  String get currentUserId => 'owner';
  @override
  Stream<String?> get authChanges => changes.stream;
  @override
  Future<MomentJournal> listMonth(DateTime? month) async => MomentJournal(
    today: _today,
    weekStart: momentWeekStart(_today),
    month: _month,
    records: _records(),
    weekPhotoCount: 14,
  );
  @override
  Future<Album> createMonthlyAlbum({
    required DateTime month,
    required List<MomentRecord> selectedRecords,
    required List<String> selectedPhotoIds,
    required String title,
  }) async {
    writes++;
    throw StateError('Audit captures must not create an album.');
  }
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected repository access: ${invocation.memberName}');
}

class _Archive implements PrivateMomentArchiveRepository {
  final changes = StreamController<int>.broadcast();
  @override
  String get currentUserId => 'owner';
  @override
  int get sessionRevision => 0;
  @override
  Stream<int> get sessionChanges => changes.stream;
  @override
  Future<List<String>> monthlyPhotoChoices({
    required String ownerId,
    required DateTime month,
  }) async => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected archive access: ${invocation.memberName}');
}

class _Engagement implements MomentEngagementRepository {
  @override
  Future<bool> recordActivity(MomentActivity activity, {DateTime? month}) async =>
      true;
  @override
  Future<MomentEngagement> load() async => const MomentEngagement(
    reminder: MomentReminder(),
    hasRecords: true,
  );
  @override
  Future<MomentEngagement> saveReminder(MomentReminder reminder) async =>
      MomentEngagement(reminder: reminder, hasRecords: true);
}

class _Publications implements MomentPublicationRepository {
  @override
  Future<MomentPublicationState?> state(String recordId) async =>
      MomentPublicationState(
        recordId: recordId,
        recordRevision: 1,
        sourceRevision: 1,
        status: 'private',
        publicationRevision: 0,
      );
  @override
  void dispose() {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected publication access: ${invocation.memberName}');
}

Future<void> _loadFonts() async {
  for (final entry in {
    'NotoSans': [
      'assets/fonts/NotoSansKR-Regular.ttf',
      'assets/fonts/NotoSansKR-SemiBold.ttf',
      'assets/fonts/NotoSansKR-Bold.ttf',
    ],
    'Eulyoo': [
      'assets/fonts/Eulyoo1945-Regular.ttf',
      'assets/fonts/Eulyoo1945-SemiBold.ttf',
    ],
    'Poppins': [
      'assets/fonts/Poppins-Regular.otf',
      'assets/fonts/Poppins-SemiBold.otf',
    ],
    'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
  }.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }
}

Future<void> _decodeImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    final seen = <String>{};
    for (final element in find.byType(SnapfitImage).evaluate()) {
      final widget = element.widget as SnapfitImage;
      if (!widget.urlOrGs.startsWith('asset:')) continue;
      final key = '${widget.urlOrGs}:${widget.memCacheWidth}:${widget.memCacheHeight}';
      if (!seen.add(key)) continue;
      Object? failure;
      await precacheImage(
        ResizeImage.resizeIfNeeded(
          widget.memCacheWidth,
          widget.memCacheHeight,
          AssetImage(widget.urlOrGs.substring(6)),
        ),
        element,
        onError: (error, stack) => failure = error,
      );
      if (failure != null) throw StateError('Photo decode failed: $failure');
    }
    // Await the exact providers mounted by the real image widgets as well.
    for (final element in find.byType(Image).evaluate()) {
      Object? failure;
      await precacheImage(
        (element.widget as Image).image,
        element,
        onError: (error, stack) => failure = error,
      );
      if (failure != null) throw StateError('Mounted image decode failed: $failure');
    }
  });
  await tester.pump(const Duration(milliseconds: 100));
  expect(
    tester.widgetList<RawImage>(find.byType(RawImage)).any((image) => image.image != null),
    isTrue,
    reason: 'A capture must contain decoded photographs, not loading placeholders.',
  );
}

Finder _scrollable() => find.descendant(
  of: find.byType(ListView).first,
  matching: find.byType(Scrollable),
).first;

Future<void> _reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    240,
    scrollable: _scrollable(),
    maxScrolls: 100,
  );
  await tester.ensureVisible(target);
  await tester.pump(const Duration(milliseconds: 200));
  await _decodeImages(tester);
}

Future<void> _png(WidgetTester tester, String path) async {
  void repaint(RenderObject node) {
    node.markNeedsPaint();
    node.visitChildren(repaint);
  }
  repaint(tester.renderObject<RenderRepaintBoundary>(find.byKey(_captureKey)));
  await tester.pump();
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_captureKey));
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  final caseName = Platform.environment['MONTH_AUDIT_CASE'] ?? 'phone';
  const cases = {'phone': Size(390, 844), 'compact': Size(320, 568)};
  final viewport = cases[caseName];
  if (viewport == null) throw ArgumentError('MONTH_AUDIT_CASE must be phone or compact.');
  final out = Platform.environment['MONTH_AUDIT_DIR'] ??
      'docs/verification/record-next-audit-2026-11-12/month';
  setUpAll(_loadFonts);

  testWidgets('month accumulation audit $caseName', (tester) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    final repository = _Repository();
    final archive = _Archive();
    final records = _records();
    final selected = selectMonthlyMomentPhotoIds(month: _month, records: records);
    final container = ProviderContainer(overrides: [
      momentsRepositoryProvider.overrideWithValue(repository),
      privateMomentArchiveRepositoryProvider.overrideWithValue(archive),
      momentEngagementRepositoryProvider.overrideWithValue(_Engagement()),
      momentPublicationRepositoryProvider.overrideWithValue(_Publications()),
    ]);
    final stages = <Map<String, dynamic>>[];
    Map<String, dynamic> stage(String name, int selectionCount) {
      final position = tester.state<ScrollableState>(_scrollable()).position;
      return {
        'stage': name,
        'selectedCount': selectionCount,
        'scrollPixels': position.pixels,
        // A lazy ListView may refine this estimate as later children mount.
        'reportedMaxScrollExtentAtStage': position.maxScrollExtent,
        'scrollViewportHeight': position.viewportDimension,
        'decodedRawImageWidgets': tester.widgetList<RawImage>(find.byType(RawImage))
            .where((image) => image.image != null).length,
      };
    }
    try {
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: SnapFitTheme.light(),
          builder: (context, child) => RepaintBoundary(key: _captureKey, child: child!),
          home: MonthlyMomentPreviewScreen(month: _month, today: _today, records: records),
        ),
      ));
      await tester.pump();
      await _decodeImages(tester);
      stages.add(stage('top', selected.length));
      await _png(tester, '$out/monthly-$caseName-top.png');

      // The cross-month default includes a photo around the middle of the grid.
      // Deselect that real tile to document an ordinary selection interaction.
      final middleId = selected[selected.length ~/ 2];
      final middle = find.byKey(ValueKey('moment-photo-select-$middleId'));
      await _reveal(tester, middle);
      final middleSemantics = find.ancestor(
        of: middle,
        matching: find.byWidgetPredicate((widget) => widget is Semantics &&
            widget.properties.selected != null &&
            widget.properties.label?.contains(' 사진') == true),
      ).first;
      expect(tester.widget<Semantics>(middleSemantics).properties.selected, isTrue);
      await tester.tap(middle);
      await tester.pumpAndSettle();
      expect(tester.widget<Semantics>(middleSemantics).properties.selected, isFalse);
      await _decodeImages(tester);
      stages.add(stage('middle-selection', selected.length - 1));
      await _png(tester, '$out/monthly-$caseName-middle.png');

      final cta = find.byKey(const ValueKey('monthly-moment-create'));
      await _reveal(tester, cta);
      expect(tester.widget<FilledButton>(cta).onPressed, isNotNull);
      stages.add(stage('final-cta', selected.length - 1));
      await _png(tester, '$out/monthly-$caseName-cta.png');
      final position = tester.state<ScrollableState>(_scrollable()).position;
      final ctaRect = tester.getRect(cta);
      final viewportRect = tester.getRect(_scrollable());
      final ctaContentTop = position.pixels + ctaRect.top - viewportRect.top;
      final ctaRevealScroll = math.max(0.0, ctaContentTop + ctaRect.height - position.viewportDimension);
      for (final snapshot in stages) {
        final pixels = snapshot['scrollPixels'] as double;
        snapshot.addAll({
          'finalMeasuredMaxScrollExtent': position.maxScrollExtent,
          'ctaContentTop': ctaContentTop,
          'ctaHeight': ctaRect.height,
          'additionalScrollToFullyRevealCta': math.max(0.0, ctaRevealScroll - pixels),
          'additionalViewportHeightsToCta': math.max(0.0, ctaRevealScroll - pixels) /
              (snapshot['scrollViewportHeight'] as double),
        });
      }
      final metrics = {
        'case': caseName,
        'viewport': {'width': viewport.width, 'height': viewport.height},
        'fixture': {'days': records.length, 'photosPerDay': 2, 'photoCount': 36, 'assets': _assets},
        'screen': 'MonthlyMomentPreviewScreen, new album, actual product widget',
        'stages': stages,
        'albumWrites': repository.writes,
        'ctaActivated': false,
      };
      await tester.runAsync(() async {
        final file = File('$out/monthly-$caseName-metrics.json');
        await file.parent.create(recursive: true);
        await file.writeAsString(const JsonEncoder.withIndent('  ').convert(metrics));
      });
      // ignore: avoid_print
      print('MONTH_AUDIT_METRICS ${jsonEncode(metrics)}');
      expect(repository.writes, 0);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      container.dispose();
      await repository.changes.close();
      await archive.changes.close();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }
  });
}
