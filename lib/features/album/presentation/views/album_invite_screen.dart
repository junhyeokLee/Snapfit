import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/theme/snapfit_design_tokens.dart' show SnapFitRadius;
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/web/web_design.dart';
import '../../data/api/album_provider.dart';
import '../../domain/entities/album.dart';
import '../../service/album_invite_service.dart';
import '../widgets/home/home_album_cover_thumbnail.dart';
import '../widgets/web/web_saved_album_artwork.dart';

class AlbumInviteScreen extends ConsumerStatefulWidget {
  final int albumId;
  final String albumTitle;
  final Album? album;
  final bool initialAllowEditing;

  const AlbumInviteScreen({
    super.key,
    required this.albumId,
    required this.albumTitle,
    this.album,
    this.initialAllowEditing = true,
  });

  @override
  ConsumerState<AlbumInviteScreen> createState() => _AlbumInviteScreenState();
}

class _AlbumInviteScreenState extends ConsumerState<AlbumInviteScreen> {
  late bool _allowEditing;
  String? _inviteLink;
  bool _isCreatingInvite = false;
  bool _isSharing = false;
  bool _isCopying = false;
  bool _copied = false;
  String? _inviteError;

  bool get _busy => _isCreatingInvite || _isSharing || _isCopying;

  @override
  void initState() {
    super.initState();
    _allowEditing = widget.initialAllowEditing;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _createInviteLink();
    });
  }

  @override
  Widget build(BuildContext context) => kIsWeb
      ? _buildWeb()
      : Scaffold(
          backgroundColor: SnapFitColors.backgroundOf(context),
          appBar: const ExperienceHeader(
            title: '멤버 초대',
            showNotifications: false,
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide =
                        constraints.maxWidth >= 540 &&
                        MediaQuery.orientationOf(context) ==
                            Orientation.landscape;
                    final compact = constraints.maxHeight < 420;
                    if (wide) {
                      return Padding(
                        key: const ValueKey('inviteContent'),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: (constraints.maxWidth * .36).clamp(
                                180,
                                300,
                              ),
                              child: SingleChildScrollView(
                                key: const PageStorageKey('invite-album'),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: _albumIdentity(
                                  compact: true,
                                  stacked: true,
                                  previewHeight: (constraints.maxHeight * .68)
                                      .clamp(96, 192),
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            VerticalDivider(
                              width: 1,
                              color: ExperienceFormStyle.line(context),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: SingleChildScrollView(
                                key: const PageStorageKey('invite-settings'),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: _linkSettings(
                                  compact: true,
                                  linkFirst: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      key: const ValueKey('inviteContent'),
                      padding: EdgeInsets.fromLTRB(
                        24,
                        compact ? 12 : 24,
                        24,
                        20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _albumIdentity(
                            compact: compact,
                            previewHeight: compact ? 104 : 164,
                          ),
                          SizedBox(height: compact ? 10 : 24),
                          Divider(
                            color: ExperienceFormStyle.line(context),
                            height: 1,
                          ),
                          SizedBox(height: compact ? 8 : 20),
                          _linkSettings(compact: compact),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: _actions(),
              ),
            ),
          ),
        );

  Widget _buildWeb() => SnapFitWebShell(
    title: '앨범 공유',
    showNavigation: false,
    actions: [
      TextButton.icon(
        onPressed: _busy ? null : () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back, size: 17),
        label: const Text('앨범으로'),
      ),
    ],
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WebPageHeading(
            eyebrow: 'SHARE ALBUM',
            title: '앨범에 초대하기',
            description: '참여할 사람의 권한을 정하고 초대 링크를 공유하세요.',
          ),
          const SizedBox(height: 30),
          LayoutBuilder(
            builder: (context, box) {
              final summary = WebSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.album != null) ...[
                      SizedBox(
                        height: 230,
                        child: Center(
                          child: WebSavedAlbumArtwork(album: widget.album!),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      widget.albumTitle,
                      style: TextStyle(
                        color: WebPalette.of(context).ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (widget.album != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        widget.album!.physicalCoverSize.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          color: WebPalette.of(context).muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Divider(height: 1, color: WebPalette.of(context).line),
                    const SizedBox(height: 20),
                    Text(
                      '초대 권한',
                      style: TextStyle(
                        fontSize: 12,
                        color: WebPalette.of(context).muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _allowEditing ? '보기 및 편집' : '보기 전용',
                      style: TextStyle(
                        color: WebPalette.of(context).brandInk,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _allowEditing
                          ? '참여자는 사진과 글, 페이지 구성을 함께 편집할 수 있습니다.'
                          : '참여자는 앨범을 볼 수 있으며 내용을 변경할 수 없습니다.',
                      style: TextStyle(
                        fontSize: 13,
                        color: WebPalette.of(context).muted,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              );
              final form = WebSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '공유 설정',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: WebPalette.of(context).ink,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _linkSettings(),
                    const SizedBox(height: 26),
                    _actions(),
                  ],
                ),
              );
              if (box.maxWidth < 900)
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [summary, const SizedBox(height: 20), form],
                );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 330, child: summary),
                  const SizedBox(width: 28),
                  Expanded(child: form),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    ),
  );

  Widget _albumIdentity({
    bool compact = false,
    bool stacked = false,
    double previewHeight = 164,
  }) => LayoutBuilder(
    builder: (context, bounds) {
      final album = widget.album?.id == widget.albumId ? widget.album : null;
      final vertical =
          stacked ||
          (!compact && bounds.maxWidth < 300) ||
          MediaQuery.textScalerOf(context).scale(16) > 22.4;
      final cover = album == null
          ? null
          : SizedBox(
              key: const ValueKey('inviteAlbumArtwork'),
              width: vertical
                  ? double.infinity
                  : compact
                  ? 80
                  : 144,
              height:
                  (vertical
                      ? previewHeight
                      : compact
                      ? 80
                      : 164) +
                  (compact && !vertical ? 8 : 16),
              child: Center(
                child: HomeAlbumCoverThumbnail(
                  album: album,
                  height: vertical
                      ? previewHeight
                      : compact
                      ? 80
                      : 164,
                  maxWidth: vertical
                      ? (bounds.maxWidth * .76).clamp(100, 218)
                      : compact
                      ? 72
                      : 132,
                  showBookDepth: true,
                  showShadow: true,
                ),
              ),
            );
      final identity = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact) ...[
            Text(
              '공유할 앨범',
              style: ExperienceFormStyle.text(context, 12, secondary: true),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            widget.albumTitle,
            style: ExperienceFormStyle.text(
              context,
              compact ? 18 : 20,
              weight: FontWeight.w700,
            ),
          ),
          if (album != null) ...[
            SizedBox(height: compact ? 6 : 10),
            Text(
              album.physicalCoverSize.displayName,
              key: const ValueKey('inviteAlbumSpec'),
              style: ExperienceFormStyle.text(context, 12, secondary: true),
            ),
          ],
          if (!compact) ...[
            const SizedBox(height: 10),
            Text(
              '초대받은 멤버와 이 앨범을 공유해요.',
              style: ExperienceFormStyle.text(context, 13, secondary: true),
            ),
          ],
        ],
      );
      return vertical
          ? Column(
              key: const ValueKey('inviteAlbumIdentity'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (cover != null) ...[cover, const SizedBox(height: 18)],
                identity,
              ],
            )
          : Row(
              key: const ValueKey('inviteAlbumIdentity'),
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (cover != null) ...[
                  cover,
                  SizedBox(width: compact ? 16 : 20),
                ],
                Expanded(child: identity),
              ],
            );
    },
  );

  Widget _linkSettings({bool compact = false, bool linkFirst = false}) {
    final permission = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          Text(
            '초대받는 멤버의 권한',
            style: ExperienceFormStyle.text(context, 12, secondary: true),
          ),
          const SizedBox(height: 6),
        ],
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: compact,
          title: Text(
            '편집 권한 허용',
            style: ExperienceFormStyle.text(
              context,
              15,
              weight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            _allowEditing
                ? '사진과 문구를 함께 편집할 수 있어요.'
                : '앨범을 감상할 수 있고, 내용은 수정할 수 없어요.',
            style: ExperienceFormStyle.text(context, 13, secondary: true),
          ),
          value: _allowEditing,
          onChanged: _busy
              ? null
              : (value) {
                  setState(() => _allowEditing = value);
                  _createInviteLink();
                },
          activeTrackColor: kIsWeb
              ? WebPalette.of(context).brand
              : ExperienceStyle.accent,
        ),
      ],
    );
    final link = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '초대 링크',
          style: ExperienceFormStyle.text(context, 14, weight: FontWeight.w600),
        ),
        SizedBox(height: compact ? 6 : 10),
        Semantics(
          liveRegion: true,
          child: Container(
            key: const ValueKey('inviteLinkSurface'),
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            decoration: BoxDecoration(
              color: ExperienceFormStyle.surface(context),
              borderRadius: BorderRadius.circular(SnapFitRadius.lg),
              border: Border.all(color: ExperienceFormStyle.line(context)),
            ),
            child: Row(
              children: [
                if (_inviteError == null) ...[
                  _isCreatingInvite
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : ExperienceIcon(
                          'Link2',
                          size: 18,
                          color: ExperienceFormStyle.muted(context),
                        ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: _isCreatingInvite
                      ? Text(
                          '초대 링크를 만드는 중',
                          style: ExperienceFormStyle.text(
                            context,
                            13,
                            secondary: true,
                          ),
                        )
                      : _inviteError != null
                      ? Text(
                          _inviteError!,
                          style: ExperienceFormStyle.text(context, 13),
                        )
                      : SelectableText(
                          _inviteLink ?? '초대 링크 준비 중',
                          style: ExperienceFormStyle.text(context, 13),
                        ),
                ),
                if (_inviteError != null) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: '초대 링크 다시 만들기',
                    onPressed: _busy ? null : _createInviteLink,
                    icon: const ExperienceIcon('RefreshCw', size: 20),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!linkFirst) ...[
          permission,
          SizedBox(height: compact ? 6 : 16),
          Divider(color: ExperienceFormStyle.line(context), height: 1),
          SizedBox(height: compact ? 8 : 20),
        ],
        link,
        if (linkFirst) ...[
          const SizedBox(height: 12),
          Divider(color: ExperienceFormStyle.line(context), height: 1),
          const SizedBox(height: 8),
          permission,
        ],
        const SizedBox(height: 12),
        Text(
          '링크를 받은 사람이 앨범에 참여할 수 있어요. 믿을 수 있는 사람에게만 공유해주세요.',
          style: ExperienceFormStyle.text(context, 12, secondary: true),
        ),
        const SizedBox(height: 8),
        Text(
          '권한을 바꾸면 새 링크를 만들어요. 이미 보낸 링크의 권한은 바뀌지 않아요.',
          style: ExperienceFormStyle.text(context, 12, secondary: true),
        ),
      ],
    );
  }

  Widget _actions() {
    final enabled = !_busy && _inviteLink != null;
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final buttonStyle = ExperienceFormStyle.primary(context).copyWith(
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 14, vertical: landscape ? 8 : 12),
      ),
    );
    final copy = Tooltip(
      message: '링크 복사하기',
      child: OutlinedButton.icon(
        key: const ValueKey('inviteCopy'),
        onPressed: enabled ? _copyInviteLink : null,
        style: buttonStyle.copyWith(
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? ExperienceFormStyle.muted(context)
                : ExperienceFormStyle.ink(context),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: ExperienceFormStyle.line(context)),
          ),
        ),
        icon: _isCopying
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : ExperienceIcon(
                _copied ? 'Check' : 'Copy',
                size: 18,
                color: enabled
                    ? ExperienceFormStyle.ink(context)
                    : ExperienceFormStyle.muted(context),
              ),
        label: Text(
          _isCopying
              ? '복사 중'
              : _copied
              ? '링크 복사 완료'
              : '링크 복사',
          textAlign: TextAlign.center,
        ),
      ),
    );
    final share = FilledButton.icon(
      key: const ValueKey('inviteShare'),
      onPressed: enabled ? _inviteViaKakaoTalk : null,
      style: buttonStyle.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? ExperienceFormStyle.surface(context)
              : const Color(0xFFFEE500),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? ExperienceFormStyle.muted(context)
              : const Color(0xFF302B16),
        ),
      ),
      icon: _isSharing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : ExperienceIcon(
              'MessageCircle',
              size: 19,
              color: enabled
                  ? const Color(0xFF302B16)
                  : ExperienceFormStyle.muted(context),
            ),
      label: Text(
        _isSharing ? '카카오톡 여는 중' : '카카오톡으로 초대',
        textAlign: TextAlign.center,
      ),
    );
    return Container(
      key: const ValueKey('inviteActions'),
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: landscape ? 8 : 16,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: ExperienceFormStyle.line(context)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final row = constraints.maxWidth >= 480;
          return row
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: copy),
                      const SizedBox(width: 12),
                      Expanded(child: share),
                    ],
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [share, const SizedBox(height: 10), copy],
                );
        },
      ),
    );
  }

  Future<void> _createInviteLink() async {
    if (_busy) return;
    // One issued link belongs to one permission; never reuse a stale role.
    final role = _allowEditing ? 'EDITOR' : 'VIEWER';
    setState(() {
      _isCreatingInvite = true;
      _inviteLink = null;
      _inviteError = null;
      _copied = false;
    });
    try {
      final response = await ref
          .read(albumMemberRepositoryProvider)
          .invite(widget.albumId, role: role);
      if (!mounted) return;
      if (response.albumId != widget.albumId) {
        throw const FormatException('Invite album mismatch');
      }
      final link = AlbumInviteService.normalizeInviteLink(response.link);
      setState(() => _inviteLink = link);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _inviteError = AlbumInviteService.inviteErrorMessage(error),
      );
    } finally {
      if (mounted) setState(() => _isCreatingInvite = false);
    }
  }

  Future<void> _inviteViaKakaoTalk() async {
    final link = _inviteLink;
    if (_busy || link == null) return;
    setState(() => _isSharing = true);
    try {
      final success = await AlbumInviteService.inviteViaKakaoTalk(
        ref: ref,
        albumId: widget.albumId,
        albumTitle: widget.albumTitle,
        allowEditing: _allowEditing,
        inviteLink: link,
        context: context,
      );
      if (!mounted || !success) return;
      _showMessage('카카오톡 공유 화면을 열었어요.');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _copyInviteLink() async {
    final link = _inviteLink;
    if (_busy || link == null) return;
    setState(() => _isCopying = true);
    try {
      await Clipboard.setData(ClipboardData(text: link));
      if (!mounted) return;
      setState(() => _copied = true);
      _showMessage('초대 링크를 복사했어요.');
    } catch (_) {
      if (!mounted) return;
      _showMessage('링크를 복사하지 못했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isCopying = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
