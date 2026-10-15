import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../../shared/web/web_design.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../shared/widgets/experience_icon.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/utils/screen_logger.dart';
import '../../../data/api/album_provider.dart';
import '../../../service/album_invite_service.dart';

/// 스텝3: 친구 초대 기능 (딥링크)
class AlbumCreateStep2 extends ConsumerStatefulWidget {
  final String albumTitle;
  final CoverSize selectedCover;
  final int selectedPageCount;
  final bool allowEditing;
  final ValueChanged<bool>? onAllowEditingChanged;
  final int? albumId;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const AlbumCreateStep2({
    super.key,
    required this.albumTitle,
    required this.selectedCover,
    required this.selectedPageCount,
    this.allowEditing = true,
    this.onAllowEditingChanged,
    this.albumId,
    required this.onNext,
    required this.onBack,
  });

  @override
  ConsumerState<AlbumCreateStep2> createState() => _AlbumCreateStep2State();
}

class _AlbumCreateStep2State extends ConsumerState<AlbumCreateStep2> {
  bool _allowEditing = true;
  int? _albumId;
  String? _inviteLink;
  bool _isCreatingInvite = false;

  @override
  void initState() {
    super.initState();
    ScreenLogger.widget('AlbumCreateStep2', '앨범 생성 Step 3 · 친구 초대/딥링크');
    _allowEditing = widget.allowEditing;
    // 앨범 ID는 부모에서 전달받음
    _albumId = widget.albumId;
    if (_albumId != null) {
      Future.microtask(_createInviteLink);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildContent();
  }

  Widget _buildContent() => SafeArea(
    top: false,
    child: Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final summary = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '함께 만드는 앨범',
                          style: ExperienceFormStyle.text(
                            context,
                            22,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ExperienceIcon(
                          'BookOpen',
                          size: 30,
                          color: ExperienceFormStyle.selectionInk(context),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.albumTitle,
                          style: ExperienceFormStyle.text(
                            context,
                            17,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.selectedCover.displayName} · ${widget.selectedCover.coverType.label} · ${widget.selectedPageCount}쪽',
                          style: ExperienceFormStyle.text(
                            context,
                            12,
                            secondary: true,
                          ),
                        ),
                      ],
                    );
                    final sharing = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _isCreatingInvite
                                ? null
                                : _inviteViaKakaoTalk,
                            icon: SvgPicture.asset(
                              'assets/social/kakaotalk.svg',
                              width: 20,
                              height: 20,
                            ),
                            label: const Text('카카오톡으로 초대'),
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: const Color(0xFFFEE500),
                              foregroundColor: const Color(0xFF191919),
                              textStyle: ExperienceFormStyle.text(
                                context,
                                14,
                                weight: FontWeight.w600,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(kIsWeb ? 12 : 6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                          decoration: BoxDecoration(
                            color: ExperienceFormStyle.surface(context),
                            borderRadius: BorderRadius.circular(kIsWeb ? 12 : 6),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '링크 복사하기',
                                      style: ExperienceFormStyle.text(
                                        context,
                                        13,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _inviteLink ??
                                          (_isCreatingInvite
                                              ? '초대 링크 생성 중...'
                                              : '초대 링크를 만들 수 있어요'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: ExperienceFormStyle.text(
                                        context,
                                        12,
                                        secondary: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: '초대 링크 복사',
                                onPressed: _isCreatingInvite
                                    ? null
                                    : _copyInviteLink,
                                icon: Icon(
                                  Icons.content_copy_outlined,
                                  size: 21,
                                  color: ExperienceFormStyle.ink(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Divider(color: ExperienceFormStyle.line(context)),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '편집 권한 허용',
                                    style: ExperienceFormStyle.text(
                                      context,
                                      14,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _allowEditing
                                        ? '사진과 페이지를 함께 편집'
                                        : '앨범 보기만 허용',
                                    style: ExperienceFormStyle.text(
                                      context,
                                      12,
                                      secondary: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _allowEditing,
                              onChanged: _isCreatingInvite
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _allowEditing = value;
                                        _inviteLink = null;
                                      });
                                      widget.onAllowEditingChanged?.call(value);
                                      _createInviteLink();
                                    },
                              activeTrackColor: SnapFitColors.accent,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '초대는 나중에도 할 수 있어요.',
                          style: ExperienceFormStyle.text(
                            context,
                            12,
                            secondary: true,
                          ),
                        ),
                      ],
                    );
                    return box.maxWidth >= 640
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 4, child: kIsWeb ? WebSurface(child: summary) : summary),
                              const SizedBox(width: 40),
                              Expanded(flex: 6, child: kIsWeb ? WebSurface(child: sharing) : sharing),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              kIsWeb ? WebSurface(child: summary) : summary,
                              const SizedBox(height: 28),
                              kIsWeb ? WebSurface(child: sharing) : sharing,
                            ],
                          );
                  },
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      tooltip: '이전',
                      onPressed: widget.onBack,
                      icon: ExperienceIcon(
                        'ArrowLeft',
                        color: ExperienceFormStyle.ink(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _confirmSkipInviteBeforeNext,
                      style: ExperienceFormStyle.primary(context),
                      child: const Text('편집 시작'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  /// 초대 링크 생성
  Future<void> _createInviteLink() async {
    if (_isCreatingInvite || _albumId == null) return;

    setState(() => _isCreatingInvite = true);

    try {
      final memberRepository = ref.read(albumMemberRepositoryProvider);
      final inviteResponse = await memberRepository.invite(
        _albumId!,
        role: _allowEditing ? 'EDITOR' : 'VIEWER',
      );

      if (!mounted) return;
      setState(() => _inviteLink = inviteResponse.link);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('초대 링크 생성 실패: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingInvite = false);
      }
    }
  }

  /// 카카오톡으로 초대 링크 공유
  Future<void> _inviteViaKakaoTalk() async {
    if (_albumId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('앨범 정보를 불러오는 중입니다. 잠시만 기다려주세요.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    if (_inviteLink == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('초대 링크를 생성하는 중입니다. 잠시만 기다려주세요.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      // 초대 링크가 없으면 다시 생성 시도
      await _createInviteLink();
      if (_inviteLink == null) {
        return;
      }
    }

    // 로딩 표시
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('카카오톡으로 공유 중...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

    final success = await AlbumInviteService.inviteViaKakaoTalk(
      ref: ref,
      albumId: _albumId!,
      albumTitle: widget.albumTitle,
      allowEditing: _allowEditing,
      inviteLink: _inviteLink,
      context: context,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: kIsWeb ? WebPalette.of(context).onBrand : Colors.white, size: 20.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    '카카오톡 공유 화면을 열었어요.',
                    style: TextStyle(fontSize: 14.sp, color: kIsWeb ? WebPalette.of(context).onBrand : null),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFFFE812),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
      }
      // 실패 시 안내는 서비스에서 처리됨
    }
  }

  /// 초대 링크 복사
  Future<void> _copyInviteLink() async {
    if (_inviteLink == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('초대 링크를 생성하는 중입니다. 잠시만 기다려주세요.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      // 초대 링크가 없으면 다시 생성 시도
      await _createInviteLink();
      if (_inviteLink == null) {
        return;
      }
    }

    await Clipboard.setData(ClipboardData(text: _inviteLink!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: kIsWeb ? WebPalette.of(context).onBrand : Colors.white, size: 20.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  '초대 링크가 클립보드에 복사되었습니다.',
                  style: TextStyle(fontSize: 14.sp, color: kIsWeb ? WebPalette.of(context).onBrand : null),
                ),
              ),
            ],
          ),
          backgroundColor: SnapFitColors.accent,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmSkipInviteBeforeNext() async {
    final goNext = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kIsWeb ? WebPalette.of(context).surface : SnapFitColors.surfaceOf(context),
        title: Text(
          '초대를 건너뛸까요?',
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
        content: Text(
          '지금은 초대하지 않고 다음 단계로 이동합니다.\n멤버 초대는 앨범에서도 언제든 할 수 있어요.',
          style: TextStyle(
            fontSize: 13.sp,
            color: SnapFitColors.textSecondaryOf(context),
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              '계속 초대하기',
              style: TextStyle(
                color: SnapFitColors.textPrimaryOf(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '건너뛰고 다음',
              style: TextStyle(
                color: kIsWeb ? WebPalette.of(context).brandInk : SnapFitColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (goNext == true) {
      widget.onNext();
    }
  }
}
