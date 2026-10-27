import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/navigation/web_app_location.dart';
import '../../../../shared/web/web_design.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/widgets/snapfit_motion.dart';
import '../../../auth/presentation/views/login_screen.dart';
import '../../data/social_profile_photo.dart';
import '../../domain/social_models.dart';
import '../providers/social_providers.dart';
import '../widgets/social_profile_widgets.dart';
import '../widgets/social_web_frame.dart';
import '../widgets/social_widgets.dart';

class SocialProfileEditScreen extends ConsumerStatefulWidget {
  const SocialProfileEditScreen({super.key, this.imagePicker});

  final ImagePicker? imagePicker;

  @override
  ConsumerState<SocialProfileEditScreen> createState() =>
      _SocialProfileEditScreenState();
}

class _SocialProfileEditScreenState
    extends ConsumerState<SocialProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _handle = TextEditingController();
  final _bio = TextEditingController();
  String? _initializedFor;
  bool _saving = false;
  bool _photoBusy = false;
  String? _error;
  String? _photoError;
  SocialProfile? _lastProfile;
  int _revision = 0;
  int _photoRevision = 0;
  DialogRoute<bool>? _photoDialog;

  void _login() {
    final navigate = WebNavigationScope.maybeOf(context)?.onPublicNavigate;
    if (kIsWeb && navigate != null) {
      navigate(WebAppLocation.login);
      return;
    }
    Navigator.of(context).push<void>(
      snapFitRoute(
        page: const LoginScreen(),
        settings: kIsWeb
            ? const WebAppRouteSettings(WebAppLocation.login)
            : null,
      ),
    );
  }

  @override
  void dispose() {
    _revision++;
    _photoRevision++;
    _dismissPhotoDialog();
    _name.dispose();
    _handle.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _initialize(String actor, SocialProfile? profile) {
    if (_initializedFor == actor) return;
    _initializedFor = actor;
    _name.text = profile?.displayName ?? '';
    _handle.text = profile?.handle ?? '';
    _bio.text = profile?.bio ?? '';
  }

  void _invalidateProfile(String actor) {
    ref.invalidate(ownSocialProfileProvider);
    ref.invalidate(socialProfileProvider(actor));
    ref.invalidate(socialRelationsProvider);
    ref.invalidate(socialRelationsPageProvider);
    ref.invalidate(socialFeedProvider);
    ref.invalidate(socialWorkProvider);
    ref.invalidate(socialCommentsProvider);
    ref.invalidate(socialCommentsPageProvider);
    ref.invalidate(socialProfileWorksProvider);
    ref.invalidate(socialProfileWorksPageProvider);
    ref.invalidate(socialOwnWorksProvider);
    ref.invalidate(socialOwnWorksPageProvider);
    ref.invalidate(socialSavedWorksProvider);
    ref.invalidate(socialSavedWorksPageProvider);
  }

  bool _photoIsCurrent(String actor, int revision) =>
      mounted &&
      revision == _photoRevision &&
      _initializedFor == actor &&
      ref.read(socialCurrentUserIdProvider) == actor;

  Future<String?> _freshOwnPhoto() async {
    final actor = ref.read(socialCurrentUserIdProvider);
    final revision = _photoRevision;
    if (actor == null || _initializedFor != actor) return null;
    final fresh = await ref.read(socialRepositoryProvider).fetchProfile(actor);
    if (!_photoIsCurrent(actor, revision) || fresh?.userId != actor)
      return null;
    return fresh?.avatarUrl;
  }

  Future<bool?> _confirmPhoto({required WidgetBuilder builder}) async {
    final route = DialogRoute<bool>(context: context, builder: builder);
    _photoDialog = route;
    try {
      return await Navigator.of(context, rootNavigator: true).push<bool>(route);
    } finally {
      if (_photoDialog == route) _photoDialog = null;
    }
  }

  void _dismissPhotoDialog() {
    final route = _photoDialog;
    _photoDialog = null;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      route.navigator?.removeRoute(route);
    });
  }

  Future<void> _changePhoto() async {
    final actor = ref.read(socialCurrentUserIdProvider);
    if (actor == null || _photoBusy || _saving || _initializedFor != actor)
      return;
    final revision = ++_photoRevision;
    var requested = false;
    setState(() {
      _photoBusy = true;
      _photoError = null;
    });
    try {
      final image = await (widget.imagePicker ?? ImagePicker()).pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        requestFullMetadata: false,
      );
      if (!_photoIsCurrent(actor, revision) || image == null) return;
      if (await image.length() > socialProfilePhotoInputMaxBytes) {
        if (_photoIsCurrent(actor, revision)) {
          setState(() => _photoError = '20MB 이하의 사진을 선택해 주세요.');
        }
        return;
      }
      final bytes = await image.readAsBytes();
      if (!_photoIsCurrent(actor, revision)) return;
      if (bytes.length > socialProfilePhotoInputMaxBytes) {
        setState(() => _photoError = '20MB 이하의 사진을 선택해 주세요.');
        return;
      }
      final preview = await prepareSocialProfilePhoto(bytes);
      if (!_photoIsCurrent(actor, revision)) return;
      final accepted = await _confirmPhoto(
        builder: (context) => AlertDialog(
          title: const Text('이 사진을 공개할까요?'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 240,
                    child: Image.memory(
                      preview,
                      cacheWidth: 768,
                      fit: BoxFit.contain,
                      semanticLabel: '선택한 공개 프로필 사진 전체 미리보기',
                      errorBuilder: (_, _, _) =>
                          const Center(child: Text('사진을 미리 볼 수 없어요.')),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('선택한 사진 전체가 공개 프로필에 표시돼요. 다른 사람이 크게 볼 수 있어요.'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('공개 사진으로 등록'),
            ),
          ],
        ),
      );
      if (!_photoIsCurrent(actor, revision) || accepted != true) return;
      requested = true;
      final profile = await ref
          .read(socialRepositoryProvider)
          .updateOwnPhoto(bytes);
      if (!_photoIsCurrent(actor, revision)) return;
      if (profile.userId == actor) _lastProfile = profile;
      _invalidateProfile(actor);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('공개 프로필 사진을 변경했어요.')));
    } catch (_) {
      if (!_photoIsCurrent(actor, revision)) return;
      _invalidateProfile(actor);
      setState(() {
        _photoError = requested
            ? '사진 변경 결과를 확인하지 못했어요. 다시 확인해 주세요.'
            : '사진을 준비하지 못했어요. 다른 사진을 선택해 주세요.';
      });
    } finally {
      if (_photoIsCurrent(actor, revision)) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto() async {
    final actor = ref.read(socialCurrentUserIdProvider);
    if (actor == null || _photoBusy || _saving || _initializedFor != actor)
      return;
    final revision = ++_photoRevision;
    setState(() {
      _photoBusy = true;
      _photoError = null;
    });
    try {
      final accepted = await _confirmPhoto(
        builder: (context) => AlertDialog(
          title: const Text('공개 프로필 사진을 삭제할까요?'),
          content: const Text('프로필에는 이름의 첫 글자가 표시돼요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('사진 삭제'),
            ),
          ],
        ),
      );
      if (!_photoIsCurrent(actor, revision) || accepted != true) return;
      final profile = await ref.read(socialRepositoryProvider).removeOwnPhoto();
      if (!_photoIsCurrent(actor, revision)) return;
      if (profile.userId == actor) _lastProfile = profile;
      _invalidateProfile(actor);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('공개 프로필 사진을 삭제했어요.')));
    } catch (_) {
      if (!_photoIsCurrent(actor, revision)) return;
      _invalidateProfile(actor);
      setState(() => _photoError = '사진 삭제 결과를 확인하지 못했어요. 다시 확인해 주세요.');
    } finally {
      if (_photoIsCurrent(actor, revision)) setState(() => _photoBusy = false);
    }
  }

  Future<void> _save() async {
    final actor = ref.read(socialCurrentUserIdProvider);
    if (actor == null || _saving || _photoBusy || _initializedFor != actor)
      return;
    if (_formKey.currentState?.validate() != true) return;
    final revision = ++_revision;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(socialRepositoryProvider)
          .upsertOwnProfile(
            displayName: _name.text.trim(),
            handle: _handle.text.trim().toLowerCase(),
            bio: _bio.text.trim(),
          );
      if (!mounted ||
          revision != _revision ||
          ref.read(socialCurrentUserIdProvider) != actor)
        return;
      _invalidateProfile(actor);
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('공개 프로필을 저장했어요.')));
      if (Navigator.canPop(context)) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted ||
          revision != _revision ||
          ref.read(socialCurrentUserIdProvider) != actor)
        return;
      setState(() {
        _saving = false;
        _error = '저장하지 못했어요. 아이디 중복이나 연결 상태를 확인하고 다시 시도해 주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(socialCurrentUserIdProvider);
    ref.listen<String?>(socialCurrentUserIdProvider, (previous, next) {
      if (previous == next) return;
      _revision++;
      _photoRevision++;
      _dismissPhotoDialog();
      _initializedFor = null;
      _lastProfile = null;
      _saving = false;
      _photoBusy = false;
      _error = null;
      _photoError = null;
      _name.clear();
      _handle.clear();
      _bio.clear();
    });
    final profile = actor == null ? null : ref.watch(ownSocialProfileProvider);
    return SocialWebFrame(
      section: WebSection.myProfile,
      child: PopScope(
        canPop: !_saving && !_photoBusy,
        child: Scaffold(
          appBar: const ExperienceHeader(
            title: '프로필 수정',
            showNotifications: false,
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: SocialProfileContent(
                maxWidth: 600,
                child: actor == null
                    ? SocialProfileStatePanel(
                        title: '로그인이 필요해요.',
                        message: '다시 로그인한 뒤 공개 프로필을 수정해 주세요.',
                        action: FilledButton(
                          style: SocialStyle.primary(context),
                          onPressed: _login,
                          child: const Text('로그인'),
                        ),
                      )
                    : _profileContent(actor, profile!),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileContent(String actor, AsyncValue<SocialProfile?> profile) {
    final data = profile.asData;
    if (data != null && (data.value == null || data.value!.userId == actor)) {
      _initialize(actor, data.value);
      _lastProfile = data.value;
    }
    if (_initializedFor == actor) {
      return _form(_lastProfile, refreshError: profile.hasError);
    }
    if (profile.hasError) {
      return SocialProfileStatePanel(
        title: '프로필을 불러오지 못했어요.',
        message: '연결 상태를 확인한 뒤 다시 시도해 주세요.',
        action: OutlinedButton(
          onPressed: () => ref.invalidate(ownSocialProfileProvider),
          child: const Text('다시 시도'),
        ),
      );
    }
    return const SocialProfileStatePanel(
      title: '프로필을 불러오고 있어요.',
      message: '잠시만 기다려 주세요.',
      loading: true,
    );
  }

  Widget _form(SocialProfile? profile, {bool refreshError = false}) => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SocialProfileAvatar(
            name: profile?.displayName ?? '나',
            imageUrl: profile?.avatarUrl,
            size: 120,
            expandable: true,
            refreshImageUrl: _freshOwnPhoto,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton(
              key: const ValueKey('social-profile-change-photo'),
              onPressed: _photoBusy || _saving ? null : _changePhoto,
              child: Text(_photoBusy ? '사진 확인 중…' : '사진 변경'),
            ),
            if (profile?.avatarUrl?.isNotEmpty == true ||
                profile?.avatarPath?.isNotEmpty == true)
              TextButton(
                key: const ValueKey('social-profile-remove-photo'),
                onPressed: _photoBusy || _saving ? null : _removePhoto,
                child: const Text('사진 삭제'),
              ),
          ],
        ),
        if (_photoError != null)
          Semantics(
            liveRegion: true,
            child: Text(
              _photoError!,
              style: ExperienceFormStyle.text(
                context,
                13,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        if (refreshError)
          TextButton.icon(
            onPressed: _photoBusy
                ? null
                : () => ref.invalidate(ownSocialProfileProvider),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('프로필 다시 확인'),
          ),
        const SizedBox(height: 26),
        Text(
          '다른 사람에게 보일 나의 소개',
          style: ExperienceFormStyle.text(context, 22, weight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Text(
          '계정의 실명이나 이메일과 별도로 공개할 이름을 정해요.',
          style: ExperienceFormStyle.text(context, 13, secondary: true),
        ),
        const SizedBox(height: 28),
        TextFormField(
          key: const ValueKey('social-profile-name'),
          controller: _name,
          enabled: !_saving,
          maxLength: 30,
          textInputAction: TextInputAction.next,
          decoration: ExperienceFormStyle.input(
            context,
            hint: '공개할 닉네임',
          ).copyWith(labelText: '닉네임'),
          validator: (value) =>
              value == null || value.trim().isEmpty ? '닉네임을 입력해 주세요.' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: const ValueKey('social-profile-handle'),
          controller: _handle,
          enabled: !_saving,
          maxLength: 24,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.next,
          decoration: ExperienceFormStyle.input(context, hint: 'slow.archive')
              .copyWith(
                labelText: '아이디',
                prefixText: '@',
                helperText: '영문·숫자·점·밑줄로 3~24자',
              ),
          validator: (value) =>
              RegExp(
                r'^[a-z0-9._]{3,24}$',
              ).hasMatch((value ?? '').trim().toLowerCase())
              ? null
              : '아이디는 영문·숫자·점·밑줄로 3~24자 입력해 주세요.',
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: const ValueKey('social-profile-bio'),
          controller: _bio,
          enabled: !_saving,
          maxLength: 160,
          minLines: 3,
          maxLines: 6,
          decoration: ExperienceFormStyle.input(
            context,
            hint: '나의 기록과 좋아하는 스타일을 소개해 주세요.',
          ).copyWith(labelText: '소개'),
        ),
        const SizedBox(height: 20),
        Text(
          '프로필과 팔로우 관계는 공개돼요. 원본 앨범, 저장한 작품과 포인트는 공개 프로필에 표시되지 않아요.',
          style: ExperienceFormStyle.text(context, 12, secondary: true),
        ),
        if (_error != null) ...[
          const SizedBox(height: 18),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: ExperienceFormStyle.text(
                context,
                13,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
        const SizedBox(height: 28),
        FilledButton(
          style: SocialStyle.primary(context),
          onPressed: _saving || _photoBusy ? null : _save,
          child: Text(_saving ? '저장 중…' : '프로필 저장'),
        ),
      ],
    ),
  );
}
