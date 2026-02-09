import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../data/api/album_provider.dart';
import '../../../data/dto/request/create_album_request.dart';

/// 스텝2: 앨범 생성
class AlbumCreateStep2AlbumCreation extends ConsumerStatefulWidget {
  final String albumTitle;
  final CoverSize selectedCover;
  final int selectedPageCount;
  final Function(int albumId)? onAlbumCreated;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const AlbumCreateStep2AlbumCreation({
    super.key,
    required this.albumTitle,
    required this.selectedCover,
    required this.selectedPageCount,
    this.onAlbumCreated,
    required this.onNext,
    required this.onBack,
  });

  @override
  ConsumerState<AlbumCreateStep2AlbumCreation> createState() => _AlbumCreateStep2AlbumCreationState();
}

class _AlbumCreateStep2AlbumCreationState extends ConsumerState<AlbumCreateStep2AlbumCreation> {
  int? _albumId;
  bool _isCreating = false;
  bool _hasInitiated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 앨범 생성은 한 번만 실행
    if (!_hasInitiated && !_isCreating && _albumId == null) {
      _hasInitiated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _createAlbum();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // STEP 표시
          Text(
            'STEP 02/04',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: SnapFitColors.accent,
            ),
          ),
          SizedBox(height: 16.h),
          // 메인 타이틀
          Text(
            '앨범 생성 중...',
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: SnapFitColors.textPrimaryOf(context),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '앨범을 생성하고 있습니다. 잠시만 기다려주세요.',
            style: TextStyle(
              fontSize: 14.sp,
              color: SnapFitColors.textMutedOf(context),
            ),
          ),
          SizedBox(height: 40.h),
          // 로딩 인디케이터
          Center(
            child: _isCreating
                ? CircularProgressIndicator(
                    color: SnapFitColors.accent,
                  )
                : Icon(
                    Icons.check_circle,
                    size: 80.sp,
                    color: SnapFitColors.accent,
                  ),
          ),
          SizedBox(height: 40.h),
          // 다음 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isCreating || _albumId == null) ? null : () {
                if (_albumId != null) {
                  widget.onAlbumCreated?.call(_albumId!);
                  widget.onNext();
                }
              },
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
                  : Icon(Icons.arrow_forward, size: 20.sp),
              label: Text(
                _isCreating ? '앨범 생성 중...' : '다음',
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

  /// 앨범 생성
  Future<void> _createAlbum() async {
    if (_isCreating) return;
    
    setState(() => _isCreating = true);
    
    try {
      final albumRepository = ref.read(albumRepositoryProvider);
      
      // 앨범 생성 (빈 커버로 시작)
      final request = CreateAlbumRequest(
        ratio: widget.selectedCover.ratio.toString(),
        coverLayersJson: '[]', // 빈 레이어로 시작
        coverImageUrl: '',
        coverThumbnailUrl: '',
        coverTheme: '',
      );
      
      final album = await albumRepository.createAlbum(request);
      _albumId = album.id;
      
      if (mounted) {
        widget.onAlbumCreated?.call(album.id!);
        setState(() => _isCreating = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('앨범 생성 실패: $e')),
        );
        setState(() => _isCreating = false);
      }
    }
  }
}
