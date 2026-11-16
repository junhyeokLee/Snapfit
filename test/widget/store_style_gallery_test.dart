import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/domain/store_template_discovery.dart';
import 'package:snap_fit/features/store/presentation/widgets/store_style_gallery.dart';

class _GalleryHost extends StatefulWidget {
  const _GalleryHost({
    required this.templates,
    required this.onChange,
    this.outerScroll,
    this.dark = false,
    this.textScale = 1,
  });
  final List<PremiumTemplate> templates;
  final ValueChanged<String?> onChange;
  final ScrollController? outerScroll;
  final bool dark;
  final double textScale;

  @override
  State<_GalleryHost> createState() => _GalleryHostState();
}

class _GalleryHostState extends State<_GalleryHost> {
  String? selected;

  void select(String? value) => setState(() {
    selected = value;
    widget.onChange(value);
  });

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: widget.dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(widget.textScale),
        disableAnimations: true,
      ),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        controller: widget.outerScroll,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              StoreStyleGallery(
                templates: widget.templates,
                styleId: selected,
                onStyleChanged: select,
              ),
              const SizedBox(height: 1200),
            ],
          ),
        ),
      ),
    ),
  );
}

String _assetName(Image image) {
  final provider = image.image;
  return (provider is ResizeImage ? provider.imageProvider : provider)
      .toString();
}

void _viewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('mood selection and reset never read template documents', (
    tester,
  ) async {
    _viewport(tester, 390);
    var documentReads = 0;
    final changes = <String?>[];
    final custom = PremiumTemplate(
      // Even an existing catalog ID cannot borrow another document's bitmap.
      id: -9301,
      title: '별도로 만든 디자인',
      category: '여행',
      tags: ['필름', '미니멀'],
      coverImageUrl: '',
      previewImages: const [],
      pageCount: 24,
      userCount: 0,
      documentBuilder: () {
        documentReads++;
        throw StateError('A mood filter must not build a document');
      },
    );
    await tester.pumpWidget(
      _GalleryHost(templates: [custom], onChange: changes.add),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('store-style-count-film')))
          .data,
      '1개',
    );
    final film = find.byKey(const ValueKey('store-style-film'));
    await tester.tap(film);
    await tester.pumpAndSettle();
    expect(changes, ['film']);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('store-style-count-minimal')))
          .data,
      '1개',
      reason: 'Selecting film must retain other moods from the pre-style scope',
    );
    expect(
      tester
          .widget<Semantics>(
            find.byKey(const ValueKey('store-style-semantics-film')),
          )
          .properties
          .selected,
      isTrue,
    );
    await tester.tap(film);
    await tester.pumpAndSettle();
    expect(changes, ['film', null]);
    await tester.tap(film);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('store-style-all')));
    await tester.pumpAndSettle();
    expect(changes, ['film', null, 'film', null]);
    expect(documentReads, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('real catalog supplies distinct covers and retains other moods', (
    tester,
  ) async {
    _viewport(tester, 390);
    await tester.pumpWidget(
      _GalleryHost(templates: publishedCreationTemplates, onChange: (_) {}),
    );
    await tester.pumpAndSettle();
    final before = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(before, hasLength(storeTemplateStyles.length));
    expect(
      before.map(_assetName).toSet(),
      hasLength(storeTemplateStyles.length),
    );
    for (final image in before) {
      expect(image.image, isA<ResizeImage>());
      expect((image.image as ResizeImage).width, 224);
      expect(image.excludeFromSemantics, isTrue);
    }
    await tester.tap(find.byKey(const ValueKey('store-style-film')));
    await tester.pumpAndSettle();
    for (final style in storeTemplateStyles) {
      expect(find.byKey(ValueKey('store-style-${style.id}')), findsOneWidget);
    }
    expect(
      tester.widgetList<Image>(find.byType(Image)).map(_assetName),
      before.map(_assetName),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('programmatic selection reveals only the horizontal mood shelf', (
    tester,
  ) async {
    _viewport(tester, 320);
    final outer = ScrollController();
    addTearDown(outer.dispose);
    await tester.pumpWidget(
      _GalleryHost(templates: const [], onChange: (_) {}, outerScroll: outer),
    );
    await tester.pumpAndSettle();
    outer.jumpTo(40);
    await tester.pumpAndSettle();
    final horizontal = tester
        .widget<SingleChildScrollView>(
          find.byKey(const ValueKey('store-style-filters')),
        )
        .controller!;
    tester
        .state<_GalleryHostState>(find.byType(_GalleryHost))
        .select('editorial');
    await tester.pumpAndSettle();
    expect(outer.offset, 40);
    expect(horizontal.offset, greaterThan(0));
    final tile = tester.getRect(
      find.byKey(const ValueKey('store-style-editorial')),
    );
    final shelf = tester.getRect(
      find.byKey(const ValueKey('store-style-filters')),
    );
    expect(tile.left, greaterThanOrEqualTo(shelf.left - .5));
    expect(tile.right, lessThanOrEqualTo(shelf.right + .5));

    tester.state<_GalleryHostState>(find.byType(_GalleryHost)).select(null);
    await tester.pumpAndSettle();
    expect(outer.offset, 40);
    expect(horizontal.offset, horizontal.position.minScrollExtent);
    expect(tester.takeException(), isNull);
  });

  for (final (width, scale, dark) in [
    (390.0, 1.0, false),
    (320.0, 2.0, false),
    (320.0, 2.0, true),
  ]) {
    testWidgets('compact mood layout width=$width scale=$scale dark=$dark', (
      tester,
    ) async {
      _viewport(tester, width);
      await tester.pumpWidget(
        _GalleryHost(
          templates: const [],
          onChange: (_) {},
          dark: dark,
          textScale: scale,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('분위기로 골라보기'), findsOneWidget);
      final reset = tester.getSize(
        find.byKey(const ValueKey('store-style-all')),
      );
      expect(reset.width, greaterThanOrEqualTo(44));
      expect(reset.height, greaterThanOrEqualTo(44));
      if (scale == 1) {
        expect(
          tester.getSize(find.byType(StoreStyleGallery)).height,
          lessThanOrEqualTo(145),
        );
        final shelf = tester.getRect(
          find.byKey(const ValueKey('store-style-filters')),
        );
        final next = tester.getRect(
          find.byKey(const ValueKey('store-style-natural')),
        );
        expect(next.left, lessThan(shelf.right));
        expect(next.right, greaterThan(shelf.right));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
