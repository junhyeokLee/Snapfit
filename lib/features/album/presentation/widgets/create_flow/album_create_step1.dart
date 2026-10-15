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
  @override
  State<AlbumCreateStep1> createState() => _AlbumCreateStep1State();
}

class _AlbumCreateStep1State extends State<AlbumCreateStep1> {
  late final _title = TextEditingController(text: widget.albumTitle);
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

  @override
  Widget build(BuildContext context) {
    final cover = widget.selectedCover ?? defaultCoverSize;
    final muted = ExperienceFormStyle.muted(context);
    return CreationWorkspace(
      keyboardOpen: creationKeyboardIsOpen(context),
      stage: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _title,
        builder: (context, title, _) {
          final name = title.text.trim().isEmpty ? '나만의 새 앨범' : title.text;
          final pages = widget.documentPages;
          return CreationPaperStage(
            inset: pages != null && pages.isNotEmpty ? 0 : 22,
            title: widget.templateTitle ?? name,
            detail: '${cover.displayName} · ${cover.coverType.label}',
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
          );
        },
      ),
      fields: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '앨범 설정',
                  style: ExperienceFormStyle.text(
                    context,
                    20,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.onChangeDesign != null)
                IconButton(
                  tooltip: '시작 방식 변경',
                  onPressed: widget.onChangeDesign,
                  icon: const Icon(Icons.swap_horiz, size: 21),
                ),
            ],
          ),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                widget.sourceLabel,
                style: ExperienceFormStyle.text(context, 12, secondary: true),
              ),
              if (_awaitingPhotos)
                Text(
                  '사진 추가 전',
                  key: const ValueKey('creation-cover-awaiting-photos'),
                  style: ExperienceFormStyle.text(context, 12, secondary: true),
                ),
            ],
          ),
          const SizedBox(height: 22),
          _label(context, '앨범 제목'),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('creation-album-title'),
            controller: _title,
            onChanged: widget.onTitleChanged,
            maxLength: 50,
            style: ExperienceFormStyle.text(context, 16),
            textInputAction: TextInputAction.done,
            decoration: ExperienceFormStyle.input(
              context,
              hint: '앨범 이름',
            ).copyWith(counterStyle: TextStyle(fontSize: 11, color: muted)),
          ),
          const SizedBox(height: 16),
          _label(context, '책 크기'),
          const SizedBox(height: 12),
          CoverSizePicker(
            selectedCover: widget.selectedCover,
            availableCovers: widget.availableCovers,
            onSelected: widget.onCoverSelected,
          ),
          if ((widget.availableCovers?.length ?? coverSizes.length) <
              coverSizes.length)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '이 디자인에 맞는 크기',
                style: ExperienceFormStyle.text(context, 12, secondary: true),
              ),
            ),
          const SizedBox(height: 24),
          _label(context, '표지 종류'),
          const SizedBox(height: 12),
          PrintCoverTypePicker(
            selected: cover.coverType,
            onSelected: (type) =>
                widget.onCoverSelected(cover.withCoverType(type)),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _label(context, '내지')),
              IconButton(
                tooltip: '페이지 줄이기',
                onPressed:
                    !_tooManyPages && widget.selectedPageCount > _minimumPages
                    ? () => widget.onPageCountChanged(
                        widget.selectedPageCount - AlbumPagePolicy.pageStep,
                      )
                    : null,
                icon: const Icon(Icons.remove, size: 20),
              ),
              SizedBox(
                width: 64,
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
                        widget.selectedPageCount < AlbumPagePolicy.maxInnerPages
                    ? () => widget.onPageCountChanged(
                        widget.selectedPageCount + AlbumPagePolicy.pageStep,
                      )
                    : null,
                icon: const Icon(Icons.add, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _tooManyPages
                ? '이 디자인은 내지 80쪽을 초과해요. 다른 디자인을 선택해주세요.'
                : '표지 별도 · 내지 20~80쪽 · 2쪽 단위',
            style: ExperienceFormStyle.text(context, 12, secondary: true),
          ),
          if (_hasTemplate && !_tooManyPages)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '디자인 ${widget.templatePageCount ?? widget.minPageCount}쪽'
                '${widget.selectedPageCount > (widget.templatePageCount ?? widget.minPageCount) ? ' + 빈 페이지 ${widget.selectedPageCount - (widget.templatePageCount ?? widget.minPageCount)}쪽' : ''}',
                style: ExperienceFormStyle.text(context, 12, secondary: true),
              ),
            ),
          if (widget.onChangeDesign != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.onChangeDesign,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('디자인 변경'),
              ),
            ),
        ],
      ),
      actions: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _title,
        builder: (context, value, _) => SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const ValueKey('creation-setup-next'),
            onPressed:
                value.text.trim().isNotEmpty &&
                    widget.selectedCover != null &&
                    AlbumPagePolicy.isValid(widget.selectedPageCount) &&
                    !_tooManyPages
                ? widget.onNext
                : null,
            style: ExperienceFormStyle.primary(context),
            child: Text(_hasTemplate ? '사진 채우기' : '표지 만들기'),
          ),
        ),
      ),
    );
  }
}
