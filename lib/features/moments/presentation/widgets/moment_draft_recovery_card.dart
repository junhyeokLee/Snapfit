import 'package:flutter/material.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../../social/presentation/widgets/social_widgets.dart';
import '../../domain/moment_draft.dart';

class MomentDraftRecoveryCard extends StatelessWidget {
  const MomentDraftRecoveryCard({
    super.key,
    required this.drafts,
    required this.onResume,
  });
  final List<MomentDraftSummary> drafts;
  final ValueChanged<MomentDraftSummary> onResume;

  Future<void> _choose(BuildContext context) async {
    final selected = await showModalBottomSheet<MomentDraftSummary>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '이 기기에 보관한 기록',
                  style: ExperienceFormStyle.text(
                    context,
                    19,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              for (final draft in drafts)
                ListTile(
                  leading: const Icon(Icons.edit_note_rounded),
                  title: Text(
                    draft.caption.trim().isEmpty
                        ? '${draft.recordDate.month}월 ${draft.recordDate.day}일의 순간'
                        : draft.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${draft.photoCount}장 · '
                    '${draft.isEditing ? '수정하던 기록' : '새 기록'}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(context, draft),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && context.mounted) onResume(selected);
  }

  @override
  Widget build(BuildContext context) {
    if (drafts.isEmpty) return const SizedBox.shrink();
    final draft = drafts.first;
    return Material(
      color: SocialStyle.paper(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: SocialStyle.line(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const ValueKey('moments-resume-draft'),
            onTap: () => onResume(draft),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 76,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: SocialStyle.accent(context).withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.edit_note_rounded,
                      color: SocialStyle.accent(context),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '남기던 순간 이어 쓰기',
                          style: ExperienceFormStyle.text(
                            context,
                            16,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '사진과 글을 이 기기에 보관했어요.\n'
                          '${draft.recordDate.month}월 ${draft.recordDate.day}일 · '
                          '${draft.photoCount}장',
                          style: ExperienceFormStyle.text(
                            context,
                            12,
                            secondary: true,
                          ).copyWith(height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: SocialStyle.accent(context),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (drafts.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextButton(
                key: const ValueKey('moments-all-drafts'),
                onPressed: () => _choose(context),
                child: Text('다른 임시 기록 ${drafts.length - 1}개 보기'),
              ),
            ),
        ],
      ),
    );
  }
}
