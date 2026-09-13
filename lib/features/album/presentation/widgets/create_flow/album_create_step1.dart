import 'package:flutter/material.dart';
import '../../../../../core/theme/snapfit_design_tokens.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/layer.dart';
import '../../../../store/presentation/widgets/template_page_renderer.dart';
import 'creation_template_image.dart';
import 'cover_size_picker.dart';
import 'print_cover_type_picker.dart';

class AlbumCreateStep1 extends StatefulWidget {
  final String albumTitle;
  final String? templateTitle;
  final String? templatePreviewImageUrl;
  final String sourceLabel;
  final CoverSize? selectedCover;
  final int selectedPageCount;
  final int minPageCount;
  final List<CoverSize>? availableCovers;
  final List<LayerModel>? coverLayers;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<CoverSize> onCoverSelected;
  final ValueChanged<int> onPageCountChanged;
  final VoidCallback onNext;
  final VoidCallback? onChangeDesign;

  const AlbumCreateStep1({
    super.key,
    required this.albumTitle,
    this.templateTitle,
    this.templatePreviewImageUrl,
    this.sourceLabel = '직접 만들기',
    this.availableCovers,
    this.coverLayers,
    required this.selectedCover,
    required this.selectedPageCount,
    this.minPageCount = 10,
    required this.onTitleChanged,
    required this.onCoverSelected,
    required this.onPageCountChanged,
    required this.onNext,
    this.onChangeDesign,
  });

  @override
  State<AlbumCreateStep1> createState() => _AlbumCreateStep1State();
}

class _AlbumCreateStep1State extends State<AlbumCreateStep1> {
  late final TextEditingController _title = TextEditingController(
    text: widget.albumTitle,
  );

  @override
  void didUpdateWidget(AlbumCreateStep1 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.albumTitle != widget.albumTitle &&
        _title.text != widget.albumTitle) {
      _title.text = widget.albumTitle;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  bool get _hasTemplate => widget.templateTitle?.isNotEmpty ?? false;

  @override
  Widget build(BuildContext context) {
    final ink = SnapFitColors.textPrimaryOf(context);
    final muted = SnapFitColors.textSecondaryOf(context);
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 640;
                      final summary = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '앨범 설정',
                            style: TextStyle(
                              fontSize: 25,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (_hasTemplate) ...[
                                SizedBox(
                                  width: 66,
                                  height: 84,
                                  child: _coverPreview(),
                                ),
                                const SizedBox(width: 16),
                              ] else ...[
                                Icon(
                                  Icons.auto_stories_outlined,
                                  size: 30,
                                  color: muted,
                                ),
                                const SizedBox(width: 16),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.sourceLabel,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: muted,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      widget.templateTitle ?? '나만의 새 앨범',
                                      style: TextStyle(
                                        fontSize: 16,
                                        height: 1.4,
                                        fontWeight: FontWeight.w600,
                                        color: ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.onChangeDesign != null)
                                IconButton(
                                  tooltip: '시작 방식 변경',
                                  onPressed: widget.onChangeDesign,
                                  icon: const Icon(Icons.swap_horiz, size: 23),
                                ),
                            ],
                          ),
                        ],
                      );
                      final fields = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label(context, '앨범 제목'),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _title,
                            onChanged: widget.onTitleChanged,
                            maxLength: 50,
                            style: TextStyle(fontSize: 16, color: ink),
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              hintText: '앨범 이름',
                              counterStyle: TextStyle(
                                fontSize: 11,
                                color: muted,
                              ),
                              filled: true,
                              fillColor: SnapFitColors.surfaceOf(context),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: ink.withValues(alpha: .15),
                                ),
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _label(context, '책 크기'),
                          const SizedBox(height: 12),
                          CoverSizePicker(
                            selectedCover: widget.selectedCover,
                            availableCovers: widget.availableCovers,
                            onSelected: widget.onCoverSelected,
                          ),
                          if ((widget.availableCovers?.length ??
                                  coverSizes.length) <
                              coverSizes.length)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                '이 디자인에 맞는 크기',
                                style: TextStyle(fontSize: 12, color: muted),
                              ),
                            ),
                          const SizedBox(height: 24),
                          _label(context, '표지 종류'),
                          const SizedBox(height: 12),
                          PrintCoverTypePicker(
                            selected:
                                widget.selectedCover?.coverType ??
                                PrintCoverType.soft,
                            onSelected: (type) => widget.onCoverSelected(
                              (widget.selectedCover ?? defaultCoverSize)
                                  .withCoverType(type),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(child: _label(context, '분량')),
                              IconButton(
                                tooltip: '페이지 줄이기',
                                onPressed:
                                    widget.selectedPageCount >
                                        widget.minPageCount
                                    ? () => widget.onPageCountChanged(
                                        widget.selectedPageCount - 1,
                                      )
                                    : null,
                                icon: const Icon(Icons.remove, size: 20),
                              ),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  '${widget.selectedPageCount}쪽',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: ink,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: '페이지 늘리기',
                                onPressed: widget.selectedPageCount < 50
                                    ? () => widget.onPageCountChanged(
                                        widget.selectedPageCount + 1,
                                      )
                                    : null,
                                icon: const Icon(Icons.add, size: 20),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _hasTemplate
                                ? '표지 별도 · 디자인 ${widget.minPageCount}쪽${widget.selectedPageCount > widget.minPageCount ? ' + 빈 페이지 ${widget.selectedPageCount - widget.minPageCount}쪽' : ''}'
                                : '표지 별도 · 최대 50쪽',
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ],
                      );
                      if (wide)
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 4, child: summary),
                            const SizedBox(width: 40),
                            Expanded(flex: 6, child: fields),
                          ],
                        );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [summary, const SizedBox(height: 30), fields],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _title,
                  builder: (context, value, _) => SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed:
                          value.text.trim().isNotEmpty &&
                              widget.selectedCover != null
                          ? widget.onNext
                          : null,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: ink,
                        foregroundColor: SnapFitColors.backgroundOf(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: SnapFitFonts.body,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(_hasTemplate ? '사진 채우기' : '표지 만들기'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Text(
    text,
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: SnapFitColors.textPrimaryOf(context),
    ),
  );

  Widget _coverPreview() {
    final layers = widget.coverLayers;
    final cover = widget.selectedCover;
    if (layers != null && layers.isNotEmpty && cover != null) {
      final canvas = coverCanvasBaseSize(cover);
      return FittedBox(
        child: TemplatePageRenderer(
          layers: layers,
          width: canvas.width,
          height: canvas.height,
          designCanvasSize: canvas,
          showCanvasChrome: true,
        ),
      );
    }
    return CreationTemplateImage(url: widget.templatePreviewImageUrl ?? '');
  }
}
