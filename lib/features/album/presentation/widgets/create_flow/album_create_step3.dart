import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../viewmodels/album_editor_view_model.dart';

/// 스텝3: 앨범 생성 후 페이지 편집 화면으로 이동
class AlbumCreateStep3 extends ConsumerStatefulWidget {
  final String albumTitle;
  final CoverSize selectedCover;
  final int selectedPageCount;
  final List<String> invitedEmails;
  final VoidCallback onComplete;
  final VoidCallback onBack;

  const AlbumCreateStep3({
    super.key,
    required this.albumTitle,
    required this.selectedCover,
    required this.selectedPageCount,
    required this.invitedEmails,
    required this.onComplete,
    required this.onBack,
  });

  @override
  ConsumerState<AlbumCreateStep3> createState() => _AlbumCreateStep3State();
}

class _AlbumCreateStep3State extends ConsumerState<AlbumCreateStep3> {
  bool _isCreating = false;

  Future<void> _createAlbum() async {
    if (_isCreating) return;
    
    setState(() => _isCreating = true);
    
    try {
      final vm = ref.read(albumEditorViewModelProvider.notifier);
      
      // 앨범 생성 전 초기화
      vm.resetForCreate(initialCover: widget.selectedCover);
      
      // 선택된 페이지 수만큼 페이지 생성 (커버 제외)
      // 현재 커버 페이지만 있으므로, 추가로 (selectedPageCount - 1)개 페이지 생성
      for (int i = 1; i < widget.selectedPageCount; i++) {
        vm.addPage();
      }
      
      // TODO: 실제 앨범 생성 API 호출
      // final albumRepo = ref.read(albumRepositoryProvider);
      // await albumRepo.createAlbum(...);
      
      // 초대 이메일이 있으면 초대 요청
      if (widget.invitedEmails.isNotEmpty) {
        // TODO: 초대 API 호출
        // for (final email in widget.invitedEmails) {
        //   await albumMemberRepo.inviteAlbum(albumId, email);
        // }
      }
      
      if (!mounted) return;
      widget.onComplete();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('앨범 생성 실패: $e')),
      );
      setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 40.h),
          // 앨범 편집 시작하기 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isCreating ? null : _createAlbum,
              icon: _isCreating
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          SnapFitColors.pureWhite,
                        ),
                      ),
                    )
                  : Icon(Icons.rocket_launch, size: 20.sp),
              label: Text(
                _isCreating ? '앨범 생성 중...' : '앨범 편집 시작하기',
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
              onPressed: _isCreating ? null : widget.onBack,
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

  Widget _buildInfoCard(
    BuildContext context,
    String label,
    String value,
    String? subtitle,
  ) {
    return Container(
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: SnapFitColors.textMutedOf(context),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: SnapFitColors.textPrimaryOf(context),
                  ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: SnapFitColors.textMutedOf(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
