import 'package:flutter/material.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/constants/cover_size.dart';
import 'cover_size_picker.dart';
import 'print_cover_type_picker.dart';
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
    _pageCount = widget.initialBrief?.pageCount ?? 8;
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foreground = SnapFitColors.textPrimaryOf(context);
    return ColoredBox(
      color: SnapFitColors.isDark(context)
          ? const Color(0xFF111111)
          : const Color(0xFFF5F6F4),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: widget.onBack,
                        tooltip: '이전',
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '어떤 앨범을 만들까요?',
                        style: TextStyle(
                          fontSize: 26,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                          color: foreground,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        key: const Key('ai_template_brief'),
                        controller: _prompt,
                        minLines: 4,
                        maxLines: 7,
                        maxLength: 1000,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: foreground,
                        ),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: '원하는 분위기',
                          hintText: '제주 바다의 짙은 초록, 넓은 여백, 풍경은 크게. 글은 짧게.',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: _prompts.entries
                            .map(
                              (entry) => ActionChip(
                                label: Text(entry.key),
                                onPressed: () => setState(() {
                                  _prompt.text = entry.value;
                                }),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        '책 크기',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: foreground,
                        ),
                      ),
                      const SizedBox(height: 12),
                      CoverSizePicker(
                        selectedCover: _cover,
                        onSelected: (cover) => setState(() => _cover = cover),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '표지 종류',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: foreground,
                        ),
                      ),
                      const SizedBox(height: 12),
                      PrintCoverTypePicker(
                        selected: _cover.coverType,
                        onSelected: (type) =>
                            setState(() => _cover = _cover.withCoverType(type)),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '내지',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: foreground,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '2쪽 줄이기',
                            onPressed: _pageCount > 4
                                ? () => setState(() => _pageCount -= 2)
                                : null,
                            icon: const Icon(Icons.remove_rounded),
                          ),
                          SizedBox(
                            width: 48,
                            child: Text(
                              '$_pageCount쪽',
                              textAlign: TextAlign.center,
                            ),
                          ),
                          IconButton(
                            tooltip: '2쪽 늘리기',
                            onPressed: _pageCount < 16
                                ? () => setState(() => _pageCount += 2)
                                : null,
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          key: const Key('ai_template_brief_continue'),
                          onPressed: _prompt.text.trim().isEmpty
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
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF203D35),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            '디자인 요청하기',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
