import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../domain/social_models.dart';
import 'social_widgets.dart';
import '../../../../shared/widgets/experience_icon.dart';

/// Matches the server's ASCII handle boundaries while preserving the suffix
/// when a user chooses a suggestion with the caret inside an existing token.
({String query, TextRange range})? socialMentionToken(TextEditingValue value) {
  final selection = value.selection;
  if (!selection.isValid ||
      !selection.isCollapsed ||
      selection.baseOffset > value.text.length) {
    return null;
  }
  final before = value.text.substring(0, selection.baseOffset);
  final match = RegExp(
    r'(?:^|[^A-Za-z0-9._@])@([A-Za-z0-9._]{0,24})$',
  ).firstMatch(before);
  if (match == null) return null;
  final suffix = RegExp(
    r'^[A-Za-z0-9._]*',
  ).stringMatch(value.text.substring(selection.baseOffset))!;
  return (
    query: match.group(1)!.toLowerCase(),
    range: TextRange(
      start: before.lastIndexOf('@'),
      end: selection.baseOffset + suffix.length,
    ),
  );
}

/// Keeps a conversation together even when its root arrives on an older page.
/// An unavailable root never produces a made-up comment or author.
List<SocialComment> socialThreadedComments(Iterable<SocialComment> comments) {
  final ordered = comments.toList()
    ..sort((a, b) {
      final byTime = a.createdAt.compareTo(b.createdAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
  final byId = {for (final comment in ordered) comment.id: comment};
  final groups = <String, List<SocialComment>>{};
  for (final comment in ordered) {
    final root = comment.rootCommentId ?? comment.parentCommentId ?? comment.id;
    groups.putIfAbsent(root, () => []).add(comment);
  }
  final entries = groups.entries.toList()
    ..sort((a, b) {
      final left = byId[a.key]?.createdAt ?? a.value.first.createdAt;
      final right = byId[b.key]?.createdAt ?? b.value.first.createdAt;
      final byTime = left.compareTo(right);
      return byTime != 0 ? byTime : a.key.compareTo(b.key);
    });
  return [
    for (final group in entries) ...[
      if (byId[group.key] case final root?) root,
      for (final reply in group.value)
        if (reply.id != group.key) reply,
    ],
  ];
}

String socialCommentTime(DateTime at, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(at);
  if (elapsed.inMinutes < 1) return '방금';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}분 전';
  if (elapsed.inDays < 1) return '${elapsed.inHours}시간 전';
  if (elapsed.inDays < 7) return '${elapsed.inDays}일 전';
  return '${at.year}.${at.month.toString().padLeft(2, '0')}.${at.day.toString().padLeft(2, '0')}';
}

class SocialCommentAvatar extends StatelessWidget {
  const SocialCommentAvatar({
    super.key,
    required this.profile,
    this.size = 36,
    this.onTap,
  });

  final SocialProfile profile;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: SocialStyle.paper(context),
      child: Center(
        child: Text(
          profile.displayName.characters.firstOrNull ?? 's',
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: size * .38,
            fontWeight: FontWeight.w600,
            color: SocialStyle.accent(context),
          ),
        ),
      ),
    );
    return Semantics(
      button: onTap != null,
      label: '${profile.displayName} 프로필 보기',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: size + 8,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: ClipOval(
              child: ExcludeSemantics(
                child: profile.avatarUrl?.isNotEmpty == true
                    ? Image.network(
                        profile.avatarUrl!,
                        fit: BoxFit.cover,
                        cacheWidth: 120,
                        errorBuilder: (_, _, _) => fallback,
                      )
                    : fallback,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Only server-resolved public handles become links; ordinary @text stays text.
class SocialCommentBody extends StatefulWidget {
  const SocialCommentBody({
    super.key,
    required this.comment,
    required this.onProfile,
  });

  final SocialComment comment;
  final ValueChanged<SocialProfile> onProfile;

  @override
  State<SocialCommentBody> createState() => _SocialCommentBodyState();
}

class _SocialCommentBodyState extends State<SocialCommentBody> {
  final _recognizers = <TapGestureRecognizer>[];

  void _clearRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();
    final text = widget.comment.body;
    final profiles = {
      for (final profile in widget.comment.mentions)
        profile.handle.toLowerCase(): profile,
    };
    final spans = <InlineSpan>[];
    var from = 0;
    for (final token in RegExp(r'@[A-Za-z0-9._]{3,24}').allMatches(text)) {
      final before = token.start == 0 ? '' : text[token.start - 1];
      final after = token.end == text.length ? '' : text[token.end];
      if (RegExp(r'[A-Za-z0-9._@]').hasMatch(before) ||
          RegExp(r'[A-Za-z0-9._]').hasMatch(after)) {
        continue;
      }
      final profile = profiles[token.group(0)!.substring(1).toLowerCase()];
      if (profile == null) continue;
      if (token.start > from) {
        spans.add(TextSpan(text: text.substring(from, token.start)));
      }
      final recognizer = TapGestureRecognizer()
        ..onTap = () => widget.onProfile(profile);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: token.group(0),
          recognizer: recognizer,
          style: TextStyle(
            color: SocialStyle.accent(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      from = token.end;
    }
    if (from < text.length) spans.add(TextSpan(text: text.substring(from)));
    return Text.rich(
      TextSpan(children: spans),
      style: TextStyle(
        fontSize: 14,
        height: 1.65,
        color: SocialStyle.ink(context),
      ),
    );
  }
}

class SocialCommentTile extends StatelessWidget {
  const SocialCommentTile({
    super.key,
    required this.comment,
    required this.workAuthorId,
    required this.onProfile,
    required this.onReply,
    required this.action,
  });

  final SocialComment comment;
  final String workAuthorId;
  final ValueChanged<SocialProfile> onProfile;
  final VoidCallback? onReply;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final reply = comment.isReply;
    final muted = SnapFitColors.textSecondaryOf(context);
    return Padding(
      padding: EdgeInsets.only(left: reply ? 44 : 0, top: reply ? 0 : 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: reply
              ? Border(left: BorderSide(color: SocialStyle.line(context)))
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(reply ? 10 : 0, 7, 0, 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SocialCommentAvatar(
                profile: comment.author,
                size: reply ? 28 : 34,
                onTap: () => onProfile(comment.author),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이름 폭을 먼저 확보하고, 공간이 부족할 때만 정보를 다음 줄로 보낸다.
                    Wrap(
                      spacing: comment.author.userId == workAuthorId ? 6 : 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        InkWell(
                          onTap: () => onProfile(comment.author),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Text(
                              comment.author.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (comment.author.userId == workAuthorId)
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: SocialStyle.paper(context),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    '작성자',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: muted,
                                    ),
                                  ),
                                ),
                              ),
                            Text(
                              socialCommentTime(comment.createdAt),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: muted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (reply)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          comment.parentAuthor == null
                              ? '이전 댓글에 남긴 답글'
                              : '@${comment.parentAuthor!.handle}님에게 답글',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ),
                    SocialCommentBody(comment: comment, onProfile: onProfile),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: ValueKey('social-comment-reply-${comment.id}'),
                        onPressed: onReply,
                        style: TextButton.styleFrom(
                          foregroundColor: muted,
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          minimumSize: const Size(44, 40),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        child: const Text('답글 달기'),
                      ),
                    ),
                  ],
                ),
              ),
              action,
            ],
          ),
        ),
      ),
    );
  }
}

class SocialMentionSuggestions extends StatelessWidget {
  const SocialMentionSuggestions({
    super.key,
    required this.profiles,
    required this.query,
    required this.loading,
    required this.failed,
    required this.onSelect,
    required this.onRetry,
  });

  final List<SocialProfile> profiles;
  final String query;
  final bool loading, failed;
  final ValueChanged<SocialProfile> onSelect;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('social-mention-suggestions'),
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: SocialStyle.background(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: SocialStyle.line(context)),
      ),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: .1),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading) const LinearProgressIndicator(minHeight: 2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 216),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                for (final profile in profiles)
                  ListTile(
                    key: ValueKey('social-mention-${profile.userId}'),
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    leading: SocialCommentAvatar(profile: profile, size: 30),
                    title: Text(
                      profile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '@${profile.handle}',
                      style: TextStyle(
                        fontSize: 12,
                        color: SnapFitColors.textSecondaryOf(context),
                      ),
                    ),
                    onTap: () => onSelect(profile),
                  ),
                if (profiles.isEmpty && !loading && !failed)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      query.isEmpty ? '아이디를 입력해 사용자를 찾아보세요.' : '일치하는 사용자가 없어요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: SnapFitColors.textSecondaryOf(context),
                      ),
                    ),
                  ),
                if (failed)
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const ExperienceIcon('RefreshCw', size: 16),
                    label: const Text('사용자 다시 찾기'),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
