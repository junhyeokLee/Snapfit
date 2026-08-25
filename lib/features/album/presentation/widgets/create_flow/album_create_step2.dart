import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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

  Widget _buildContent() {
    final isDark = SnapFitColors.isDark(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF0E1117), Color(0xFF102A30), Color(0xFF171423)]
              : const [Color(0xFFFFF8F1), Color(0xFFEAFBFD), Color(0xFFF7F3FF)],
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 28.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30.r),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          Colors.white.withOpacity(0.10),
                          Colors.white.withOpacity(0.04),
                        ]
                      : [
                          Colors.white.withOpacity(0.88),
                          const Color(0xFFEAFBFD).withOpacity(0.70),
                        ],
                ),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.10)
                      : SnapFitColors.deepCharcoal.withOpacity(0.07),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.30 : 0.10),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                  BoxShadow(
                    color: SnapFitColors.accent.withOpacity(
                      isDark ? 0.16 : 0.10,
                    ),
                    blurRadius: 38,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: SnapFitColors.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    child: Text(
                      'INVITE COCKPIT',
                      style: TextStyle(
                        color: SnapFitColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  SizedBox(height: 18.h),
                  Text(
                    '함께 만드는\n초대 흐름 준비',
                    style: TextStyle(
                      color: SnapFitColors.textPrimaryOf(context),
                      fontSize: 26,
                      height: 1.12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.9,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    '${widget.albumTitle} · ${widget.selectedCover.name} · ${widget.selectedPageCount}쪽',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: SnapFitColors.textSecondaryOf(context),
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 18.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: const [
                      _InvitePill(label: '링크 자동 생성'),
                      _InvitePill(label: '편집 권한 선택'),
                      _InvitePill(label: '나중에 초대 가능'),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 14.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE812),
                borderRadius: BorderRadius.circular(24.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFE812).withOpacity(0.28),
                    blurRadius: 18,
                    offset: Offset(0, 10.h),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48.w,
                    height: 48.w,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.09),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: const Center(
                      child: Text(
                        'K',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 13.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '카카오톡으로 초대',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '친구에게 예쁜 초대 메시지 보내기',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    '>',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ).onTap(() => _inviteViaKakaoTalk()),
            SizedBox(height: 12.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(18.w),
              decoration: BoxDecoration(
                color: SnapFitColors.surfaceOf(
                  context,
                ).withOpacity(isDark ? 0.88 : 0.92),
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(
                  color: SnapFitColors.overlayLightOf(context),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: SnapFitColors.accent.withOpacity(0.11),
                      borderRadius: BorderRadius.circular(15.r),
                    ),
                    child: const Center(
                      child: Text(
                        'URL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: SnapFitColors.accent,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '링크 복사하기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: SnapFitColors.textPrimaryOf(context),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          _inviteLink == null
                              ? (_isCreatingInvite
                                    ? '초대 링크 생성 중...'
                                    : '공유 버튼을 누르면 초대 링크가 생성됩니다.')
                              : (_inviteLink!.length > 40
                                    ? '${_inviteLink!.substring(0, 40)}...'
                                    : _inviteLink!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: SnapFitColors.textMutedOf(context),
                            fontFamily: 'Noto Sans KR',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'COPY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: SnapFitColors.textMutedOf(context),
                    ),
                  ),
                ],
              ),
            ).onTap(() => _copyInviteLink()),
            SizedBox(height: 12.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: SnapFitColors.surfaceOf(
                  context,
                ).withOpacity(isDark ? 0.86 : 0.92),
                borderRadius: BorderRadius.circular(22.r),
                border: Border.all(
                  color: SnapFitColors.overlayLightOf(context),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42.w,
                    height: 42.w,
                    decoration: BoxDecoration(
                      color: SnapFitColors.accent.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Center(
                      child: Text(
                        _allowEditing ? 'ON' : 'OFF',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: SnapFitColors.accent,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '편집 권한 허용',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: SnapFitColors.textPrimaryOf(context),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          _allowEditing
                              ? '멤버가 사진을 추가하고 배치할 수 있어요.'
                              : '멤버는 보기 전용으로 앨범을 확인할 수 있어요.',
                          style: TextStyle(
                            fontSize: 12,
                            color: SnapFitColors.textMutedOf(context),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _allowEditing,
                    onChanged: (value) {
                      setState(() {
                        _allowEditing = value;
                        _inviteLink = null;
                      });
                      widget.onAllowEditingChanged?.call(value);
                      _createInviteLink();
                    },
                    activeColor: SnapFitColors.accent,
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: SnapFitColors.accent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(
                  color: SnapFitColors.accent.withOpacity(0.18),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18.sp,
                    color: SnapFitColors.accent,
                  ),
                  SizedBox(width: 9.w),
                  Expanded(
                    child: Text(
                      '멤버 초대는 앨범 생성 후에도 설정 > 멤버 관리에서 언제든 가능합니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: SnapFitColors.textMutedOf(context),
                        height: 1.38,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 14.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _confirmSkipInviteBeforeNext,
                icon: Icon(Icons.arrow_forward_rounded, size: 20.sp),
                label: Text(
                  '다음',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SnapFitColors.accent,
                  foregroundColor: SnapFitColors.pureWhite,
                  padding: EdgeInsets.symmetric(vertical: 17.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            SizedBox(height: 10.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: widget.onBack,
                style: OutlinedButton.styleFrom(
                  foregroundColor: SnapFitColors.textPrimaryOf(context),
                  side: BorderSide(
                    color: SnapFitColors.overlayLightOf(context),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 15.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                ),
                child: Text(
                  '이전',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                Icon(Icons.check_circle, color: Colors.white, size: 20.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    '카카오톡으로 초대 메시지를 보냈습니다! 💌',
                    style: TextStyle(fontSize: 14.sp),
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
              Icon(Icons.check_circle, color: Colors.white, size: 20.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  '초대 링크가 클립보드에 복사되었습니다.',
                  style: TextStyle(fontSize: 14.sp),
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
        backgroundColor: SnapFitColors.surfaceOf(context),
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
                color: SnapFitColors.accent,
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

class _InvitePill extends StatelessWidget {
  final String label;

  const _InvitePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context).withOpacity(0.78),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: SnapFitColors.overlayLightOf(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: SnapFitColors.accent,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: SnapFitColors.textPrimaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

extension on Widget {
  Widget onTap(VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: this);
  }
}
