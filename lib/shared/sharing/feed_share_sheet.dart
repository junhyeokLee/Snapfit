import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/experience_form_style.dart';
import '../../shared/widgets/experience_icon.dart';

typedef FeedImageShareWriter =
    Future<ShareResult> Function(Uint8List bytes, String filename, Rect origin);

/// Files and captions are separate: some receiving apps reject image + text.
/// A local PNG is the only image payload; source URLs never enter the share UI.
final feedImageShareWriterProvider = Provider<FeedImageShareWriter>((ref) {
  return (bytes, filename, origin) => SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'image/png')],
      fileNameOverrides: [filename],
      subject: 'SnapFit 앨범',
      sharePositionOrigin: origin,
      downloadFallbackEnabled: true,
    ),
  );
});

typedef FeedLinkShareWriter =
    Future<ShareResult> Function(Uri uri, Rect origin);
final feedLinkShareWriterProvider = Provider<FeedLinkShareWriter>((ref) {
  return (uri, origin) => SharePlus.instance.share(
    ShareParams(
      uri: uri,
      sharePositionOrigin: origin,
      subject: 'SnapFit 앨범',
      text: 'SnapFit으로 만든 앨범이에요. 함께 보기 →\n$uri',
    ),
  );
});

class FeedSharePhoto {
  const FeedSharePhoto({
    required this.id,
    required this.preview,
    required this.render,
  });

  final String id;
  final WidgetBuilder preview;
  final Future<Uint8List> Function(ThemeData theme, bool Function() isActive)
  render;
}

/// The caller owns access/revision validation; this view owns selection,
/// cancellation and the final explicit handoff to the system share sheet.
Future<void> showFeedShareSheet(
  BuildContext context, {
  required String title,
  required String caption,
  required List<FeedSharePhoto> photos,
  required bool Function() isActive,
  String? initialPhotoId,
  String? note,
  Uri? publicUri,
  Future<void> Function()? validate,
}) async {
  if (!context.mounted || !isActive()) return;
  if (photos.isEmpty && publicUri == null && caption.trim().isEmpty) return;
  // A link is an app page, never a signed storage URL or access token.
  if (publicUri != null &&
      (publicUri.scheme != 'https' ||
          publicUri.host.isEmpty ||
          publicUri.userInfo.isNotEmpty ||
          publicUri.hasQuery ||
          (publicUri.fragment.isNotEmpty &&
              !RegExp(
                r'^/works/[A-Za-z0-9][A-Za-z0-9_-]{0,127}$',
              ).hasMatch(publicUri.fragment)))) {
    throw ArgumentError.value(publicUri, 'publicUri');
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FeedShareSheet(
      title: title,
      caption: caption,
      photos: photos,
      isActive: isActive,
      initialPhotoId: initialPhotoId,
      note: note,
      publicUri: publicUri,
      validate: validate,
    ),
  );
}

class _FeedShareSheet extends ConsumerStatefulWidget {
  const _FeedShareSheet({
    required this.title,
    required this.caption,
    required this.photos,
    required this.isActive,
    this.initialPhotoId,
    this.note,
    this.publicUri,
    this.validate,
  });

  final String title, caption;
  final List<FeedSharePhoto> photos;
  final bool Function() isActive;
  final String? initialPhotoId, note;
  final Uri? publicUri;
  final Future<void> Function()? validate;

  @override
  ConsumerState<_FeedShareSheet> createState() => _FeedShareSheetState();
}

class _FeedShareSheetState extends ConsumerState<_FeedShareSheet> {
  Timer? _guard;
  Uint8List? _png;
  int _selected = 0, _generation = 0;
  bool _preparing = false, _sending = false, _started = false, _invalid = false;
  String? _error, _notice;
  ModalRoute<dynamic>? _route;

  bool _active([int? generation]) {
    if (!mounted ||
        _invalid ||
        (_route != null && !_route!.isCurrent) ||
        (generation != null && generation != _generation)) {
      return false;
    }
    try {
      return widget.isActive();
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.photos.indexWhere(
      (p) => p.id == widget.initialPhotoId,
    );
    if (initial >= 0) _selected = initial;
    _guard = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!_active()) _invalidate();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    if (_started) return;
    _started = true;
    unawaited(_prepare());
  }

  void _invalidate() {
    if (!mounted || _invalid) return;
    _guard?.cancel();
    setState(() {
      _invalid = true;
      _png = null;
      _generation++;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = _route;
      if (mounted && route?.isActive == true)
        route!.navigator?.removeRoute(route);
    });
  }

  Future<void> _validate(int generation) async {
    if (!_active(generation)) throw StateError('Share session changed');
    await widget.validate?.call().timeout(const Duration(seconds: 25));
    if (!_active(generation)) throw StateError('Share session changed');
  }

  Future<void> _prepare() async {
    if (!_active() || _sending || _preparing) return;
    final generation = ++_generation;
    setState(() {
      _preparing = true;
      _png = null;
      _error = null;
      _notice = null;
    });
    try {
      await _validate(generation);
      if (widget.photos.isNotEmpty) {
        final bytes = await widget.photos[_selected]
            .render(Theme.of(context), () => _active(generation))
            .timeout(const Duration(seconds: 45));
        if (!_active(generation)) return;
        const signature = [137, 80, 78, 71, 13, 10, 26, 10];
        if (bytes.length < 24 ||
            bytes.length > 8 * 1024 * 1024 ||
            !List.generate(
              8,
              (i) => bytes[i] == signature[i],
            ).every((v) => v)) {
          throw const FormatException('Invalid shared PNG');
        }
        setState(() => _png = bytes);
      }
    } catch (_) {
      if (!_active(generation)) return;
      setState(() {
        _error = '사진이나 공개 상태를 확인하지 못했어요. 다시 준비해 주세요.';
        _png = null;
      });
    } finally {
      if (_active(generation)) setState(() => _preparing = false);
    }
  }

  void _select(int index) {
    if (_sending || _preparing || index == _selected || !_active()) return;
    setState(() => _selected = index);
    unawaited(_prepare());
  }

  Rect _origin(BuildContext anchor) {
    final box = anchor.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    return const Rect.fromLTWH(1, 1, 1, 1);
  }

  Future<void> _send(BuildContext anchor, {bool link = false}) async {
    if (!_active() || _sending || _preparing || (!link && _png == null)) return;
    final generation = _generation;
    final origin = _origin(anchor);
    final bytes = _png;
    setState(() {
      _sending = true;
      _notice = null;
      _error = null;
    });
    try {
      await _validate(generation);
      if (!_active(generation)) return;
      final result = link
          ? await ref.read(feedLinkShareWriterProvider)(
              widget.publicUri!,
              origin,
            )
          : await ref.read(feedImageShareWriterProvider)(
              bytes!,
              'snapfit-moment.png',
              origin,
            );
      if (!_active(generation)) return;
      setState(
        () => _notice = switch (result.status) {
          ShareResultStatus.dismissed => '공유를 취소했어요.',
          ShareResultStatus.unavailable =>
            link ? '공유창을 확인해 주세요.' : '공유창이나 저장된 이미지를 확인해 주세요.',
          ShareResultStatus.success => '선택한 앱에서 게시하거나 전송을 마쳐 주세요.',
        },
      );
    } catch (_) {
      if (!_active(generation)) return;
      setState(() {
        _png = null;
        _error = '공유할 사진과 공개 상태를 다시 확인해 주세요.';
      });
    } finally {
      if (_active(generation)) setState(() => _sending = false);
    }
  }

  Future<void> _copyCaption() async {
    if (!_active() || _sending || _preparing) return;
    final generation = _generation;
    setState(() {
      _sending = true;
      _notice = null;
    });
    try {
      await _validate(generation);
      if (!_active(generation)) return;
      await Clipboard.setData(ClipboardData(text: widget.caption));
      if (_active(generation))
        setState(() => _notice = '글을 복사했어요. 공유할 앱에 붙여넣어 주세요.');
    } catch (_) {
      if (_active(generation))
        setState(() {
          _png = null;
          _error = '글을 복사하지 못했어요. 다시 시도해 주세요.';
        });
    } finally {
      if (_active(generation)) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    _guard?.cancel();
    _png = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_invalid) return const SizedBox.shrink();
    final hasPhotos = widget.photos.isNotEmpty;
    final busy = _preparing || _sending;
    final accent = ExperienceFormStyle.selectionInk(context);
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: ExperienceFormStyle.text(
                            context,
                            22,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('feed-share-close'),
                        tooltip: '공유 닫기',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const ExperienceIcon('X'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasPhotos ? '꾸민 모습 그대로, 한 장만 골라 보내요.' : '피드 링크와 글을 공유해요.',
                    style: ExperienceFormStyle.text(
                      context,
                      13,
                      secondary: true,
                    ),
                  ),
                  if (hasPhotos) ...[
                    const SizedBox(height: 18),
                    Container(
                      key: const ValueKey('feed-share-preview'),
                      height: (MediaQuery.sizeOf(context).height * .27).clamp(
                        120,
                        260,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: .035),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _png != null
                          ? Image.memory(
                              _png!,
                              fit: BoxFit.contain,
                              cacheWidth: 780,
                              semanticLabel: '공유할 사진 ${_selected + 1}',
                            )
                          : Center(
                              child: _preparing
                                  ? const CircularProgressIndicator(
                                      strokeWidth: 2,
                                    )
                                  : const ExperienceIcon('Image', size: 36),
                            ),
                    ),
                    if (widget.photos.length > 1) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 76,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.photos.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, index) => Semantics(
                            selected: index == _selected,
                            button: true,
                            label: '${index + 1}번째 사진 공유 선택',
                            child: InkWell(
                              key: ValueKey(
                                'feed-share-photo-${widget.photos[index].id}',
                              ),
                              onTap: busy ? null : () => _select(index),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 76,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: index == _selected
                                        ? accent
                                        : Theme.of(context).dividerColor,
                                    width: index == _selected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: widget.photos[index].preview(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Builder(
                      builder: (anchor) => FilledButton.icon(
                        key: const ValueKey('feed-share-image'),
                        onPressed: busy || _png == null
                            ? null
                            : () => _send(anchor),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(44, 52),
                        ),
                        icon: const ExperienceIcon('Share2', size: 20),
                        label: Text(
                          _preparing
                              ? '사진 준비 중'
                              : _sending
                              ? '공유 여는 중'
                              : '사진 공유하기',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      kIsWeb
                          ? '공유창에서 인스타그램·카카오톡을 선택해 주세요.\n공유창이 지원되지 않는 브라우저에서는 이미지가 저장돼요.'
                          : '공유창에서 인스타그램·카카오톡을 선택해 주세요.',
                      textAlign: TextAlign.center,
                      style: ExperienceFormStyle.text(
                        context,
                        12,
                        secondary: true,
                      ),
                    ),
                  ],
                  if (widget.caption.trim().isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      widget.caption,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: ExperienceFormStyle.text(context, 13),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        key: const ValueKey('feed-share-copy-caption'),
                        onPressed: busy ? null : _copyCaption,
                        icon: const ExperienceIcon('Copy', size: 17),
                        label: const Text('글 복사'),
                      ),
                    ),
                  ],
                  if (widget.publicUri != null)
                    Builder(
                      builder: (anchor) => OutlinedButton.icon(
                        key: const ValueKey('feed-share-link'),
                        onPressed: busy
                            ? null
                            : () => _send(anchor, link: true),
                        icon: const ExperienceIcon('Link2'),
                        label: const Text('피드 링크 공유하기'),
                      ),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      key: const ValueKey('feed-share-error'),
                      style: ExperienceFormStyle.text(context, 13),
                    ),
                    TextButton(
                      key: const ValueKey('feed-share-retry'),
                      onPressed: busy ? null : _prepare,
                      child: const Text('다시 준비하기'),
                    ),
                  ],
                  if (_notice != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _notice!,
                        key: const ValueKey('feed-share-notice'),
                        style: ExperienceFormStyle.text(
                          context,
                          12,
                          secondary: true,
                        ),
                      ),
                    ),
                  if (widget.note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        widget.note!,
                        style: ExperienceFormStyle.text(
                          context,
                          12,
                          secondary: true,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
