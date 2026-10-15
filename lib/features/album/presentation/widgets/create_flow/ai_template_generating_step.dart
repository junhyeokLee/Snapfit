import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../core/constants/cover_size.dart';
import 'creation_workspace.dart';

class AiTemplateGeneratingStep extends StatelessWidget {
  const AiTemplateGeneratingStep({super.key, this.cover, this.innerPageCount});
  final CoverSize? cover;
  final int? innerPageCount;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - 48),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: LayoutBuilder(
                builder: (context, box) {
                  final book = CreationPaperStage(
                    title: '디자인 생성 중',
                    detail: innerPageCount == null
                        ? null
                        : '표지 · 내지 $innerPageCount쪽',
                    child: CreationBlankBook(
                      cover: cover ?? defaultCoverSize,
                      title: '새로운 이야기',
                    ),
                  );
                  final status = Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ExperienceFormStyle.selectionInk(context),
                          semanticsLabel: 'AI 템플릿 생성 중',
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'AI 템플릿을 만들고 있어요',
                        textAlign: TextAlign.center,
                        style: ExperienceFormStyle.text(
                          context,
                          20,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '요청한 분위기와 구성을 디자인에 반영하고 있어요.',
                        textAlign: TextAlign.center,
                        style: ExperienceFormStyle.text(
                          context,
                          14,
                          secondary: true,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        '성공 시만 처리. 실패 시 차감 없음.',
                        textAlign: TextAlign.center,
                        style: ExperienceFormStyle.text(
                          context,
                          12,
                          secondary: true,
                        ),
                      ),
                    ],
                  );
                  return MediaQuery.orientationOf(context) ==
                              Orientation.landscape &&
                          box.maxWidth >= 520
                      ? Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: math.max(
                                  120,
                                  constraints.maxHeight - 48,
                                ),
                                child: book,
                              ),
                            ),
                            const SizedBox(width: 32),
                            Expanded(child: status),
                          ],
                        )
                      : Column(
                          children: [
                            SizedBox(
                              height: math.min(280, constraints.maxHeight * .4),
                              child: book,
                            ),
                            const SizedBox(height: 28),
                            status,
                          ],
                        );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
