import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_document_preview.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

List<List<LayerModel>> lightboundPreviewPages(
  CollectionAspect aspect,
  LightboundWeddingCopy copy, {
  bool photos = true,
}) => templateDocumentPages(buildLightboundWeddingDraft(aspect, copy: copy))
    .map(
      (page) => DataTemplateEngine.buildLayersFromJson(page, aspect.canvas)
          .map(
            (layer) => !photos && layer.type == LayerType.image
                ? layer.copyWith(clearImage: true)
                : layer,
          )
          .toList(),
    )
    .toList();

bool lightboundCopyFits(LightboundWeddingCopy copy) {
  for (final aspect in CollectionAspect.values) {
    for (final layer in lightboundPreviewPages(aspect, copy).expand((p) => p)) {
      if (layer.type != LayerType.text) continue;
      final painter = TextPainter(
        text: TextSpan(text: layer.text, style: layer.textStyle),
        textDirection: TextDirection.ltr,
        strutStyle: StrutStyle.fromTextStyle(
          layer.textStyle!,
          forceStrutHeight: true,
        ),
      )..layout(maxWidth: layer.width);
      final fits = painter.height <= layer.height + .5;
      painter.dispose();
      if (!fits) return false;
    }
  }
  return true;
}

class LightboundPreview extends StatelessWidget {
  const LightboundPreview({super.key});
  @override
  Widget build(BuildContext context) =>
      AuthoredDraftPreview<LightboundWeddingCopy>(
        title: lightboundWeddingTitle,
        chapters: lightboundSpreadNames,
        initialCopy: const LightboundWeddingCopy(),
        buildPages: (aspect, copy, photos) =>
            lightboundPreviewPages(aspect, copy, photos: photos),
        copySheet: (copy) => _CopySheet(copy: copy),
      );
}

/// A shared collection workbench; it never publishes or calls AI.
class AuthoredDraftPreview<T> extends StatefulWidget {
  const AuthoredDraftPreview({
    super.key,
    required this.title,
    required this.chapters,
    required this.initialCopy,
    required this.buildPages,
    required this.copySheet,
    this.editionLabel = '무료',
    this.extraControls = const [],
    this.revision,
    this.coverRevision,
    this.pageRequest,
  });
  final String title;
  final List<String> chapters;
  final T initialCopy;
  final List<List<LayerModel>> Function(CollectionAspect, T, bool) buildPages;
  final Widget Function(T) copySheet;
  final String editionLabel;
  final List<Widget> extraControls;
  final Object? revision;
  final Object? coverRevision;
  final ({int page, int serial})? pageRequest;
  @override
  State<AuthoredDraftPreview<T>> createState() =>
      _AuthoredDraftPreviewState<T>();
}

class _AuthoredDraftPreviewState<T> extends State<AuthoredDraftPreview<T>> {
  CollectionAspect _aspect = CollectionAspect.square;
  late T _copy = widget.initialCopy;
  bool _overview = false;
  bool _photos = true;
  int _page = 0;
  int _jumpSerial = 0;
  late List<List<LayerModel>> _pages;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _pages = widget.buildPages(_aspect, _copy, _photos);

  @override
  void didUpdateWidget(covariant AuthoredDraftPreview<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _load();
    if (oldWidget.coverRevision != widget.coverRevision) {
      _page = 0;
      _overview = false;
      _jumpSerial++;
    }
    if (oldWidget.pageRequest != widget.pageRequest &&
        widget.pageRequest != null) {
      _page = widget.pageRequest!.page.clamp(0, _pages.length - 1);
      _overview = false;
      _jumpSerial++;
    }
  }

  void _jumpTo(int index) => setState(() {
    _page = index;
    _overview = false;
    _jumpSerial++;
  });

  Future<void> _edit() async {
    final next = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => widget.copySheet(_copy),
    );
    if (next == null || !mounted) return;
    setState(() {
      _copy = next;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 48,
      excludeHeaderSemantics: true,
      surfaceTintColor: Colors.transparent,
      title: PopupMenuButton<String>(
        tooltip: '시안 선택',
        onSelected: (route) {
          if (route == '/frames' ||
              route == '/materials' ||
              route == '/atelier') {
            Navigator.of(context).pushNamed(route);
          } else {
            Navigator.of(context).pushReplacementNamed(route);
          }
        },
        itemBuilder: (_) => [
          for (final collection in authoredCollections)
            PopupMenuItem(
              value: '/${collection.id}',
              child: Text(collection.title),
            ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: '/luminous-edition',
            child: Text('겹쳐진 순간 · 유료 후보'),
          ),
          const PopupMenuItem(value: '/frames', child: Text('사진 프레임')),
          const PopupMenuItem(value: '/materials', child: Text('종이·스티커')),
          const PopupMenuItem(value: '/atelier', child: Text('소재 스튜디오')),
        ],
        child: Semantics(
          button: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.expand_more_rounded, size: 18),
            ],
          ),
        ),
      ),
      actions: [
        PopupMenuButton<int>(
          tooltip: '목차',
          icon: const Icon(Icons.format_list_bulleted_rounded, size: 22),
          onSelected: _jumpTo,
          itemBuilder: (_) => [
            const PopupMenuItem(value: 0, child: Text('표지')),
            for (var i = 0; i < widget.chapters.length; i++)
              PopupMenuItem(
                value: i * 2 + 1,
                child: Text(
                  '${i * 2 + 1}–${i * 2 + 2} / ${widget.chapters[i]}',
                ),
              ),
          ],
        ),
        IconButton(
          tooltip: '문구 편집',
          onPressed: _edit,
          icon: const Icon(Icons.edit_note_rounded, size: 23),
        ),
        IconButton(
          tooltip: _overview ? '책으로 보기' : '전체 펼침 보기',
          onPressed: () => setState(() => _overview = !_overview),
          icon: Icon(
            _overview ? Icons.auto_stories_outlined : Icons.grid_view_rounded,
            size: 21,
          ),
        ),
        PopupMenuButton<CollectionAspect>(
          tooltip: '앨범 규격',
          initialValue: _aspect,
          icon: const Icon(Icons.aspect_ratio_rounded, size: 22),
          onSelected: (value) => setState(() {
            _aspect = value;
            _load();
          }),
          itemBuilder: (_) => [
            for (final aspect in CollectionAspect.values)
              PopupMenuItem(value: aspect, child: Text(aspect.cover.name)),
          ],
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: _overview
                ? _overviewView()
                : CreationDocumentPreview(
                    key: ValueKey(_jumpSerial),
                    pages: _pages,
                    canvas: _aspect.canvas,
                    initialPage: _page,
                    onPageChanged: (index) => _page = index,
                    preserveTypography: true,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.editionLabel} · 표지 + 내지 ${_pages.length - 1}쪽',
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ...widget.extraControls,
                IconButton(
                  tooltip: _photos ? '샘플 사진 숨기기' : '샘플 사진 보이기',
                  icon: Icon(
                    _photos ? Icons.image_outlined : Icons.hide_image_outlined,
                    size: 20,
                  ),
                  onPressed: () => setState(() {
                    _photos = !_photos;
                    _load();
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _overviewView() => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: LayoutBuilder(
      builder: (context, viewport) {
        final width = math.min(1180.0, viewport.maxWidth - 32);
        final columns = width > 950 ? 2 : 1;
        final spreadWidth = (width - 24 * (columns - 1)) / columns;
        Widget render(int index, double width) => TemplatePageRenderer(
          layers: _pages[index],
          width: width,
          height: width / _aspect.canvas.aspectRatio,
          designCanvasSize: _aspect.canvas,
          preserveTypography: true,
          imageDecodeWidth:
              (math.max(width, width / _aspect.canvas.aspectRatio) *
                      MediaQuery.devicePixelRatioOf(context) *
                      2)
                  .ceil()
                  .clamp(100, 1800),
          showCanvasChrome: false,
        );
        Widget sheet(List<int> indices, String name, double width) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Semantics(
              button: true,
              label: '$name 펼치기',
              child: InkWell(
                onTap: () => _jumpTo(indices.first),
                child: Row(
                  children: [
                    for (final index in indices)
                      render(index, width / indices.length),
                  ],
                ),
              ),
            ),
          ],
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Center(
            child: SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: SizedBox(
                      width: math.min(240, width),
                      child: sheet([0], '표지', math.min(240, width)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Wrap(
                    spacing: 24,
                    runSpacing: 32,
                    children: [
                      for (var i = 0; i < widget.chapters.length; i++)
                        SizedBox(
                          width: spreadWidth,
                          child: sheet(
                            [i * 2 + 1, i * 2 + 2],
                            '${(i + 1).toString().padLeft(2, '0')} / ${widget.chapters[i]}',
                            spreadWidth,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _CopySheet extends StatefulWidget {
  const _CopySheet({required this.copy});
  final LightboundWeddingCopy copy;
  @override
  State<_CopySheet> createState() => _CopySheetState();
}

class _CopySheetState extends State<_CopySheet> {
  final _form = GlobalKey<FormState>();
  late final _first = TextEditingController(text: widget.copy.firstName);
  late final _second = TextEditingController(text: widget.copy.secondName);
  late final _date = TextEditingController(text: widget.copy.date);
  late final _letter = TextEditingController(text: widget.copy.letter);
  String? _error;

  @override
  void dispose() {
    for (final controller in [_first, _second, _date, _letter]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _apply() {
    if (!_form.currentState!.validate()) return;
    final copy = LightboundWeddingCopy(
      firstName: _first.text.trim(),
      secondName: _second.text.trim(),
      date: _date.text.trim(),
      letter: _letter.text.trim(),
    );
    if (!lightboundCopyFits(copy)) {
      setState(() => _error = '문구가 페이지 여백을 넘어요. 글자 수나 줄바꿈을 줄여 주세요.');
      return;
    }
    Navigator.of(context).pop(copy);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: math
          .min(
            650.0,
            MediaQuery.sizeOf(context).height * .90 -
                MediaQuery.viewInsetsOf(context).bottom,
          )
          .clamp(100.0, 650.0)
          .toDouble(),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '앨범 문구',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '문구 적용',
                    onPressed: _apply,
                    icon: const Icon(Icons.check_rounded),
                  ),
                  IconButton(
                    tooltip: '문구 편집 닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Form(
                  key: _form,
                  child: Column(
                    children: [
                      for (final field in [
                        (_first, '첫 번째 이름', 12),
                        (_second, '두 번째 이름', 12),
                        (_date, '기념일', 20),
                      ])
                        TextFormField(
                          controller: field.$1,
                          maxLength: field.$3,
                          decoration: InputDecoration(labelText: field.$2),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? '내용을 입력해 주세요.'
                              : null,
                        ),
                      TextFormField(
                        controller: _letter,
                        minLines: 5,
                        maxLines: 10,
                        maxLength: 220,
                        decoration: const InputDecoration(
                          labelText: '미래의 우리에게',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? '편지를 입력해 주세요.'
                            : null,
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
