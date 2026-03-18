import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../data/api/album_provider.dart';
import '../../service/album_invite_service.dart';

class AlbumInviteScreen extends ConsumerStatefulWidget {
  final int albumId;
  final String albumTitle;
  final bool initialAllowEditing;

  const AlbumInviteScreen({
    super.key,
    required this.albumId,
    required this.albumTitle,
    this.initialAllowEditing = true,
  });

  @override
  ConsumerState<AlbumInviteScreen> createState() => _AlbumInviteScreenState();
}

class _AlbumInviteScreenState extends ConsumerState<AlbumInviteScreen> {
  late bool _allowEditing;
  String? _inviteLink;
  bool _isCreatingInvite = false;

  @override
  void initState() {
    super.initState();
    _allowEditing = widget.initialAllowEditing;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _createInviteLink();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: SnapFitColors.backgroundOf(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '멤버 초대',
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 16.h),
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
            SizedBox(height: 28.h),
            Center(
              child: Container(
                width: 120.w,
                height: 120.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: SnapFitColors.accent, width: 2),
                  color: SnapFitColors.backgroundOf(context),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 50.sp,
                          color: SnapFitColors.accent,
                        ),
                        SizedBox(width: 4.w),
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
                                decoration: const BoxDecoration(
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
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 32.w,
                        height: 32.w,
                        decoration: const BoxDecoration(
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
            SizedBox(height: 28.h),
            _InviteActionCard(
              title: '카카오톡으로 초대',
              subtitle: '친구에게 예쁜 초대 메시지 보내기 💌',
              icon: Icons.chat_bubble_outline,
              background: const Color(0xFFFFE812),
              foreground: Colors.black87,
              onTap: _inviteViaKakaoTalk,
            ),
            SizedBox(height: 12.h),
            _InviteActionCard(
              title: '링크 복사하기',
              subtitle: _inviteLink == null
                  ? '초대 링크 생성 중...'
                  : (_inviteLink!.length > 42
                        ? '${_inviteLink!.substring(0, 42)}...'
                        : _inviteLink!),
              icon: Icons.link,
              background: SnapFitColors.surfaceOf(context),
              foreground: SnapFitColors.textPrimaryOf(context),
              borderColor: SnapFitColors.overlayLightOf(context),
              onTap: _copyInviteLink,
            ),
            SizedBox(height: 16.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: SnapFitColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: SnapFitColors.overlayLightOf(context),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_outlined,
                    size: 22.sp,
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
                        SizedBox(height: 3.h),
                        Text(
                          '끄면 보기 전용으로 초대됩니다.',
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
                    onChanged: (v) {
                      setState(() {
                        _allowEditing = v;
                        _inviteLink = null;
                      });
                      _createInviteLink();
                    },
                    activeColor: SnapFitColors.accent,
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
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
                      '멤버 초대는 앨범에서도 언제든 가능합니다.',
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
            SizedBox(height: 28.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SnapFitColors.accent,
                  foregroundColor: SnapFitColors.pureWhite,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  '완료',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createInviteLink() async {
    if (_isCreatingInvite) return;
    setState(() => _isCreatingInvite = true);

    try {
      final memberRepository = ref.read(albumMemberRepositoryProvider);
      final inviteResponse = await memberRepository.invite(
        widget.albumId,
        role: _allowEditing ? 'EDITOR' : 'VIEWER',
      );
      if (!mounted) return;
      setState(() => _inviteLink = inviteResponse.link);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('초대 링크 생성 실패: $e')));
    } finally {
      if (mounted) {
        setState(() => _isCreatingInvite = false);
      }
    }
  }

  Future<void> _inviteViaKakaoTalk() async {
    if (_inviteLink == null) {
      await _createInviteLink();
      if (_inviteLink == null) return;
    }

    final success = await AlbumInviteService.inviteViaKakaoTalk(
      ref: ref,
      albumId: widget.albumId,
      albumTitle: widget.albumTitle,
      allowEditing: _allowEditing,
      context: context,
    );

    if (!mounted || !success) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('카카오톡으로 초대 메시지를 보냈습니다.')));
  }

  Future<void> _copyInviteLink() async {
    if (_inviteLink == null) {
      await _createInviteLink();
      if (_inviteLink == null) return;
    }

    await Clipboard.setData(ClipboardData(text: _inviteLink!));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('초대 링크를 복사했습니다.')));
  }
}

class _InviteActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color? borderColor;
  final VoidCallback onTap;

  const _InviteActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(18.w),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16.r),
          border: borderColor == null ? null : Border.all(color: borderColor!),
        ),
        child: Row(
          children: [
            Icon(icon, color: foreground, size: 24.sp),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: foreground.withOpacity(0.75),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 24.sp, color: foreground),
          ],
        ),
      ),
    );
  }
}
