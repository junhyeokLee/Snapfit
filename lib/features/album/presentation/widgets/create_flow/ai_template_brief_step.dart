import 'package:flutter/material.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/album_page_policy.dart';
import 'cover_size_picker.dart';
import 'print_cover_type_picker.dart';
import 'creation_workspace.dart';
import '../../../ai_album/domain/ai_album_models.dart';

class AiTemplateBriefStep extends StatefulWidget {
  const AiTemplateBriefStep({
    super.key,
    this.initialBrief,
    this.initialCoverSize,
    required this.onContinue,
    required this.onBack,
    this.onChanged,
  });
  final AiTemplateBrief? initialBrief;
  final CoverSize? initialCoverSize;
  final ValueChanged<AiTemplateBrief> onContinue;
  final VoidCallback onBack;
  final ValueChanged<AiTemplateBrief>? onChanged;
  @override
  State<AiTemplateBriefStep> createState() => _AiTemplateBriefStepState();
}

class _AiTemplateBriefStepState extends State<AiTemplateBriefStep> {
  late final TextEditingController _prompt;
  late CoverSize _cover;
  late int _pageCount;
  late AiTemplateSafeOptions _options;
  @override
  void initState() {
    super.initState();
    _prompt = TextEditingController(text: widget.initialBrief?.prompt ?? '');
    _options =
        widget.initialBrief?.safeOptions ?? const AiTemplateSafeOptions();
    _cover = newAlbumCoverSize(
      widget.initialBrief?.coverSize ?? widget.initialCoverSize,
    );
    _pageCount = AlbumPagePolicy.normalize(
      widget.initialBrief?.pageCount ?? AlbumPagePolicy.minInnerPages,
    );
    _prompt.addListener(_remember);
  }

  AiTemplateBrief get _brief => AiTemplateBrief(
    prompt: _prompt.text,
    pageCount: _pageCount,
    aspect: _cover.ratio > 1
        ? AiTemplateAspect.landscape
        : AiTemplateAspect.square,
    printProductId: _cover.productId,
    safeOptions: _options,
  );

  void _remember() => widget.onChanged?.call(_brief);

  void _changeFormat(VoidCallback update) {
    setState(update);
    _remember();
  }

  @override
  void dispose() {
    _prompt.removeListener(_remember);
    _prompt.dispose();
    super.dispose();
  }

  Widget _choice<T extends Enum>(
    String label,
    T selected,
    Map<T, String> choices,
    void Function(T) update,
  ) => DropdownButtonFormField<T>(
    key: ValueKey('ai-safe-${selected.runtimeType}'),
    initialValue: selected,
    isExpanded: true,
    decoration: ExperienceFormStyle.input(context).copyWith(labelText: label),
    items: [
      for (final entry in choices.entries)
        DropdownMenuItem(
          value: entry.key,
          child: Text(
            entry.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
    onChanged: (value) {
      if (value != null) _changeFormat(() => update(value));
    },
  );

  Widget _label(BuildContext context, String value) => Text(
    value,
    style: ExperienceFormStyle.text(context, 14, weight: FontWeight.w600),
  );
  @override
  Widget build(BuildContext context) => CreationWorkspace(
    keyboardOpen: creationKeyboardIsOpen(context),
    stage: CreationPaperStage(
      title: '디자인 생성 전',
      detail:
          '${_cover.displayName} · ${_cover.coverType.label} · 내지 $_pageCount쪽',
      child: CreationBlankBook(cover: _cover, title: '새로운 이야기'),
    ),
    portraitStageHeight: 232,
    fields: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF14AAA8), Color(0xFF7B6CF5)],
              ).createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: Text(
                'AI 템플릿',
                style: ExperienceFormStyle.text(
                  context,
                  20,
                  weight: FontWeight.w700,
                ).copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '✦',
              style: TextStyle(
                fontSize: 12,
                color: SnapFitColors.accent,
                height: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          key: const Key('ai_template_brief'),
          controller: _prompt,
          minLines: creationKeyboardIsOpen(context) ? 1 : 3,
          maxLines: creationKeyboardIsOpen(context) ? 2 : 7,
          maxLength: 1000,
          style: ExperienceFormStyle.text(context, 15),
          decoration: ExperienceFormStyle.input(
            context,
            hint: '나중에 직접 넣을 문구나 기억하고 싶은 내용을 적어 두세요.',
          ).copyWith(labelText: '개인 메모 · 기기에만 보관', alignLabelWithHint: true),
        ),
        const SizedBox(height: 8),
        Text(
          '이 메모와 사진은 AI에 보내지 않아요. 아래에서 고른 디자인 선호만 사용하며, 생성 후 문구를 직접 바꿀 수 있어요.',
          style: ExperienceFormStyle.text(context, 12, secondary: true),
        ),
        const SizedBox(height: 20),
        _choice<AiDesignTopic>('앨범 주제', _options.topic, const {
          AiDesignTopic.travel: '여행',
          AiDesignTopic.family: '가족',
          AiDesignTopic.baby: '성장',
          AiDesignTopic.couple: '두 사람',
          AiDesignTopic.friends: '친구',
          AiDesignTopic.daily: '일상',
          AiDesignTopic.celebration: '기념과 축하',
        }, (value) => _options = _options.copyWith(topic: value)),
        const SizedBox(height: 16),
        _choice<AiDesignMood>('분위기', _options.mood, const {
          AiDesignMood.editorial: '에디토리얼',
          AiDesignMood.warm: '따뜻하게',
          AiDesignMood.minimal: '간결하게',
          AiDesignMood.playful: '경쾌하게',
          AiDesignMood.elegant: '차분하고 우아하게',
        }, (value) => _options = _options.copyWith(mood: value)),
        const SizedBox(height: 16),
        _choice<AiDesignPalette>('색감', _options.palette, const {
          AiDesignPalette.neutral: '중성색',
          AiDesignPalette.warm: '따뜻한 색',
          AiDesignPalette.cool: '시원한 색',
          AiDesignPalette.pastel: '파스텔',
          AiDesignPalette.vivid: '선명한 색',
        }, (value) => _options = _options.copyWith(palette: value)),
        const SizedBox(height: 16),
        _choice<AiDesignDensity>('구성', _options.density, const {
          AiDesignDensity.quiet: '여백을 넉넉하게',
          AiDesignDensity.balanced: '균형 있게',
          AiDesignDensity.layered: '겹침을 풍성하게',
        }, (value) => _options = _options.copyWith(density: value)),
        const SizedBox(height: 24),
        _label(context, '책 크기'),
        const SizedBox(height: 12),
        CoverSizePicker(
          selectedCover: _cover,
          onSelected: (cover) => _changeFormat(() => _cover = cover),
        ),
        const SizedBox(height: 24),
        _label(context, '표지 종류'),
        const SizedBox(height: 12),
        PrintCoverTypePicker(
          selected: _cover.coverType,
          onSelected: (type) =>
              _changeFormat(() => _cover = _cover.withCoverType(type)),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _label(context, '내지')),
            IconButton(
              tooltip: '2쪽 줄이기',
              onPressed: _pageCount > AlbumPagePolicy.minInnerPages
                  ? () => _changeFormat(
                      () => _pageCount -= AlbumPagePolicy.pageStep,
                    )
                  : null,
              icon: const Icon(Icons.remove, size: 20),
            ),
            SizedBox(
              width: 64,
              child: Text(
                '$_pageCount쪽',
                textAlign: TextAlign.center,
                style: ExperienceFormStyle.text(
                  context,
                  15,
                  weight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: '2쪽 늘리기',
              onPressed: _pageCount < AlbumPagePolicy.maxInnerPages
                  ? () => _changeFormat(
                      () => _pageCount += AlbumPagePolicy.pageStep,
                    )
                  : null,
              icon: const Icon(Icons.add, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '내지는 20~80쪽, 2쪽 단위로 선택할 수 있어요.',
          style: ExperienceFormStyle.text(context, 12, secondary: true),
        ),
      ],
    ),
    actions: Row(
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            tooltip: '이전',
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back, size: 21),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _prompt,
            builder: (context, value, _) => FilledButton(
              key: const Key('ai_template_brief_continue'),
              onPressed: () => widget.onContinue(_brief),
              style: CreationStyle.primary(context),
              child: const Text('디자인 요청하기'),
            ),
          ),
        ),
      ],
    ),
  );
}
