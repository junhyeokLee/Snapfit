import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/theme/snapfit_design_tokens.dart' show SnapFitRadius;
import '../../../../core/utils/app_error_mapper.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/web/web_design.dart';
import '../../../auth/data/dto/auth_response.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../domain/order_visibility_owner.dart';
import '../widgets/customer_web_page.dart';

enum AccountSettingsResult { signedOut, deleted }

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key, this.onChangePhoto});

  final Future<void> Function(BuildContext, WidgetRef, UserInfo)? onChangePhoto;

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  bool _busy = false;
  bool _confirmingSessionAction = false;

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool _sameAccount(UserInfo user) =>
      ref.read(authViewModelProvider).asData?.value?.id == user.id &&
      (!kIsWeb || ref.read(visibleOrderOwnerProvider) == user.id);

  Future<bool?> _showAccountAction(Widget child) {
    if (kIsWeb) {
      final owner = ref.read(visibleOrderOwnerProvider);
      if (owner == null) return Future.value(false);
      return showDialog<bool>(
        context: context,
        builder: (_) => Consumer(
          builder: (dialogContext, dialogRef, _) => Dialog(
            backgroundColor: WebPalette.of(context).surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: dialogRef.watch(visibleOrderOwnerProvider) == owner
                  ? child
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('로그인 계정이 변경되었어요. 이 창을 닫아주세요.'),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('닫기'),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      );
    }
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 760),
      backgroundColor: SnapFitColors.backgroundOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SnapFitRadius.lg),
        ),
      ),
      builder: (_) => child,
    );
  }

  Future<bool> _confirm(UserInfo user, {bool delete = false}) async {
    FocusScope.of(context).unfocus();
    final confirmed = await _showAccountAction(
      _AccountConfirmation(user: user, delete: delete),
    );
    if (!mounted || confirmed != true) return false;
    if (!_sameAccount(user)) {
      _message('로그인 계정이 변경되었어요. 다시 확인해 주세요.');
      return false;
    }
    return true;
  }

  Future<void> _endSession(UserInfo user, {bool delete = false}) async {
    if (_busy || _confirmingSessionAction) return;
    _confirmingSessionAction = true;
    var confirmed = false;
    try {
      confirmed = await _confirm(user, delete: delete);
    } finally {
      _confirmingSessionAction = false;
    }
    if (!confirmed || !mounted || !_sameAccount(user)) return;
    setState(() => _busy = true);
    try {
      final auth = ref.read(authViewModelProvider.notifier);
      if (delete) {
        final result = await auth.requestAccountDeletion();
        if (mounted && _sameAccount(user)) {
          _message(
            '${result.alreadyRequested ? '이미 접수한 삭제 요청이 있어요.' : '삭제 요청을 접수했어요.'} '
            '접수번호 ${result.reference}\n담당자 확인 후 처리합니다. 지금 계정·사진은 삭제되지 않았고 로그인도 유지됩니다.',
          );
        }
        return;
      } else {
        await auth.logout();
      }
      if (mounted) {
        Navigator.pop(context, AccountSettingsResult.signedOut);
      }
    } catch (error) {
      _message(AppErrorMapper.toUserMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword(UserInfo user) async {
    final email = user.email?.trim() ?? '';
    if (_busy || email.isEmpty) return;
    FocusScope.of(context).unfocus();
    final send = await _showAccountAction(
      _AccountActionSheet(
        title: '비밀번호 재설정',
        confirmLabel: '재설정 메일 보내기',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(
              email,
              style: ExperienceFormStyle.text(
                context,
                14,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '이메일로 재설정 링크를 보내드려요. 메일의 링크를 열어 새 비밀번호를 설정해 주세요.',
              style: ExperienceFormStyle.text(context, 14, secondary: true),
            ),
          ],
        ),
      ),
    );
    if (!mounted || send != true) return;
    if (!_sameAccount(user)) {
      _message('로그인 계정이 변경되었어요. 다시 확인해 주세요.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(authViewModelProvider.notifier)
          .requestPasswordReset(email);
      _message('재설정 메일을 보냈어요. 받은편지함과 스팸함을 확인해 주세요.');
    } catch (error) {
      _message(AppErrorMapper.toUserMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePhoto(UserInfo user) async {
    if (_busy || widget.onChangePhoto == null) return;
    setState(() => _busy = true);
    try {
      await widget.onChangePhoto!(context, ref, user);
    } catch (error) {
      _message(AppErrorMapper.toUserMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authViewModelProvider).asData?.value;
    final provider = user?.provider.toUpperCase() ?? '';
    final email = user?.email?.trim() ?? '';
    final photo = user?.profileImageUrl?.trim() ?? '';
    final compact = MediaQuery.orientationOf(context) == Orientation.landscape;
    final providerLabel = switch (provider) {
      'EMAIL' => '이메일',
      'GOOGLE' => 'Google',
      'KAKAO' => '카카오',
      'APPLE' => 'Apple',
      _ => '로그인 계정',
    };
    if (kIsWeb) return _webSettings(user, providerLabel);
    final avatar = ClipOval(
      child: SizedBox(
        width: compact ? 48 : 64,
        height: compact ? 48 : 64,
        child: ColoredBox(
          color: ExperienceFormStyle.selection(context),
          child: photo.isEmpty
              ? Icon(
                  Icons.person_outline,
                  size: 30,
                  color: ExperienceFormStyle.selectionInk(context),
                )
              : Image.network(
                  photo,
                  fit: BoxFit.cover,
                  cacheWidth: 192,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.person_outline, size: 30),
                ),
        ),
      ),
    );
    final stackedProfile =
        compact ||
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(16) > 22.4;
    final profileName = SelectableText(
      user?.name ?? '로그인이 필요해요',
      key: const ValueKey('accountProfileName'),
      style: ExperienceFormStyle.text(
        context,
        compact ? 18 : 20,
        weight: FontWeight.w700,
      ),
    );
    final photoAction = user != null && widget.onChangePhoto != null
        ? IconButton(
            tooltip: '프로필 사진 변경',
            onPressed: () => _changePhoto(user),
            icon: Icon(
              Icons.photo_camera_outlined,
              color: ExperienceFormStyle.ink(context),
            ),
          )
        : null;
    final profile = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(context, '프로필'),
        SizedBox(height: compact ? 12 : 20),
        Row(
          children: [
            avatar,
            if (stackedProfile)
              const Spacer()
            else ...[
              const SizedBox(width: 16),
              Expanded(child: profileName),
            ],
            if (photoAction != null) photoAction,
          ],
        ),
        if (stackedProfile) ...[const SizedBox(height: 12), profileName],
        SizedBox(height: compact ? 12 : 24),
        _info(
          context,
          '이메일',
          email.isEmpty ? '이메일 미제공' : email,
          selectable: true,
        ),
        _info(context, '로그인 방식', providerLabel),
      ],
    );
    final security = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(context, '계정 관리'),
        const SizedBox(height: 8),
        if (user != null && provider == 'EMAIL' && email.isNotEmpty)
          ExperienceRow(
            themeAware: true,
            icon: Icons.key_outlined,
            title: '비밀번호 재설정',
            subtitle: '로그인 이메일로 재설정 링크 받기',
            onTap: () => _resetPassword(user),
          ),
        if (user != null && provider != 'EMAIL')
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '$providerLabel 계정의 비밀번호는 해당 서비스에서 관리해 주세요.',
              style: ExperienceFormStyle.text(context, 13, secondary: true),
            ),
          ),
        if (user != null) ...[
          ExperienceRow(
            themeAware: true,
            icon: Icons.logout_outlined,
            title: '로그아웃',
            subtitle: '앨범과 구매한 항목은 계정에 보관돼요',
            onTap: () => _endSession(user),
          ),
          const SizedBox(height: 24),
          Divider(color: ExperienceFormStyle.line(context)),
          const SizedBox(height: 12),
          _section(context, '계정·개인정보 삭제 요청'),
          const SizedBox(height: 8),
          Text(
            '삭제 요청을 접수하면 담당자 확인 후 처리해요. 접수 즉시 계정이나 사진이 삭제되지는 않아요.',
            key: const ValueKey('account-delete-guidance'),
            style: ExperienceFormStyle.text(context, 13, secondary: true),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _endSession(user, delete: true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                minimumSize: const Size(0, 48),
              ),
              child: const Text('회원 탈퇴'),
            ),
          ),
        ],
      ],
    );
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: SnapFitColors.backgroundOf(context),
        appBar: ExperienceHeader(
          title: '계정 설정',
          themeAware: true,
          showNotifications: false,
          onBack: _busy ? () {} : () => Navigator.maybePop(context),
        ),
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              AbsorbPointer(
                absorbing: _busy,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 540 && compact;
                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: wide ? 1040 : 640,
                        ),
                        child: wide
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(
                                      width: (constraints.maxWidth * .4).clamp(
                                        200,
                                        340,
                                      ),
                                      child: SingleChildScrollView(
                                        key: const PageStorageKey(
                                          'account-profile',
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        child: profile,
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
                                        key: const PageStorageKey(
                                          'account-actions',
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        child: security,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : SingleChildScrollView(
                                key: const PageStorageKey('account-actions'),
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  24,
                                  24,
                                  28,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    profile,
                                    const SizedBox(height: 32),
                                    security,
                                  ],
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ),
              if (_busy)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _webSettings(UserInfo? user, String providerLabel) {
    if (user == null || ref.watch(visibleOrderOwnerProvider) != user.id) {
      return const CustomerWebPage(
        title: '계정 설정',
        eyebrow: 'ACCOUNT',
        showNavigation: false,
        child: Center(child: Text('로그인 계정을 확인하고 계정 설정을 다시 열어주세요.')),
      );
    }
    final photo = user.profileImageUrl;
    return PopScope(
      canPop: !_busy,
      child: SnapFitWebShell(
        title: '계정 설정',
        section: WebSection.account,
        showNavigation: false,
        actions: [
          OutlinedButton.icon(
            onPressed: _busy ? null : () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('계정'),
          ),
        ],
        child: AbsorbPointer(
          absorbing: _busy,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const WebPageHeading(
                  title: '프로필과 보안',
                  description: '로그인 정보와 계정 보안 설정을 확인하세요.',
                ),
                const SizedBox(height: 24),
                if (_busy) const LinearProgressIndicator(minHeight: 2),
                LayoutBuilder(
                  builder: (context, bounds) {
                    final profile = WebSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '프로필',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: WebPalette.of(context).ink,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 72,
                                  height: 72,
                                  child: photo != null && photo.isNotEmpty
                                      ? Image.network(
                                          photo,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              ColoredBox(
                                                color: WebPalette.of(
                                                  context,
                                                ).softBrand,
                                                child: Icon(
                                                  Icons.person_outline,
                                                  color: WebPalette.of(
                                                    context,
                                                  ).brandInk,
                                                ),
                                              ),
                                        )
                                      : ColoredBox(
                                          color: WebPalette.of(
                                            context,
                                          ).softBrand,
                                          child: Icon(
                                            Icons.person_outline,
                                            color: WebPalette.of(
                                              context,
                                            ).brandInk,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Text(
                                  user.name,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: WebPalette.of(context).ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (widget.onChangePhoto != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => _changePhoto(user),
                                icon: const Icon(
                                  Icons.photo_camera_outlined,
                                  size: 18,
                                ),
                                label: const Text('프로필 사진 변경'),
                              ),
                            ),
                          const SizedBox(height: 20),
                          Divider(color: WebPalette.of(context).line),
                          const SizedBox(height: 20),
                          Text(
                            '로그인 이메일',
                            style: TextStyle(
                              fontSize: 12,
                              color: WebPalette.of(context).muted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            user.email?.isNotEmpty == true
                                ? user.email!
                                : '이메일 미제공',
                            style: TextStyle(
                              fontSize: 14,
                              color: WebPalette.of(context).ink,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '로그인 방식',
                            style: TextStyle(
                              fontSize: 12,
                              color: WebPalette.of(context).muted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            providerLabel,
                            style: TextStyle(
                              fontSize: 14,
                              color: WebPalette.of(context).ink,
                            ),
                          ),
                        ],
                      ),
                    );
                    final management = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        WebSurface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '로그인과 보안',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: WebPalette.of(context).ink,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                user.provider.toUpperCase() == 'EMAIL'
                                    ? '비밀번호를 변경하려면 로그인 이메일로 재설정 링크를 받아주세요.'
                                    : '$providerLabel 계정의 비밀번호는 해당 서비스에서 관리합니다.',
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.7,
                                  color: WebPalette.of(context).muted,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  if (user.provider.toUpperCase() == 'EMAIL' &&
                                      user.email?.isNotEmpty == true)
                                    OutlinedButton.icon(
                                      onPressed: () => _resetPassword(user),
                                      icon: const Icon(
                                        Icons.key_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('비밀번호 재설정'),
                                    ),
                                  OutlinedButton.icon(
                                    onPressed: () => _endSession(user),
                                    icon: const Icon(
                                      Icons.logout_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('로그아웃'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        WebSurface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '계정·개인정보 삭제 요청',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: WebPalette.of(context).ink,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '삭제 요청을 접수하면 담당자가 본인 확인과 보관 의무·공유 자료를 검토한 뒤 처리합니다. 접수 즉시 계정이나 사진이 삭제되지는 않아요. 문의: junhyeoklee616@gmail.com',
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.7,
                                  color: WebPalette.of(context).muted,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () =>
                                    _endSession(user, delete: true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.error,
                                ),
                                child: const Text('회원 탈퇴'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                    return bounds.maxWidth >= 900
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: profile),
                              const SizedBox(width: 24),
                              Expanded(flex: 3, child: management),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              profile,
                              const SizedBox(height: 24),
                              management,
                            ],
                          );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Text(
    title,
    style: ExperienceFormStyle.text(
      context,
      12,
      weight: FontWeight.w600,
      secondary: true,
    ),
  );

  Widget _info(
    BuildContext context,
    String label,
    String value, {
    bool selectable = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ExperienceFormStyle.text(context, 12, secondary: true),
        ),
        const SizedBox(height: 4),
        if (selectable)
          SelectableText(value, style: ExperienceFormStyle.text(context, 14))
        else
          Text(value, style: ExperienceFormStyle.text(context, 14)),
      ],
    ),
  );
}

class _AccountConfirmation extends StatefulWidget {
  const _AccountConfirmation({required this.user, required this.delete});
  final UserInfo user;
  final bool delete;

  @override
  State<_AccountConfirmation> createState() => _AccountConfirmationState();
}

class _AccountConfirmationState extends State<_AccountConfirmation> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) => _AccountActionSheet(
    title: widget.delete ? '계정·개인정보 삭제를 요청할까요?' : '로그아웃할까요?',
    confirmLabel: widget.delete ? '삭제 요청 접수' : '로그아웃',
    destructive: widget.delete,
    canConfirm: () => !widget.delete || _acknowledged,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectableText(
          widget.user.email ?? widget.user.name,
          style: ExperienceFormStyle.text(context, 14, weight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Text(
          widget.delete
              ? '담당자가 요청을 확인한 뒤 삭제 범위와 보관이 필요한 기록을 안내합니다. '
                    '이 단계에서는 계정·앨범·사진·거래 기록을 삭제하지 않고 로그인을 유지해요. '
                    '문의: junhyeoklee616@gmail.com'
              : '다시 로그인하면 저장한 앨범과 구매한 템플릿·소재를 이어서 사용할 수 있어요.',
          style: ExperienceFormStyle.text(context, 14, secondary: true),
        ),
        if (widget.delete) ...[
          const SizedBox(height: 12),
          CheckboxListTile(
            key: const ValueKey('account-delete-acknowledgement'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _acknowledged,
            onChanged: (value) =>
                setState(() => _acknowledged = value ?? false),
            title: Text(
              '즉시 삭제가 아닌 검토 요청 접수임을 확인했어요',
              style: ExperienceFormStyle.text(context, 13),
            ),
          ),
        ],
      ],
    ),
  );
}

class _AccountActionSheet extends StatefulWidget {
  const _AccountActionSheet({
    required this.title,
    required this.confirmLabel,
    required this.child,
    this.destructive = false,
    this.canConfirm,
  });
  final String title, confirmLabel;
  final Widget child;
  final bool destructive;
  final bool Function()? canConfirm;

  @override
  State<_AccountActionSheet> createState() => _AccountActionSheetState();
}

class _AccountActionSheetState extends State<_AccountActionSheet> {
  bool _finishing = false;

  void _finish(bool confirmed) {
    if (!mounted ||
        _finishing ||
        ModalRoute.of(context)?.isCurrent != true ||
        confirmed && !(widget.canConfirm?.call() ?? true))
      return;
    setState(() => _finishing = true);
    Navigator.pop(context, confirmed);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: LayoutBuilder(
        builder: (context, bounds) {
          final available = bounds.hasBoundedHeight
              ? bounds.maxHeight
              : MediaQuery.sizeOf(context).height;
          final compact = available < 400;
          final primary = ExperienceFormStyle.primary(context);
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: available * .94),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    compact ? 4 : 12,
                    12,
                    compact ? 4 : 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: ExperienceFormStyle.text(
                            context,
                            compact ? 18 : 20,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        key: const ValueKey('account-sheet-close'),
                        tooltip: '닫기',
                        onPressed: _finishing ? null : () => _finish(false),
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    key: const PageStorageKey('account-confirmation-content'),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: widget.child,
                  ),
                ),
                Divider(height: 1, color: ExperienceFormStyle.line(context)),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    compact ? 4 : 12,
                    20,
                    compact ? 4 : 12,
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: TextButton(
                            key: const ValueKey('account-sheet-cancel'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              textStyle: ExperienceFormStyle.text(context, 14),
                              foregroundColor: ExperienceFormStyle.ink(context),
                            ),
                            onPressed: _finishing ? null : () => _finish(false),
                            child: const Text('취소'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            key: const ValueKey('account-sheet-primary'),
                            onPressed:
                                _finishing ||
                                    !(widget.canConfirm?.call() ?? true)
                                ? null
                                : () => _finish(true),
                            style: widget.destructive
                                ? primary.copyWith(
                                    backgroundColor:
                                        WidgetStateProperty.resolveWith(
                                          (states) =>
                                              states.contains(
                                                WidgetState.disabled,
                                              )
                                              ? ExperienceFormStyle.surface(
                                                  context,
                                                )
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.error,
                                        ),
                                    foregroundColor:
                                        WidgetStateProperty.resolveWith(
                                          (states) =>
                                              states.contains(
                                                WidgetState.disabled,
                                              )
                                              ? ExperienceFormStyle.muted(
                                                  context,
                                                )
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.onError,
                                        ),
                                  )
                                : primary,
                            child: Text(
                              widget.confirmLabel,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
