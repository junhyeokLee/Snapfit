import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/utils/context_extensions.dart';
import '../../../../shared/web/web_design.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../domain/social_models.dart';
import '../../domain/social_topics.dart';
import '../../../../shared/widgets/experience_icon.dart';

/// Neutral surfaces keep published pages in focus; logo teal marks actions.
abstract final class SocialStyle {
  static Color accent(BuildContext context) => kIsWeb
      ? WebPalette.of(context).brandInk
      : Theme.of(context).brightness == Brightness.dark
      ? SnapFitColors.accentInkDark
      : SnapFitColors.accentInk;
  static Color paper(BuildContext context) => kIsWeb
      ? WebPalette.of(context).canvas
      : Theme.of(context).brightness == Brightness.dark
      ? const Color(0xff232725)
      : const Color(0xfff1f3ef);
  static Color background(BuildContext context) => kIsWeb
      ? WebPalette.of(context).background
      : SnapFitColors.backgroundOf(context);
  static Color line(BuildContext context) => kIsWeb
      ? WebPalette.of(context).line
      : Theme.of(context).brightness == Brightness.dark
      ? const Color(0xff363c37)
      : const Color(0xffe2e6df);
  static Color ink(BuildContext context) => kIsWeb
      ? WebPalette.of(context).ink
      : SnapFitColors.textPrimaryOf(context);
  static ButtonStyle primary(BuildContext context) => FilledButton.styleFrom(
    backgroundColor: kIsWeb
        ? WebPalette.of(context).brand
        : SnapFitColors.actionAccent,
    foregroundColor: kIsWeb
        ? WebPalette.of(context).onBrand
        : SnapFitColors.onAccent,
    minimumSize: const Size(0, 48),
    shape: const StadiumBorder(),
  );
}

class SocialContent extends StatelessWidget {
  const SocialContent({super.key, required this.child, this.maxWidth = 720});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Published snapshots keep their original page ratio without cropping.
double socialArtworkHeight(double width, double aspectRatio) {
  final ratio = aspectRatio.isFinite && aspectRatio > 0
      ? aspectRatio.clamp(.1, 10).toDouble()
      : 1.0;
  return (width / ratio).clamp(1.0, 1800.0);
}

class SocialEmpty extends StatelessWidget {
  const SocialEmpty({
    super.key,
    required this.title,
    required this.message,
    this.action,
    this.icon = const ExperienceIcon('BookOpen', size: 28),
  });
  final String title, message;
  final Widget? action;
  final Widget icon;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 56),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: SizedBox.square(
                  dimension: 96,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.rotate(
                        angle: -.12,
                        child: Container(
                          width: 62,
                          height: 76,
                          decoration: BoxDecoration(
                            color: SocialStyle.paper(context),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: SocialStyle.line(context),
                            ),
                          ),
                        ),
                      ),
                      Transform.rotate(
                        angle: .08,
                        child: Container(
                          width: 62,
                          height: 76,
                          decoration: BoxDecoration(
                            color: SocialStyle.background(context),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: SocialStyle.line(context),
                            ),
                          ),
                          child: icon,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  letterSpacing: -.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1.7,
                  color: SnapFitColors.textSecondaryOf(context),
                ),
              ),
              if (action != null) ...[const SizedBox(height: 26), action!],
            ],
          ),
        ),
      ),
    ),
  );
}

/// An honest visual placeholder, never a synthetic post or sample photo.
class SocialArtworkPlaceholder extends StatelessWidget {
  const SocialArtworkPlaceholder({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: SocialStyle.paper(context),
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExperienceIcon('BookOpen', size: compact ? 28 : 40, color: SocialStyle.accent(context),
            ),
            if (!compact) ...[
              const SizedBox(height: 12),
              Text(
                '공개 이미지가 없어요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: SnapFitColors.textSecondaryOf(context),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class SocialAuthorLine extends StatelessWidget {
  const SocialAuthorLine({
    super.key,
    required this.author,
    required this.onTap,
    this.compact = false,
  });
  final SocialProfile author;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final initial = author.displayName.characters.firstOrNull ?? 's';
    final fallback = ColoredBox(
      color: SocialStyle.paper(context),
      child: Center(
        child: Text(
          initial,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: SocialStyle.accent(context),
          ),
        ),
      ),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 7 : 10),
        child: Row(
          children: [
            ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(compact ? 36 : 12),
                child: SizedBox.square(
                  dimension: compact ? 36 : 40,
                  child: author.avatarUrl?.isNotEmpty == true
                      ? Image.network(
                          author.avatarUrl!,
                          fit: BoxFit.cover,
                          cacheWidth: 120,
                          errorBuilder: (_, _, _) => fallback,
                        )
                      : fallback,
                ),
              ),
            ),
            SizedBox(width: compact ? 10 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    author.displayName,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 14 : 15,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${author.handle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: SnapFitColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 12),
              ExcludeSemantics(
                child: ExperienceIcon('ChevronRight', size: 17, color: SnapFitColors.textMutedOf(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SocialWorkMetadata extends StatelessWidget {
  const SocialWorkMetadata({super.key, required this.work});
  final SocialWork work;
  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(
    style: TextStyle(
      fontSize: 12,
      height: 1.5,
      color: SnapFitColors.textSecondaryOf(context),
    ),
    child: Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        if (work.isMoment) ...[
          const Text('월간 기록'),
          Text(socialDate(work.recordDate ?? work.createdAt)),
        ] else ...[
          Text(socialTopicLabel(work.topic)),
          Text(work.isRestricted ? '공개 제한' : '${work.imageUrls.length}쪽'),
          Text(socialDate(work.createdAt)),
        ],
      ],
    ),
  );
}

class SocialLoading extends StatelessWidget {
  const SocialLoading({super.key, this.message = '공개 기록과 앨범을 불러오고 있어요.'});
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: message,
    child: ExcludeSemantics(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: SnapFitColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class SocialFailure extends StatelessWidget {
  const SocialFailure({super.key, required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => SocialEmpty(
    title: '기록을 불러오지 못했어요.',
    message: '연결 상태를 확인하고 다시 시도해 주세요.',
    icon: const ExperienceIcon('CloudOff'),
    action: OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
  );
}

/// No private source URL, editable document or persistent disk image cache.
class SocialWorkImage extends StatefulWidget {
  const SocialWorkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
    this.onRetry,
    this.label = '공개 이미지',
    this.excludeImageSemantics = false,
    this.imageDecodeWidth = 1440,
  });
  final String url, label;
  final BoxFit fit;
  final VoidCallback? onRetry;
  final bool excludeImageSemantics;
  final int imageDecodeWidth;
  @override
  State<SocialWorkImage> createState() => _SocialWorkImageState();
}

class _SocialWorkImageState extends State<SocialWorkImage> {
  int _attempt = 0;
  int _sourceRevision = 0;
  bool _automaticRetryUsed = false;
  bool _automaticRetryPending = false;

  @override
  void didUpdateWidget(covariant SocialWorkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _sourceRevision++;
      _automaticRetryPending = false;
      // A refreshed signature is not evidence that the image is readable.
      // Only a decoded frame restores the automatic recovery budget.
    }
  }

  void _recoverImage() {
    if (widget.onRetry == null ||
        _automaticRetryUsed ||
        _automaticRetryPending) {
      return;
    }
    _automaticRetryUsed = true;
    _automaticRetryPending = true;
    final revision = _sourceRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          revision != _sourceRevision ||
          !_automaticRetryPending ||
          widget.onRetry == null) {
        return;
      }
      _automaticRetryPending = false;
      setState(() => _attempt++);
      widget.onRetry?.call();
    });
  }

  void _retry() {
    _sourceRevision++;
    _automaticRetryPending = false;
    _automaticRetryUsed = true;
    // Resolve the same URL again even while the parent preserves loaded data.
    setState(() => _attempt++);
    widget.onRetry?.call();
  }

  @override
  Widget build(BuildContext context) => Image.network(
    widget.url,
    key: ValueKey((widget.url, _attempt)),
    fit: widget.fit,
    semanticLabel: widget.label,
    excludeFromSemantics: widget.excludeImageSemantics,
    // Browser-decoded sizes follow the CSS box; native decoding is bounded.
    cacheWidth: widget.imageDecodeWidth,
    frameBuilder: (context, child, frame, synchronous) {
      if (frame != null || synchronous) {
        _automaticRetryUsed = false;
        _automaticRetryPending = false;
      }
      return child;
    },
    loadingBuilder: (context, child, progress) => progress == null
        ? child
        : const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
    errorBuilder: (context, error, stack) {
      _recoverImage();
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 120) {
            return Center(
              child: widget.onRetry == null
                  ? Icon(
                      Icons.image_not_supported_outlined,
                      color: SnapFitColors.textMutedOf(context),
                    )
                  : IconButton(
                      tooltip: '이미지 다시 불러오기',
                      onPressed: _retry,
                      icon: const ExperienceIcon('RefreshCw'),
                    ),
            );
          }
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: widget.onRetry == null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.image_not_supported_outlined,
                          color: SnapFitColors.textMutedOf(context),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '이미지를 불러오지 못했어요.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : TextButton.icon(
                      onPressed: _retry,
                      icon: const ExperienceIcon('RefreshCw'),
                      label: const Text('이미지 다시 불러오기'),
                    ),
            ),
          );
        },
      );
    },
  );
}

class SocialWorkTile extends StatelessWidget {
  const SocialWorkTile({
    super.key,
    required this.work,
    required this.onTap,
    this.onRetry,
    this.preserveArtworkRatio = false,
  });
  final SocialWork work;
  final VoidCallback onTap;
  final VoidCallback? onRetry;
  final bool preserveArtworkRatio;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio:
              preserveArtworkRatio &&
                  work.aspectRatio.isFinite &&
                  work.aspectRatio > 0
              ? work.aspectRatio.clamp(.1, 10).toDouble()
              : 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ColoredBox(
              color: SocialStyle.paper(context),
              child: work.isRestricted || work.imageUrls.isEmpty
                  ? const SocialArtworkPlaceholder(compact: true)
                  : SocialWorkImage(
                      key: ValueKey('social-work-tile-image-${work.id}'),
                      url: work.imageUrls.first,
                      label: '${work.title} 대표 페이지',
                      onRetry: onRetry,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          work.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          work.isRestricted
              ? '공개 제한'
              : '${work.imageUrls.length}쪽 · ${socialTopicLabel(work.topic)}',
          style: TextStyle(
            fontSize: 12,
            color: SnapFitColors.textSecondaryOf(context),
          ),
        ),
      ],
    ),
  );
}

class SocialReactions extends StatelessWidget {
  const SocialReactions({
    super.key,
    required this.work,
    required this.onLike,
    required this.onSave,
    required this.onComments,
    this.busy = false,
    this.compact = false,
  });
  final SocialWork work;
  final VoidCallback onLike, onSave, onComments;
  final bool busy;
  final bool compact;

  Widget _reaction(
    BuildContext context, {
    required String keyName,
    required String action,
    required String label,
    required int count,
    required IconData icon,
    required VoidCallback onPressed,
    bool selected = false,
    bool enabled = true,
    bool toggle = false,
  }) => Semantics(
    key: ValueKey('$keyName-${work.id}'),
    button: true,
    enabled: enabled,
    toggled: toggle ? selected : null,
    label: action,
    value: '$count개',
    onTap: enabled ? onPressed : null,
    child: ExcludeSemantics(
      child: Tooltip(
        message: action,
        child: TextButton.icon(
          onPressed: enabled ? onPressed : null,
          style: TextButton.styleFrom(
            minimumSize: Size(44, compact ? 44 : 48),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 12,
              vertical: compact ? 9 : 11,
            ),
            backgroundColor: selected && !compact
                ? SocialStyle.paper(context)
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            foregroundColor: selected
                ? SocialStyle.accent(context)
                : SnapFitColors.textPrimaryOf(context),
          ),
          icon: Icon(icon, size: compact ? 24 : 22),
          label: Wrap(
            spacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (!compact) Text(label, style: const TextStyle(fontSize: 13)),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _reaction(
              context,
              keyName: 'social-like',
              action: work.isLiked ? '좋아요 취소' : '좋아요',
              label: '좋아요',
              count: work.likeCount,
              icon: work.isLiked ? Icons.favorite : Icons.favorite_border,
              onPressed: onLike,
              selected: work.isLiked,
              toggle: true,
              enabled: !busy,
            ),
            _reaction(
              context,
              keyName: 'social-comments',
              action: '댓글 보기',
              label: '댓글',
              count: work.commentCount,
              icon: Icons.chat_bubble_outline,
              onPressed: onComments,
            ),
          ],
        ),
      ),
      Semantics(
        key: ValueKey('social-save-${work.id}'),
        button: true,
        enabled: !busy,
        toggled: work.isSaved,
        label:
            '${work.isMoment ? '기록' : '앨범'} ${work.isSaved ? '저장 해제' : '저장'}',
        onTap: busy ? null : onSave,
        child: ExcludeSemantics(
          child: IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            tooltip:
                '${work.isMoment ? '기록' : '앨범'} ${work.isSaved ? '저장 해제' : '저장'}',
            onPressed: busy ? null : onSave,
            icon: Icon(
              work.isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: work.isSaved ? SocialStyle.accent(context) : null,
            ),
          ),
        ),
      ),
    ],
  );
}

String socialDate(DateTime date) =>
    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

void socialError(BuildContext context, {String? message}) {
  context.showSnack(message ?? '처리하지 못했어요. 잠시 후 다시 시도해 주세요.');
}
