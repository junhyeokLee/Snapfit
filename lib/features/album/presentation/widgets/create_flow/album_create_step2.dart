import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/constants/cover_size.dart';
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
  bool _hasInitiated = false;

  @override
  void initState() {
    super.initState();
    _allowEditing = widget.allowEditing;
    // 앨범 ID는 부모에서 전달받음
    _albumId = widget.albumId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 초대 링크 생성은 한 번만 실행
    if (!_hasInitiated && _albumId != null && _inviteLink == null && !_isCreatingInvite) {
      _hasInitiated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _createInviteLink();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildContent();
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // STEP 표시
          Text(
            'STEP 03/04',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: SnapFitColors.accent,
            ),
          ),
          SizedBox(height: 16.h),
          // 메인 타이틀
          Text(
            '함께 만들 멤버를 초대할까요? 👥',
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: SnapFitColors.textPrimaryOf(context),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '친구들과 함께 소중한 추억을 담은 앨범을 만들어보세요.\n함께 사진을 추가하고 예쁘게 꾸며보아요! ✨',
            style: TextStyle(
              fontSize: 14.sp,
              color: SnapFitColors.textMutedOf(context),
              height: 1.5,
            ),
          ),
          SizedBox(height: 40.h),
          // 중앙 아이콘
          Center(
            child: Container(
              width: 120.w,
              height: 120.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: SnapFitColors.accent,
                  width: 2,
                ),
                color: SnapFitColors.backgroundOf(context),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 두 명의 사람 아이콘 (큰 사람 + 작은 사람)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 큰 사람
                      Icon(
                        Icons.person_outline,
                        size: 50.sp,
                        color: SnapFitColors.accent,
                      ),
                      SizedBox(width: 4.w),
                      // 작은 사람 + 플러스
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 40.sp,
                            color: SnapFitColors.accent,
                          ),
                          Positioned(
                            top: -4.h,
                            right: -4.w,
                            child: Container(
                              width: 16.w,
                              height: 16.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: SnapFitColors.accent,
                              ),
                              child: Icon(
                                Icons.add,
                                size: 12.sp,
                                color: SnapFitColors.pureWhite,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // 오른쪽 상단 체크 표시
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 32.w,
                      height: 32.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: SnapFitColors.accent,
                      ),
                      child: Icon(
                        Icons.check,
                        size: 18.sp,
                        color: SnapFitColors.pureWhite,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 40.h),
          // 카카오톡으로 초대 버튼 (실서비스 스타일)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE812), // 카카오톡 노란색
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFE812).withOpacity(0.3),
                  blurRadius: 8.r,
                  offset: Offset(0, 4.h),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 카카오톡 로고 아이콘 (실제 카카오톡 스타일)
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 카카오톡 말풍선 아이콘
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 24.sp,
                            color: Colors.black87,
                          ),
                          // 작은 말풍선 (카카오톡 느낌)
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              width: 8.w,
                              height: 8.w,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE812),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.black87,
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '카카오톡',
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                '으로 초대',
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            '친구에게 예쁜 초대 메시지 보내기 💌',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16.sp,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ],
            ),
          ).onTap(() => _inviteViaKakaoTalk()),
          SizedBox(height: 16.h),
          // 링크 복사하기 버튼 (실서비스 스타일)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: SnapFitColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: SnapFitColors.overlayLightOf(context),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: SnapFitColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    Icons.link,
                    size: 24.sp,
                    color: SnapFitColors.accent,
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
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: SnapFitColors.textPrimaryOf(context),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      if (_inviteLink != null)
                        Text(
                          _inviteLink!.length > 40 
                              ? '${_inviteLink!.substring(0, 40)}...'
                              : _inviteLink!,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: SnapFitColors.textMutedOf(context),
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        Text(
                          '초대 링크 생성 중...',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: SnapFitColors.textMutedOf(context),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.copy,
                  size: 20.sp,
                  color: SnapFitColors.textMutedOf(context),
                ),
              ],
            ),
          ).onTap(() => _copyInviteLink()),
          SizedBox(height: 24.h),
          // 편집 권한 허용
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: SnapFitColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: SnapFitColors.overlayLightOf(context),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.edit_outlined,
                  size: 24.sp,
                  color: SnapFitColors.textPrimaryOf(context),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '편집 권한 허용',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: SnapFitColors.textPrimaryOf(context),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '초대된 멤버가 사진을 추가하고 배치할 수 있습니다.',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: SnapFitColors.textMutedOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _allowEditing,
                  onChanged: (value) {
                    setState(() => _allowEditing = value);
                    widget.onAllowEditingChanged?.call(value);
                  },
                  activeColor: SnapFitColors.accent,
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          // 안내 문구 (실서비스 스타일)
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: SnapFitColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: SnapFitColors.accent.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16.sp,
                  color: SnapFitColors.accent,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    '멤버 초대는 앨범 생성 후에도\n\'설정 > 멤버 관리\'에서 언제든 가능합니다.',
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: SnapFitColors.textMutedOf(context),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 40.h),
          // 다음 버튼 (Step 4로 이동)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onNext,
              icon: Icon(Icons.arrow_forward, size: 20.sp),
              label: Text(
                '다음',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: SnapFitColors.accent,
                foregroundColor: SnapFitColors.pureWhite,
                padding: EdgeInsets.symmetric(vertical: 18.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                elevation: 0,
              ),
            ),
          ),
          SizedBox(height: 16.h),
          // 이전 버튼
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: widget.onBack,
              style: OutlinedButton.styleFrom(
                foregroundColor: SnapFitColors.textPrimaryOf(context),
                side: BorderSide(
                  color: SnapFitColors.overlayLightOf(context),
                ),
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                '이전',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
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
        role: widget.allowEditing ? 'EDITOR' : 'VIEWER',
      );
      
      _inviteLink = inviteResponse.link;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('초대 링크 생성 실패: $e')),
        );
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
}

extension on Widget {
  Widget onTap(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: this,
    );
  }
}
