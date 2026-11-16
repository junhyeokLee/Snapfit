import 'package:flutter/material.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/album_page_policy.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../domain/entities/layer.dart';
import '../../../../store/presentation/widgets/template_page_renderer.dart';
import '../../../../store/presentation/widgets/template_book_artwork.dart';
import 'creation_template_image.dart';
import 'creation_document_preview.dart';
import 'creation_workspace.dart';
import 'cover_size_picker.dart';
import 'print_cover_type_picker.dart';
import '../../../../../shared/widgets/experience_icon.dart';

class AlbumCreateStep1 extends StatefulWidget {
  const AlbumCreateStep1({
    super.key,
    required this.albumTitle,
    this.templateTitle,
    this.templatePreviewImageUrl,
    this.sourceLabel = '직접 만들기',
    this.availableCovers,
    this.coverLayers,
    this.documentPages,
    this.preserveTypography = false,
    required this.selectedCover,
    required this.selectedPageCount,
    this.minPageCount = AlbumPagePolicy.minInnerPages,
    this.templatePageCount,
    required this.onTitleChanged,
    required this.onCoverSelected,
    required this.onPageCountChanged,
    required this.onNext,
    this.onChangeDesign,
    this.onEditCoverText,
    this.isPreparing = false,
  });
  final String albumTitle, sourceLabel;
  final String? templateTitle, templatePreviewImageUrl;
  final CoverSize? selectedCover;
  final int selectedPageCount, minPageCount;
  final int? templatePageCount;
  final List<CoverSize>? availableCovers;
  final List<LayerModel>? coverLayers;
  final List<List<LayerModel>>? documentPages;
  final bool preserveTypography;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<CoverSize> onCoverSelected;
  final ValueChanged<int> onPageCountChanged;
  final VoidCallback onNext;
  final VoidCallback? onChangeDesign;
  final VoidCallback? onEditCoverText;
  final bool isPreparing;
  @override
  State<AlbumCreateStep1> createState() => _AlbumCreateStep1State();
}

class _AlbumCreateStep1State extends State<AlbumCreateStep1> {
  late final _title = TextEditingController(text: widget.albumTitle);
  late String? _expandedSection = widget.albumTitle.trim().isEmpty
      ? 'name'
      : 'book';
  final _titleFocus = FocusNode();
  final _sectionKeys = <String, GlobalKey>{
    'name': GlobalKey(),
    'book': GlobalKey(),
    'pages': GlobalKey(),
  };

  void _toggleSection(String section) {
    // Hidden text fields must not retain the keyboard or accept input.
    if (_expandedSection == 'name') _titleFocus.unfocus();
    setState(
      () => _expandedSection = _expandedSection == section ? null : section,
    );
    if (_expandedSection == section) {
      // Closing the previous section changes the header's scroll position.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _sectionKeys[section]?.currentContext;
        if (!mounted || target == null) return;
        Scrollable.ensureVisible(
          target,
          alignment: 0,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      });
    }
  }

  bool get _hasTemplate => widget.templateTitle?.isNotEmpty ?? false;
  bool get _awaitingPhotos =>
      _hasTemplate &&
      !(widget.coverLayers?.any(
            (layer) => layer.type == LayerType.image && layer.hasImageSource,
          ) ??
          false);
  int get _minimumPages =>
      AlbumPagePolicy.minimumForContent(widget.minPageCount);
  bool get _tooManyPages => _minimumPages > AlbumPagePolicy.maxInnerPages;
  @override
  void didUpdateWidget(AlbumCreateStep1 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.albumTitle != widget.albumTitle &&
        _title.text != widget.albumTitle)
      _title.text = widget.albumTitle;
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    _title.dispose();
    super.dispose();
  }

  Widget _label(BuildContext context, String value) => Text(
    value,
    style: ExperienceFormStyle.text(context, 14, weight: FontWeight.w600),
  );
  Widget _coverPreview(CoverSize cover, String name) {
    final layers = widget.coverLayers;
    final canvas = coverCanvasBaseSize(cover);
    if (layers != null && layers.isNotEmpty)
      return TemplateBookArtwork(
        canvas: canvas,
        firstPage: 0,
        paired: false,
        pageBuilder: (index, wrap) => FittedBox(
          child: TemplatePageRenderer(
            layers: layers,
            width: canvas.width,
            height: canvas.height,
            designCanvasSize: canvas,
            preserveTypography: widget.preserveTypography,
            showCanvasChrome: false,
            wrapSpineArtwork: wrap,
            cacheNetworkImages: true,
            imageDecodeWidth: 800,
          ),
        ),
      );
    if (_hasTemplate && widget.templatePreviewImageUrl?.isNotEmpty == true) {
      return AspectRatio(
        aspectRatio: cover.ratio,
        child: CreationTemplateImage(url: widget.templatePreviewImageUrl!),
      );
    }
    return CreationBlankBook(cover: cover, title: name);
  }

  /// Offstage preserves the input and preview state without exposing hidden controls.
  Widget _section({
    required String id,
    required String title,
    required Widget summary,
    required Widget child,
  }) {
    final expanded = _expandedSection == id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        shape: Border(
          bottom: BorderSide(color: ExperienceFormStyle.line(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              key: _sectionKeys[id],
              button: true,
              expanded: expanded,
              child: InkWell(
                key: ValueKey('creation-settings-$id-toggle'),
                onTap: () => _toggleSection(id),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: ExperienceFormStyle.text(
                                  context,
                                  17,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              if (!expanded) ...[
                                const SizedBox(height: 5),
                                DefaultTextStyle(
                                  style: ExperienceFormStyle.text(
                                    context,
                                    14,
                                    secondary: true,
                                  ),
                                  child: summary,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: ExperienceFormStyle.muted(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Offstage(
              offstage: !expanded,
              child: ExcludeFocus(
                excluding: !expanded,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cover = widget.selectedCover ?? defaultCoverSize;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
    return CreationWorkspace(
      compactForm: true,
      portraitStageHeight: largeText ? 292 : 232,
      keyboardOpen: creationKeyboardIsOpen(context),
      stage: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _title,
        builder: (context, title, _) {
          final name = title.text.trim().isEmpty ? '나만의 새 앨범' : title.text;
          final pages = widget.documentPages;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.templateTitle ?? '빈 앨범 미리보기',
                        style: ExperienceFormStyle.text(
                          context,
                          12,
                          secondary: true,
                        ),
                      ),
                    ),
                    if (widget.onChangeDesign != null)
                      TextButton(
                        key: const ValueKey('creation-change-design'),
                        onPressed: widget.onChangeDesign,
                        child: Text(
                          '디자인 변경',
                          style: ExperienceFormStyle.text(
                            context,
                            13,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: CreationPaperStage(
                  inset: pages != null && pages.isNotEmpty ? 0 : 12,
                  child: pages != null && pages.isNotEmpty
                      ? CreationDocumentPreview(
                          pages: pages,
                          canvas: coverCanvasBaseSize(cover),
                          showBookMaterial: true,
                          preserveTypography: widget.preserveTypography,
                          showThumbnails: false,
                          spreadInLandscape: true,
                          pageKeyPrefix: 'creation-setup-page-',
                        )
                      : _coverPreview(cover, name),
                ),
              ),
              if (_awaitingPhotos)
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 8),
                  child: Text(
                    '사진 추가 전',
                    key: const ValueKey('creation-cover-awaiting-photos'),
                    textAlign: TextAlign.center,
                    style: ExperienceFormStyle.text(
                      context,
                      12,
                      secondary: true,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      fields: Semantics(
        key: const ValueKey('creation-selection-summary'),
        container: true,
        liveRegion: true,
        label:
            '${widget.sourceLabel} 선택. '
            '${widget.selectedCover == null ? '책 크기를 선택해주세요' : '${cover.displayName}, ${cover.coverType.label} 선택됨'}. '
            '내지 ${widget.selectedPageCount}쪽.'
            '${_awaitingPhotos ? ' 사진 추가 전.' : ''}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _section(
              id: 'name',
              title: '책장 이름',
              summary: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _title,
                builder: (context, value, _) => Text(
                  value.text.trim().isEmpty ? '책장에 표시할 이름을 입력해주세요' : value.text,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '책장에 표시할 이름',
                    style: ExperienceFormStyle.text(
                      context,
                      12.5,
                      secondary: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('creation-album-title'),
                    controller: _title,
                    focusNode: _titleFocus,
                    onChanged: widget.onTitleChanged,
                    maxLength: 50,
                    style: ExperienceFormStyle.text(context, 16),
                    textInputAction: TextInputAction.done,
                    decoration:
                        ExperienceFormStyle.input(
                          context,
                          hint: '예: 2026 제주 여행',
                        ).copyWith(
                          counterStyle: TextStyle(
                            fontSize: 11,
                            color: ExperienceFormStyle.muted(context),
                          ),
                        ),
                  ),
                  if (widget.onEditCoverText != null &&
                      widget.coverLayers?.any(
                            (layer) => layer.type == LayerType.text,
                          ) ==
                          true) ...[
                    Text(
                      '표지의 글은 따로 바꿀 수 있어요.',
                      style: ExperienceFormStyle.text(
                        context,
                        12.5,
                        secondary: true,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const ValueKey('creation-cover-copy-edit'),
                        onPressed: widget.onEditCoverText,
                        icon: const ExperienceIcon('PenLine', size: 17),
                        label: const Text('표지 문구 수정'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _section(
              id: 'book',
              title: '책 크기 · 커버',
              summary: Text(
                widget.selectedCover == null
                    ? '책 크기를 선택해주세요'
                    : '${cover.displayName} · ${cover.coverType.label}',
                key: const ValueKey('creation-selected-settings'),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _label(context, '책 크기'),
                  const SizedBox(height: 8),
                  CoverSizePicker(
                    compact: true,
                    selectedCover: widget.selectedCover,
                    availableCovers: widget.availableCovers,
                    onSelected: widget.onCoverSelected,
                  ),
                  if ((widget.availableCovers?.length ?? coverSizes.length) <
                      coverSizes.length)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '이 디자인에 맞는 크기',
                        style: ExperienceFormStyle.text(
                          context,
                          12,
                          secondary: true,
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _label(context, '커버 종류'),
                      Text(
                        '앨범 주문 시 적용',
                        style: ExperienceFormStyle.text(
                          context,
                          12,
                          secondary: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  PrintCoverTypePicker(
                    selected: cover.coverType,
                    onSelected: (type) =>
                        widget.onCoverSelected(cover.withCoverType(type)),
                  ),
                ],
              ),
            ),
            _section(
              id: 'pages',
              title: '내지',
              summary: Text(
                _tooManyPages
                    ? '${widget.selectedPageCount}쪽 · 주문 가능한 80쪽 초과'
                    : '${widget.selectedPageCount}쪽 · 표지 별도',
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _label(context, '내지 쪽수')),
                      IconButton(
                        tooltip: '페이지 줄이기',
                        onPressed:
                            !_tooManyPages &&
                                widget.selectedPageCount > _minimumPages
                            ? () => widget.onPageCountChanged(
                                widget.selectedPageCount -
                                    AlbumPagePolicy.pageStep,
                              )
                            : null,
                        icon: const Icon(Icons.remove, size: 20),
                      ),
                      Flexible(
                        child: Text(
                          '${widget.selectedPageCount}쪽',
                          textAlign: TextAlign.center,
                          style: ExperienceFormStyle.text(
                            context,
                            17,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '페이지 늘리기',
                        onPressed:
                            !_tooManyPages &&
                                widget.selectedPageCount <
                                    AlbumPagePolicy.maxInnerPages
                            ? () => widget.onPageCountChanged(
                                widget.selectedPageCount +
                                    AlbumPagePolicy.pageStep,
                              )
                            : null,
                        icon: const ExperienceIcon('Plus', size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '표지 별도 · 내지 20~80쪽 · 2쪽 단위',
                    style: ExperienceFormStyle.text(
                      context,
                      12.5,
                      secondary: true,
                    ),
                  ),
                  if (_hasTemplate && !_tooManyPages)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '디자인 ${widget.templatePageCount ?? widget.minPageCount}쪽'
                        '${widget.selectedPageCount > (widget.templatePageCount ?? widget.minPageCount) ? ' + 빈 페이지 ${widget.selectedPageCount - (widget.templatePageCount ?? widget.minPageCount)}쪽' : ''}',
                        style: ExperienceFormStyle.text(
                          context,
                          12.5,
                          secondary: true,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _title,
        builder: (context, value, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_tooManyPages)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '이 디자인은 내지 80쪽을 초과해요. 다른 디자인을 선택해주세요.',
                  key: const ValueKey('creation-settings-page-limit'),
                  style: ExperienceFormStyle.text(context, 12.5),
                ),
              ),
            ElevatedButton(
              key: const ValueKey('creation-setup-next'),
              onPressed:
                  !widget.isPreparing &&
                      value.text.trim().isNotEmpty &&
                      widget.selectedCover != null &&
                      AlbumPagePolicy.isValid(widget.selectedPageCount) &&
                      !_tooManyPages
                  ? widget.onNext
                  : null,
              style: CreationStyle.primary(context),
              child: Text(widget.isPreparing ? '앨범을 준비하고 있어요' : '앨범 편집하기'),
            ),
          ],
        ),
      ),
    );
  }
}
