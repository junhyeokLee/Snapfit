import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/web/web_design.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../auth/data/dto/auth_response.dart';
import '../../../auth/presentation/views/login_screen.dart';
import '../../data/api/album_provider.dart';
import '../../data/dto/response/invite_info_response.dart';
import '../../domain/entities/album.dart';
import '../../service/album_invite_failure.dart';
import '../../service/pending_album_invite.dart';
import '../viewmodels/home_view_model.dart';
import '../widgets/home/home_album_actions.dart';

final albumInviteInfoProvider = FutureProvider.autoDispose
    .family<InviteInfoResponse, String>((ref, token) async {
      final info = await ref
          .read(albumMemberRepositoryProvider)
          .getInviteInfo(token);
      if (info.albumId <= 0 || !['EDITOR', 'VIEWER'].contains(info.role)) {
        throw const FormatException('Invalid invitation');
      }
      return info;
    }, retry: (_, __) => null);

typedef InvitedAlbumOpen =
    Future<void> Function(BuildContext context, WidgetRef ref, Album album);
final invitedAlbumOpenProvider = Provider<InvitedAlbumOpen>(
  (_) =>
      (context, ref, album) => HomeAlbumActions.openAlbum(context, ref, album),
);

class AlbumInviteAcceptScreen extends ConsumerStatefulWidget {
  const AlbumInviteAcceptScreen({super.key, required this.invite});
  final PendingAlbumInvite invite;
  @override
  ConsumerState<AlbumInviteAcceptScreen> createState() =>
      _AlbumInviteAcceptScreenState();
}

class _AlbumInviteAcceptScreenState
    extends ConsumerState<AlbumInviteAcceptScreen> {
  bool _loginRequested = false;
  bool _busy = false;
  int? _acceptedId;
  String? _acceptedUserId;
  String? _acceptedRole;
  AlbumInviteFailure? _failure;
  String? _openError;

  Future<void> _accept(InviteInfoResponse info) async {
    if (_busy) return;
    final user = ref.read(authViewModelProvider).asData?.value;
    if (user == null) {
      setState(() => _loginRequested = true);
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final accepted = await ref
          .read(albumMemberRepositoryProvider)
          .acceptInvite(widget.invite.token);
      if (!mounted) return;
      if (ref.read(authViewModelProvider).asData?.value?.id != user.id) {
        setState(
          () => _failure = const AlbumInviteFailure(
            '계정이 변경되었어요',
            '현재 계정으로 초대를 다시 확인해 주세요.',
          ),
        );
        return;
      }
      if (!accepted.success ||
          accepted.albumId != info.albumId ||
          !['OWNER', 'EDITOR', 'VIEWER'].contains(accepted.role)) {
        throw const FormatException('Invalid acceptance');
      }
      setState(() {
        _acceptedId = accepted.albumId;
        _acceptedUserId = user.id;
        _acceptedRole = accepted.role;
      });
      ref
          .read(pendingAlbumInviteProvider.notifier)
          .clearIfCurrent(widget.invite);
      ref.invalidate(homeViewModelProvider);
    } catch (error) {
      if (mounted)
        setState(() {
          _failure = AlbumInviteFailure.from(error);
          if (_failure!.needsLogin) _loginRequested = true;
        });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAlbum() async {
    if (_busy || _acceptedId == null) return;
    final userId = ref.read(authViewModelProvider).asData?.value?.id;
    if (userId == null || userId != _acceptedUserId) return;
    setState(() {
      _busy = true;
      _openError = null;
    });
    try {
      final album = await ref
          .read(albumRepositoryProvider)
          .fetchAlbum('$_acceptedId');
      if (!mounted ||
          ref.read(authViewModelProvider).asData?.value?.id != userId)
        return;
      if (album.id != _acceptedId) throw const FormatException('Invalid album');
      await ref.read(invitedAlbumOpenProvider)(context, ref, album);
    } catch (_) {
      if (mounted)
        setState(
          () => _openError = '참여는 완료되었어요. 앨범을 불러오지 못했으니 다시 열거나 홈에서 확인해 주세요.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authViewModelProvider, (_, next) {
      if (_loginRequested &&
          next.hasValue &&
          next.asData?.value != null &&
          !next.isLoading) {
        setState(() => _loginRequested = false);
      }
    });
    final auth = ref.watch(authViewModelProvider);
    final user = auth.asData?.value;
    if (_loginRequested) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _loginRequested = false);
        },
        child: kIsWeb ? Column(
          children: [
            Container(
              width: double.infinity,
              color: WebPalette.of(context).surface,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Wrap(
                spacing: 20,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _loginRequested = false),
                    icon: const Icon(Icons.arrow_back, size: 17),
                    label: const Text('초대로 돌아가기'),
                  ),
                  Text('로그인 후 같은 초대에서 참여를 계속할 수 있습니다.',
                    style: TextStyle(color: WebPalette.of(context).muted, fontSize: 12)),
                ],
              ),
            ),
            const Expanded(child: LoginScreen()),
          ],
        ) : Scaffold(
          appBar: ExperienceHeader(
            title: '초대에 참여하기',
            showNotifications: false,
            onBack: () => setState(() => _loginRequested = false),
          ),
          body: const LoginScreen(),
        ),
      );
    }
    final invite = ref.watch(albumInviteInfoProvider(widget.invite.token));
    final joined = _acceptedId != null && user?.id == _acceptedUserId;
    final failure = joined ? null : _failure;
    final previewFailure = invite.hasError
        ? AlbumInviteFailure.from(invite.error!)
        : null;
    final terminal =
        !joined &&
        (failure?.retryable == false || previewFailure?.retryable == false);
    final canAct =
        !_busy &&
        !auth.isLoading &&
        (terminal ||
            joined ||
            (!invite.isLoading &&
                invite.hasValue &&
                failure?.retryable != false));
    return PopScope(
      canPop: !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop)
          ref
              .read(pendingAlbumInviteProvider.notifier)
              .clearIfCurrent(widget.invite);
      },
      child: kIsWeb ? _buildWeb(
        invite: invite,
        user: user,
        joined: joined,
        failure: failure,
        terminal: terminal,
        canAct: canAct,
      ) : Scaffold(
        backgroundColor: SnapFitColors.backgroundOf(context),
        appBar: ExperienceHeader(
          title: '앨범 초대',
          showNotifications: false,
          onBack: _busy ? () {} : () => Navigator.of(context).maybePop(),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              key: const ValueKey('inviteAcceptContent'),
              padding: EdgeInsets.symmetric(
                horizontal: box.maxWidth < 360 ? 20 : 28,
                vertical: box.maxHeight < 300 ? 16 : 32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth:
                        box.maxWidth >= 540 &&
                            MediaQuery.orientationOf(context) ==
                                Orientation.landscape
                        ? 960
                        : 680,
                  ),
                  child: invite.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(36),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 20),
                          Text('초대를 확인하고 있어요'),
                        ],
                      ),
                    ),
                    error: (error, _) =>
                        _error(AlbumInviteFailure.from(error), reload: true),
                    data: (info) => _content(
                      info,
                      user,
                      joined,
                      failure,
                      box.maxWidth >= 540 &&
                          MediaQuery.orientationOf(context) ==
                              Orientation.landscape,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.symmetric(horizontal: 20),
          child: Padding(
            padding: EdgeInsets.only(
              top: 8,
              bottom: MediaQuery.orientationOf(context) == Orientation.landscape
                  ? 8
                  : 16,
            ),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final landscape =
                        MediaQuery.orientationOf(context) ==
                        Orientation.landscape;
                    final primary = FilledButton.icon(
                      key: const ValueKey('inviteAcceptAction'),
                      style: ExperienceFormStyle.primary(context).copyWith(
                        padding: WidgetStatePropertyAll(
                          EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: landscape ? 8 : 12,
                          ),
                        ),
                      ),
                      onPressed: canAct
                          ? () => terminal
                                ? Navigator.of(context).maybePop()
                                : joined
                                ? _openAlbum()
                                : _accept(invite.requireValue)
                          : null,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : ExperienceIcon(
                              terminal
                                  ? 'ArrowLeft'
                                  : joined
                                  ? 'BookOpen'
                                  : 'ArrowRight',
                              size: 19,
                              color: canAct
                                  ? const Color(0xFF063740)
                                  : ExperienceFormStyle.muted(context),
                            ),
                      label: Text(
                        _busy
                            ? (joined ? '앨범 불러오는 중' : '참여하는 중')
                            : terminal
                            ? '초대 닫기'
                            : joined
                            ? '앨범 열기'
                            : user == null
                            ? '로그인하고 참여하기'
                            : '초대 수락하기',
                        textAlign: TextAlign.center,
                      ),
                    );
                    final dismiss = !_busy && !terminal
                        ? TextButton(
                            key: const ValueKey('inviteAcceptDismiss'),
                            onPressed: () => Navigator.of(context).maybePop(),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 48),
                            ),
                            child: Text(
                              joined ? '돌아가기' : '초대 닫기',
                              style: ExperienceStyle.text(
                                13,
                                color: SnapFitColors.textSecondaryOf(context),
                              ),
                            ),
                          )
                        : null;
                    if (landscape && box.maxWidth >= 480) {
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (dismiss != null) ...[
                              Expanded(child: dismiss),
                              const SizedBox(width: 12),
                            ],
                            Expanded(flex: 2, child: primary),
                          ],
                        ),
                      );
                    }
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [primary, if (dismiss != null) dismiss],
                      ),
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

  Widget _buildWeb({
    required AsyncValue<InviteInfoResponse> invite,
    required UserInfo? user,
    required bool joined,
    required AlbumInviteFailure? failure,
    required bool terminal,
    required bool canAct,
  }) {
    Widget failureView(AlbumInviteFailure value, {bool reload = false}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(value.title, style: TextStyle(
          color: WebPalette.of(context).ink, fontSize: 18, fontWeight: FontWeight.w700,
        )),
        const SizedBox(height: 10),
        Text(value.message, style: TextStyle(
          color: WebPalette.of(context).muted, fontSize: 14, height: 1.6,
        )),
        if (reload && value.retryable) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => ref.invalidate(
                albumInviteInfoProvider(widget.invite.token),
              ),
              icon: const Icon(Icons.refresh, size: 17),
              label: const Text('초대 다시 확인'),
            ),
          ),
        ],
      ],
    );

    final action = FilledButton.icon(
      key: const ValueKey('inviteAcceptAction'),
      onPressed: canAct ? () {
        if (terminal) {
          Navigator.of(context).maybePop();
        } else if (joined) {
          _openAlbum();
        } else {
          _accept(invite.requireValue);
        }
      } : null,
      icon: _busy ? const SizedBox(
        width: 17, height: 17,
        child: CircularProgressIndicator(strokeWidth: 2),
      ) : Icon(terminal ? Icons.arrow_back
          : joined ? Icons.auto_stories_outlined : Icons.arrow_forward, size: 18),
      label: Text(_busy ? joined ? '앨범을 불러오는 중' : '참여하는 중'
          : terminal ? '초대 닫기'
          : joined ? '앨범 열기'
          : user == null ? '로그인하고 참여하기' : '초대 수락하기'),
    );

    return SnapFitWebShell(
      title: '앨범 초대',
      showNavigation: false,
      actions: [TextButton.icon(
        onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.close, size: 17),
        label: const Text('초대 닫기'),
      )],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WebPageHeading(
              eyebrow: 'ALBUM INVITATION',
              title: joined ? '앨범에 참여했습니다' : '함께 만드는 기록에 초대받았습니다',
              description: joined
                  ? '참여한 계정으로 앨범을 열고 공유된 기록을 확인하세요.'
                  : '초대된 앨범과 참여 권한을 확인한 뒤 수락하세요.',
            ),
            const SizedBox(height: 30),
            invite.when(
              loading: () => const WebSurface(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Row(children: [
                    SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 16), Text('초대를 확인하고 있습니다'),
                  ]),
                ),
              ),
              error: (error, _) => WebSurface(child: failureView(
                AlbumInviteFailure.from(error), reload: true,
              )),
              data: (info) {
                final editable = ['OWNER', 'EDITOR'].contains(
                  joined ? _acceptedRole : info.role,
                );
                final identity = WebSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('${info.inviterName}님의 초대', style: TextStyle(
                        color: WebPalette.of(context).muted, fontSize: 13,
                      )),
                      const SizedBox(height: 14),
                      Text(info.albumTitle,
                        key: const ValueKey('inviteAcceptTitle'),
                        style: TextStyle(color: WebPalette.of(context).ink,
                          fontSize: 26, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 24),
                      Divider(color: WebPalette.of(context).line, height: 1),
                      const SizedBox(height: 22),
                      Text('참여할 계정', style: TextStyle(
                        color: WebPalette.of(context).muted, fontSize: 12,
                      )),
                      const SizedBox(height: 7),
                      Text(user == null ? '로그인이 필요합니다' : user.name,
                        style: TextStyle(color: WebPalette.of(context).ink,
                          fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(user == null
                          ? '로그인을 완료해도 이 초대는 유지됩니다.'
                          : joined ? '내 앨범에서도 다시 열 수 있습니다.'
                          : '수락하면 이 계정의 내 앨범에 추가됩니다.',
                        style: TextStyle(color: WebPalette.of(context).muted,
                          fontSize: 13, height: 1.6)),
                      if (failure != null) ...[
                        const SizedBox(height: 24), failureView(failure),
                      ],
                      if (_openError != null) ...[
                        const SizedBox(height: 22),
                        Text(_openError!, style: TextStyle(
                          color: WebPalette.of(context).muted, fontSize: 13, height: 1.6,
                        )),
                      ],
                    ],
                  ),
                );
                final permissions = WebSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.group_outlined,
                        size: 26, color: WebPalette.of(context).brandInk),
                      const SizedBox(height: 18),
                      Text('참여 권한', style: TextStyle(
                        color: WebPalette.of(context).muted, fontSize: 12,
                      )),
                      const SizedBox(height: 8),
                      Text(editable ? '보기 및 편집' : '보기 전용',
                        style: TextStyle(color: WebPalette.of(context).brandInk,
                          fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Text(editable ? '사진과 글, 페이지 구성을 함께 편집할 수 있습니다.'
                          : '앨범을 볼 수 있으며 편집 권한은 포함되지 않습니다.',
                        style: TextStyle(color: WebPalette.of(context).muted,
                          fontSize: 13, height: 1.6)),
                    ],
                  ),
                );
                return LayoutBuilder(builder: (context, box) {
                  if (box.maxWidth < 850) return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [identity, const SizedBox(height: 20), permissions],
                  );
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Expanded(child: identity),
                      const SizedBox(width: 26),
                      SizedBox(width: 320, child: permissions)],
                  );
                });
              },
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12, runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                action,
                if (!_busy && !terminal)
                  TextButton(
                    key: const ValueKey('inviteAcceptDismiss'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(joined ? '돌아가기' : '나중에 참여하기'),
                  ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _content(
    InviteInfoResponse info,
    UserInfo? user,
    bool joined,
    AlbumInviteFailure? failure,
    bool landscape,
  ) {
    final editable = [
      'OWNER',
      'EDITOR',
    ].contains(joined ? _acceptedRole : info.role);
    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ExperienceIcon(
              joined ? 'Check' : 'BookOpen',
              color: SnapFitColors.accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                joined ? '함께 간직할 앨범' : '${info.inviterName}님의 초대',
                style: ExperienceStyle.text(
                  13,
                  color: SnapFitColors.textSecondaryOf(context),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: landscape ? 14 : 20),
        Text(
          info.albumTitle,
          key: const ValueKey('inviteAcceptTitle'),
          style: ExperienceStyle.text(
            landscape ? 18 : 30,
            weight: FontWeight.w600,
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          joined
              ? '앨범에 참여했어요. 이제 함께한 장면들을 만나보세요.'
              : '소중한 장면을 함께 모으는 공간에 초대받았어요.',
          style: ExperienceStyle.text(
            14,
            color: SnapFitColors.textSecondaryOf(context),
          ),
        ),
      ],
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!landscape) Divider(color: SnapFitColors.overlayMediumOf(context)),
        _detail(
          editable ? '함께 편집' : '앨범 보기',
          editable ? '사진과 페이지를 함께 꾸밀 수 있어요.' : '앨범을 볼 수 있어요. 편집 권한은 포함되지 않아요.',
        ),
        Divider(color: SnapFitColors.overlayMediumOf(context)),
        _detail(
          user == null ? '로그인 후 참여' : '${user.name} 계정으로 참여',
          user == null
              ? '로그인해도 이 초대는 그대로 이어져요.'
              : joined
              ? '내 앨범에서 언제든 다시 볼 수 있어요.'
              : '초대를 수락하면 내 앨범에 추가돼요.',
        ),
        if (failure != null) ...[const SizedBox(height: 20), _error(failure)],
        if (_openError != null) ...[
          const SizedBox(height: 20),
          Text(
            _openError!,
            style: ExperienceStyle.text(
              13,
              color: SnapFitColors.textSecondaryOf(context),
            ),
          ),
        ],
      ],
    );
    if (landscape)
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: intro),
          const SizedBox(width: 24),
          Expanded(child: details),
        ],
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [intro, const SizedBox(height: 28), details],
    );
  }

  Widget _detail(String title, String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: ExperienceStyle.text(
            14,
            weight: FontWeight.w600,
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          style: ExperienceStyle.text(
            13,
            color: SnapFitColors.textSecondaryOf(context),
          ),
        ),
      ],
    ),
  );

  Widget _error(AlbumInviteFailure failure, {bool reload = false}) => Semantics(
    liveRegion: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          failure.title,
          style: ExperienceStyle.text(
            17,
            weight: FontWeight.w600,
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          failure.message,
          style: ExperienceStyle.text(
            13,
            color: SnapFitColors.textSecondaryOf(context),
          ),
        ),
        if (reload && failure.retryable)
          TextButton.icon(
            onPressed: () =>
                ref.invalidate(albumInviteInfoProvider(widget.invite.token)),
            icon: const ExperienceIcon('RefreshCw', size: 18),
            label: const Text('다시 확인하기'),
          ),
      ],
    ),
  );
}
