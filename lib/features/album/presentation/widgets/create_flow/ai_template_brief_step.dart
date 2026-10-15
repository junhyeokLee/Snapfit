import 'package:flutter/material.dart';
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
  });
  final AiTemplateBrief? initialBrief;
  final CoverSize? initialCoverSize;
  final ValueChanged<AiTemplateBrief> onContinue;
  final VoidCallback onBack;
  @override
  State<AiTemplateBriefStep> createState() => _AiTemplateBriefStepState();
}

class _AiTemplateBriefStepState extends State<AiTemplateBriefStep> {
  late final TextEditingController _prompt;
  late CoverSize _cover;
  late int _pageCount;
  static const _prompts = {
    '여행': '제주 바다 여행을 담을 앨범. 흰 여백에 짙은 초록을 포인트로, 풍경은 크게, 작은 장면은 리듬감 있게. 글은 짧게.',
    '기념일': '우리의 기념일을 위한 앨범. 차분한 회색과 버건디 포인트, 영화의 장면처럼 넓은 사진과 절제된 타이포그래피.',
    '일상': '산책과 일상을 담을 작은 사진집. 밝고 정갈한 여백, 선명한 파랑 포인트, 크기가 다른 사진이 자연스럽게 이어지게.',
  };
  @override
  void initState() {
    super.initState();
    _prompt = TextEditingController(text: widget.initialBrief?.prompt ?? '');
    _cover = newAlbumCoverSize(
      widget.initialCoverSize ?? widget.initialBrief?.coverSize,
    );
    _pageCount = AlbumPagePolicy.normalize(
      widget.initialBrief?.pageCount ?? AlbumPagePolicy.minInnerPages,
    );
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

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
    fields: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'AI 템플릿',
          style: ExperienceFormStyle.text(context, 20, weight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        TextField(
          key: const Key('ai_template_brief'),
          controller: _prompt,
          minLines: creationKeyboardIsOpen(context) ? 1 : 4,
          maxLines: creationKeyboardIsOpen(context) ? 2 : 7,
          maxLength: 1000,
          style: ExperienceFormStyle.text(context, 15),
          decoration: ExperienceFormStyle.input(
            context,
            hint: '제주 바다의 짙은 초록, 넓은 여백, 풍경은 크게. 글은 짧게.',
          ).copyWith(labelText: '원하는 분위기', alignLabelWithHint: true),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in _prompts.entries)
              ActionChip(
                label: Text(entry.key),
                labelStyle: ExperienceFormStyle.text(context, 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                side: BorderSide(color: ExperienceFormStyle.line(context)),
                onPressed: () => _prompt.text = entry.value,
              ),
          ],
        ),
        const SizedBox(height: 24),
        _label(context, '책 크기'),
        const SizedBox(height: 12),
        CoverSizePicker(
          selectedCover: _cover,
          onSelected: (cover) => setState(() => _cover = cover),
        ),
        const SizedBox(height: 24),
        _label(context, '표지 종류'),
        const SizedBox(height: 12),
        PrintCoverTypePicker(
          selected: _cover.coverType,
          onSelected: (type) =>
              setState(() => _cover = _cover.withCoverType(type)),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _label(context, '내지')),
            IconButton(
              tooltip: '2쪽 줄이기',
              onPressed: _pageCount > AlbumPagePolicy.minInnerPages
                  ? () => setState(() => _pageCount -= AlbumPagePolicy.pageStep)
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
                  ? () => setState(() => _pageCount += AlbumPagePolicy.pageStep)
                  : null,
              icon: const Icon(Icons.add, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '내지는 20~80쪽, 2쪽 단위로 선택할 수 있어요.\n'
          'AI가 최대 16쪽의 디자인을 만들고, 선택한 쪽수에 맞춰 '
          '중간 페이지의 디자인을 재사용해요. 사진과 글은 페이지마다 편집할 수 있어요.',
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
              onPressed: value.text.trim().isEmpty
                  ? null
                  : () => widget.onContinue(
                      AiTemplateBrief(
                        prompt: _prompt.text.trim(),
                        pageCount: _pageCount,
                        aspect: _cover.ratio > 1
                            ? AiTemplateAspect.landscape
                            : AiTemplateAspect.square,
                        printProductId: _cover.productId,
                      ),
                    ),
              style: ExperienceFormStyle.primary(context),
              child: const Text('디자인 요청하기'),
            ),
          ),
        ),
      ],
    ),
  );
}
