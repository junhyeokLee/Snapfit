import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/semantics.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../domain/social_models.dart';
import 'social_widgets.dart';

/// A shared width and safe inset for profiles on phones and wide web windows.
class SocialProfileContent extends StatelessWidget {
  const SocialProfileContent({
    super.key,
    required this.child,
    this.maxWidth = 1120,
    this.padding = const EdgeInsets.fromLTRB(20, 32, 20, 40),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(padding: padding, child: child),
    ),
  );
}

class SocialProfileAvatar extends StatefulWidget {
  const SocialProfileAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 56,
    this.borderRadius,
    this.expandable = false,
    this.refreshImageUrl,
  });

  final String name;
  final String? imageUrl;
  final double size;
  final BorderRadius? borderRadius;
  final bool expandable;
  final Future<String?> Function()? refreshImageUrl;

  @override
  State<SocialProfileAvatar> createState() => _SocialProfileAvatarState();
}

class _SocialProfileAvatarState extends State<SocialProfileAvatar> {
  bool _opening = false;
  int _openRevision = 0;
  DialogRoute<void>? _photoRoute;
  String? _thumbnailUrl;
  int _thumbnailRevision = 0;
  bool _thumbnailRecoveryPending = false;
  bool _thumbnailRecoveryAttempted = false;

  String get name => widget.name;
  String? get imageUrl => widget.imageUrl;
  double get size => widget.size;
  bool get expandable => widget.expandable;

  @override
  void initState() {
    super.initState();
    _thumbnailUrl = imageUrl;
  }

  @override
  void didUpdateWidget(covariant SocialProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != name || oldWidget.imageUrl != imageUrl) {
      _openRevision++;
      _opening = false;
      _dismissPhoto();
      _thumbnailRevision++;
      _thumbnailUrl = imageUrl;
      _thumbnailRecoveryPending = false;
      _thumbnailRecoveryAttempted = false;
    }
  }

  @override
  void dispose() {
    _openRevision++;
    _thumbnailRevision++;
    _dismissPhoto();
    super.dispose();
  }

  void _dismissPhoto() {
    final route = _photoRoute;
    _photoRoute = null;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = route.navigator;
      if (navigator != null && route.isActive) navigator.removeRoute(route);
    });
  }

  Uri? _imageUri(String? value) {
    final uri = Uri.tryParse(value?.trim() ?? '');
    return uri != null &&
            (uri.scheme == 'https' || uri.scheme == 'http') &&
            uri.host.isNotEmpty
        ? uri
        : null;
  }

  void _recoverThumbnail(Uri failedUri) {
    final refresh = widget.refreshImageUrl;
    if (refresh == null ||
        _imageUri(_thumbnailUrl) != failedUri ||
        _thumbnailRecoveryPending ||
        _thumbnailRecoveryAttempted) {
      return;
    }
    _thumbnailRecoveryPending = true;
    _thumbnailRecoveryAttempted = true;
    final revision = _thumbnailRevision;
    // Image errors arrive during build; revalidate public access after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || revision != _thumbnailRevision) return;
      try {
        final freshUri = _imageUri(await refresh());
        if (!mounted || revision != _thumbnailRevision) return;
        setState(() {
          _thumbnailUrl = freshUri?.toString();
          _thumbnailRevision++;
          _thumbnailRecoveryPending = false;
        });
      } catch (_) {
        if (mounted && revision == _thumbnailRevision) {
          _thumbnailRecoveryPending = false;
        }
      }
    });
  }

  Future<void> _openPhoto(BuildContext context, Uri cachedUri) async {
    if (_opening) return;
    final revision = ++_openRevision;
    setState(() => _opening = true);
    try {
      final resolve = widget.refreshImageUrl;
      final uri = resolve == null ? cachedUri : _imageUri(await resolve());
      if (!mounted || revision != _openRevision) return;
      if (uri == null) {
        _photoUnavailable();
      } else {
        _showPhoto(context, uri);
      }
    } catch (_) {
      if (mounted && revision == _openRevision) _photoUnavailable();
    } finally {
      if (mounted && revision == _openRevision)
        setState(() => _opening = false);
    }
  }

  void _photoUnavailable() => ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    const SnackBar(content: Text('현재 볼 수 없는 사진이에요. 프로필을 다시 확인해 주세요.')),
  );

  void _showPhoto(BuildContext context, Uri uri) {
    final route = DialogRoute<void>(
      context: context,
      useSafeArea: false,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: const Color(0xFF141818),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '사진 닫기',
                      color: Colors.white,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '프로필 사진',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Image.network(
                      uri.toString(),
                      cacheWidth: 1600,
                      fit: BoxFit.contain,
                      semanticLabel: '$name 공개 프로필 사진',
                      errorBuilder: (_, _, _) => const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          '사진을 불러오지 못했어요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, height: 1.6),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    _photoRoute = route;
    Navigator.of(context, rootNavigator: true).push(route).whenComplete(() {
      if (identical(_photoRoute, route)) _photoRoute = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final uri = _imageUri(_thumbnailUrl);
    final VoidCallback? openPhoto = expandable && uri != null && !_opening
        ? () => _openPhoto(context, uri)
        : null;
    final canExpand = openPhoto != null;
    final initials = name.trim().isEmpty ? '?' : name.trim().characters.first;
    final fallback = ColoredBox(
      color: SocialStyle.paper(context),
      child: Center(
        child: Text(
          initials,
          style: ExperienceFormStyle.text(
            context,
            size * .35,
            weight: FontWeight.w600,
            color: SocialStyle.accent(context),
          ),
        ),
      ),
    );
    final photo = SizedBox.square(
      dimension: size,
      child: uri != null
          ? Image.network(
              uri.toString(),
              key: ValueKey(_thumbnailRevision),
              fit: BoxFit.cover,
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                  .round(),
              frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
                if ((frame != null || wasSynchronouslyLoaded) &&
                    _imageUri(_thumbnailUrl) == uri) {
                  // Only a decoded image permits another expiry recovery.
                  _thumbnailRecoveryAttempted = false;
                }
                return child;
              },
              errorBuilder: (_, _, _) {
                _recoverThumbnail(uri);
                return fallback;
              },
            )
          : fallback,
    );
    final radius = widget.borderRadius;
    final ShapeBorder shape = radius == null
        ? const CircleBorder()
        : RoundedRectangleBorder(borderRadius: radius);
    final portrait = ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      child: photo,
    );
    final image = canExpand
        ? Tooltip(
            message: '프로필 사진 크게 보기',
            child: Material(
              color: Colors.transparent,
              shape: shape,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: shape,
                onTap: openPhoto,
                child: Stack(
                  children: [
                    portrait,
                    if (radius != null)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xcc1b2420),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(7),
                            child: Icon(
                              Icons.open_in_full,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          )
        : portrait;
    return Semantics(
      image: true,
      label: '$name 프로필 사진',
      button: canExpand,
      hint: canExpand ? '크게 보기' : null,
      onTap: openPhoto,
      child: ExcludeSemantics(child: image),
    );
  }
}

class SocialProfileIdentity extends StatelessWidget {
  const SocialProfileIdentity({
    super.key,
    required this.name,
    required this.handle,
    required this.bio,
    required this.worksCount,
    required this.followersCount,
    required this.followingCount,
    required this.onFollowers,
    required this.onFollowing,
    this.avatarUrl,
    this.privateLoginId,
    this.refreshImageUrl,
    this.webLayout = kIsWeb,
  });

  final bool webLayout;
  final String name;
  final String handle;
  final String bio;
  final String? avatarUrl;

  /// Supplied only by the verified owner on the private My destination.
  final String? privateLoginId;
  final Future<String?> Function()? refreshImageUrl;
  final int worksCount;
  final int followersCount;
  final int followingCount;
  final VoidCallback onFollowers;
  final VoidCallback onFollowing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (webLayout) return _webIdentity(context, constraints);
      final wide = constraints.maxWidth >= 760;
      final stack =
          constraints.maxWidth < 276 ||
          MediaQuery.textScalerOf(context).scale(14) > 20;
      final portrait = SocialProfileAvatar(
        name: name,
        imageUrl: avatarUrl,
        size: wide
            ? 196
            : constraints.maxWidth < 340
            ? 148
            : 164,
        borderRadius: BorderRadius.circular(wide ? 32 : 26),
        expandable: true,
        refreshImageUrl: refreshImageUrl,
      );
      final description = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: ExperienceFormStyle.text(
              context,
              wide ? 38 : 27,
              weight: FontWeight.w600,
            ).copyWith(height: 1.18, letterSpacing: -1),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (handle.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              '@$handle',
              style: ExperienceFormStyle.text(context, 13, secondary: true),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (privateLoginId?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 6),
            _loginId(context),
          ],
        ],
      );
      final statStyle = TextButton.styleFrom(
        foregroundColor: ExperienceFormStyle.ink(context),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        textStyle: ExperienceFormStyle.text(
          context,
          14,
          weight: FontWeight.w500,
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stack)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [portrait, const SizedBox(height: 16), description],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                portrait,
                SizedBox(width: wide ? 36 : 20),
                Expanded(child: description),
              ],
            ),
          if (bio.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              bio,
              style: ExperienceFormStyle.text(
                context,
                14,
              ).copyWith(height: 1.6),
            ),
          ],
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: SocialStyle.line(context))),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 16,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '공개 작품 $worksCount',
                      style: ExperienceFormStyle.text(
                        context,
                        14,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    style: statStyle,
                    onPressed: onFollowers,
                    child: Text('팔로워 $followersCount'),
                  ),
                  TextButton(
                    style: statStyle,
                    onPressed: onFollowing,
                    child: Text('팔로잉 $followingCount'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _loginId(BuildContext context) => Text(
    privateLoginId!.trim(),
    key: const ValueKey('social-profile-login-id'),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: ExperienceFormStyle.text(context, 12, secondary: true),
  );

  Widget _webIdentity(BuildContext context, BoxConstraints bounds) {
    final compact = bounds.maxWidth < 520;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: ExperienceFormStyle.text(
            context,
            compact ? 25 : 32,
            weight: FontWeight.w600,
          ).copyWith(letterSpacing: -.8, height: 1.25),
        ),
        if (handle.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            '@$handle',
            style: ExperienceFormStyle.text(context, 13, secondary: true),
          ),
        ],
        if (privateLoginId?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 6),
          _loginId(context),
        ],
        if (bio.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            bio,
            style: ExperienceFormStyle.text(context, 14).copyWith(height: 1.6),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '공개 작품 $worksCount',
              style: ExperienceFormStyle.text(
                context,
                13,
                weight: FontWeight.w500,
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: SocialStyle.ink(context),
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              onPressed: onFollowers,
              child: Text('팔로워 $followersCount'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: SocialStyle.ink(context),
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              onPressed: onFollowing,
              child: Text('팔로잉 $followingCount'),
            ),
          ],
        ),
      ],
    );
    final portrait = SocialProfileAvatar(
      name: name,
      imageUrl: avatarUrl,
      size: compact ? 88 : 112,
      borderRadius: BorderRadius.circular(compact ? 22 : 26),
      expandable: true,
      refreshImageUrl: refreshImageUrl,
    );
    if (bounds.maxWidth < 350 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.5) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [portrait, const SizedBox(height: 20), details],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        portrait,
        SizedBox(width: compact ? 20 : 28),
        Expanded(child: details),
      ],
    );
  }
}

/// A profile gallery gives each selected public snapshot its full page ratio.
class SocialProfileGallery extends StatefulWidget {
  const SocialProfileGallery({
    super.key,
    required this.works,
    required this.onOpenWork,
    this.onRetry,
    this.webLayout = kIsWeb,
  });

  final bool webLayout;
  final List<SocialWork> works;
  final ValueChanged<SocialWork> onOpenWork;
  final ValueChanged<SocialWork>? onRetry;

  @override
  State<SocialProfileGallery> createState() => _SocialProfileGalleryState();
}

class _SocialProfileGalleryState extends State<SocialProfileGallery> {
  bool _large = true;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final stack =
              constraints.maxWidth < 270 ||
              MediaQuery.textScalerOf(context).scale(13) > 18;
          final title = Text(
            '공개 작품',
            style: ExperienceFormStyle.text(
              context,
              21,
              weight: FontWeight.w600,
            ),
          );
          final modes = SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: false,
                tooltip: '모아 보기',
                label: Text('모아 보기'),
              ),
              ButtonSegment(
                value: true,
                tooltip: '크게 보기',
                label: Text('크게 보기'),
              ),
            ],
            selected: {_large},
            onSelectionChanged: (value) =>
                setState(() => _large = value.single),
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 9, vertical: 8),
              ),
              textStyle: WidgetStatePropertyAll(
                ExperienceFormStyle.text(context, 12),
              ),
              foregroundColor: WidgetStatePropertyAll(
                ExperienceFormStyle.ink(context),
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? SocialStyle.paper(context)
                    : Colors.transparent,
              ),
              side: WidgetStatePropertyAll(
                BorderSide(color: ExperienceFormStyle.line(context)),
              ),
            ),
          );
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 10), modes],
            );
          }
          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 8),
              modes,
            ],
          );
        },
      ),
      const SizedBox(height: 14),
      LayoutBuilder(
        builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
          final columns =
              largeText ||
                  constraints.maxWidth < 280 ||
                  (_large && widget.works.length == 1 && !widget.webLayout)
              ? 1
              : _large
              ? (constraints.maxWidth >= 700 ? 2 : 1)
              : constraints.maxWidth >= 900
              ? 3
              : 2;
          final gap = constraints.maxWidth >= 700
              ? (widget.webLayout ? 28.0 : 24.0)
              : 12.0;
          final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
          return Semantics(
            container: true,
            explicitChildNodes: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var column = 0; column < columns; column++) ...[
                  if (column > 0) SizedBox(width: gap),
                  SizedBox(
                    width: width,
                    child: Column(
                      children: [
                        for (
                          var index = column;
                          index < widget.works.length;
                          index += columns
                        ) ...[
                          if (index != column)
                            SizedBox(height: _large ? 32 : 24),
                          _tile(widget.works[index], index),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ],
  );

  Widget _tile(SocialWork work, int index) => SocialProfileWorkTile(
    key: ValueKey('social-profile-work-${work.id}'),
    work: work,
    large: _large,
    semanticOrder: index,
    onTap: () => widget.onOpenWork(work),
    onRetry: widget.onRetry == null ? null : () => widget.onRetry!(work),
  );
}

class SocialProfileWorkTile extends StatelessWidget {
  const SocialProfileWorkTile({
    super.key,
    required this.work,
    required this.onTap,
    this.onRetry,
    this.large = true,
    this.semanticOrder,
  });

  final SocialWork work;
  final VoidCallback onTap;
  final VoidCallback? onRetry;
  final bool large;
  final int? semanticOrder;

  @override
  Widget build(BuildContext context) {
    final ratio = work.aspectRatio.isFinite && work.aspectRatio > 0
        ? work.aspectRatio.clamp(.1, 10).toDouble()
        : 1.0;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      button: true,
      sortKey: semanticOrder == null
          ? null
          : OrdinalSortKey(semanticOrder!.toDouble()),
      label: '${work.title}, ${work.imageUrls.length}쪽 작품 보기',
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          excludeFromSemantics: true,
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: ratio,
                  child: ColoredBox(
                    color: SocialStyle.paper(context),
                    child: work.imageUrls.isEmpty
                        ? Center(
                            child: Icon(
                              Icons.auto_stories_outlined,
                              color: ExperienceFormStyle.muted(context),
                              size: 32,
                            ),
                          )
                        : SocialWorkImage(
                            url: work.imageUrls.first,
                            label: '${work.title} 공개 작품 미리보기',
                            excludeImageSemantics: true,
                            onRetry: onRetry,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ExcludeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        work.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ExperienceFormStyle.text(
                          context,
                          large ? 18 : 15,
                          weight: FontWeight.w600,
                        ).copyWith(height: 1.4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Icon(
                        Icons.north_east,
                        size: large ? 18 : 16,
                        color: ExperienceFormStyle.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              ExcludeSemantics(
                child: Text(
                  '${work.imageUrls.length}쪽 · ${work.topic}',
                  style: ExperienceFormStyle.text(context, 12, secondary: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keeps relationship controls below the identity when space is limited.
class SocialRelationTile extends StatelessWidget {
  const SocialRelationTile({
    super.key,
    required this.name,
    required this.handle,
    required this.onOpenProfile,
    this.avatarUrl,
    this.refreshImageUrl,
    this.isMe = false,
    this.actions = const [],
  });

  final String name;
  final String handle;
  final String? avatarUrl;
  final Future<String?> Function()? refreshImageUrl;
  final bool isMe;
  final VoidCallback onOpenProfile;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stackActions =
          constraints.maxWidth < 430 ||
          MediaQuery.textScalerOf(context).scale(14) > 18;
      final identity = InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpenProfile,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              SocialProfileAvatar(
                name: name,
                imageUrl: avatarUrl,
                refreshImageUrl: refreshImageUrl,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMe ? '$name · 나' : name,
                      style: ExperienceFormStyle.text(
                        context,
                        16,
                        weight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '@$handle',
                      style: ExperienceFormStyle.text(
                        context,
                        13,
                        secondary: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      final controls = Wrap(spacing: 6, runSpacing: 4, children: actions);
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: ExperienceFormStyle.line(context)),
          ),
        ),
        child: stackActions
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  identity,
                  if (actions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 72, bottom: 16),
                      child: controls,
                    ),
                ],
              )
            : Row(
                children: [
                  Expanded(child: identity),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    controls,
                  ],
                ],
              ),
      );
    },
  );
}

class SocialProfileStatePanel extends StatelessWidget {
  const SocialProfileStatePanel({
    super.key,
    required this.title,
    required this.message,
    this.action,
    this.loading = false,
    this.icon = Icons.auto_stories_outlined,
  });

  final String title;
  final String message;
  final Widget? action;
  final bool loading;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icon, size: 32, color: SocialStyle.accent(context)),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: ExperienceFormStyle.text(
                context,
                19,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: ExperienceFormStyle.text(context, 13, secondary: true),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    ),
  );
}
