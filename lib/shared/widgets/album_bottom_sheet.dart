import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../core/constants/snapfit_colors.dart';
import '../../features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'gallery_thumb_tile.dart';

/// 상단 드래그 핸들 + 제목 + 닫기
class _GallerySheetHeaderDelegate extends SliverPersistentHeaderDelegate {
  final VoidCallback onClose;

  _GallerySheetHeaderDelegate({required this.onClose});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final textColor = SnapFitColors.textPrimaryOf(context);
    return Container(
      height: 48,
      color: SnapFitColors.surfaceOf(context),
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      alignment: Alignment.center,
      child: Row(
        children: [
          Container(
            width: 32.w,
            height: 3.h,
            decoration: BoxDecoration(
              color: SnapFitColors.textMutedOf(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              '사진 선택',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: 12.w),
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, color: textColor, size: 22.sp),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 32.w, minHeight: 32.w),
            style: IconButton.styleFrom(
              minimumSize: Size(32.w, 32.w),
              maximumSize: Size(32.w, 32.w),
            ),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 48;
  @override
  double get minExtent => 48;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}

/// 앨범 선택 헤더 (현재 앨범명 + 드롭다운)
class AlbumHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<AssetPathEntity> albums;
  final AssetPathEntity? current;
  final VoidCallback onTap;

  AlbumHeaderDelegate({
    required this.albums,
    required this.current,
    required this.onTap,
  });

  static String _albumDisplayName(AssetPathEntity? a) {
    if (a == null) return '최근';
    return a.name == 'Recent' ? '최근' : a.name;
  }

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final textColor = SnapFitColors.textPrimaryOf(context);
    return Container(
      color: SnapFitColors.surfaceOf(context),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 22.sp,
              color: SnapFitColors.accent,
            ),
            SizedBox(width: 8.w),
            Text(
              _albumDisplayName(current),
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            SizedBox(width: 4.w),
            Icon(
              Icons.keyboard_arrow_down,
              size: 24.sp,
              color: textColor,
            ),
          ],
        ),
      ),
    );
  }

  @override
  double get maxExtent => 48;
  @override
  double get minExtent => 48;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}

/// 📸 공통 사진 선택 바텀시트 (실서비스 스타일)
/// 사진 선택 시 시트를 닫고 [AssetEntity]를 반환. 취소 시 null.
Future<AssetEntity?> showPhotoSelectionSheet(
  BuildContext context,
  WidgetRef ref, {
  void Function(AssetEntity asset)? onSelect,
}) async {
  final result = await showModalBottomSheet<AssetEntity>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    showDragHandle: false,
    builder: (_) {
      return DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        minChildSize: 0.45,
        expand: false,
        builder: (context, scrollController) {
          scrollController.addListener(() {
            final vm = ref.read(albumEditorViewModelProvider.notifier);
            if (scrollController.position.pixels >=
                scrollController.position.maxScrollExtent - 400) {
              vm.loadMore();
            }
          });

          return Consumer(
            builder: (context, ref, _) {
              final async = ref.watch(albumEditorViewModelProvider);
              final error = async.asError;
              final st = async.asData?.value;

              if (error != null) {
                return Container(
                  decoration: BoxDecoration(
                    color: SnapFitColors.surfaceOf(context),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: EdgeInsets.all(24.w),
                          child: Icon(
                            Icons.photo_library_outlined,
                            size: 48.sp,
                            color: SnapFitColors.textMutedOf(context),
                          ),
                        ),
                        Text(
                          error.error.toString().replaceFirst('Exception: ', ''),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: SnapFitColors.textSecondaryOf(context),
                          ),
                        ),
                        SizedBox(height: 16.h),
                        TextButton.icon(
                          onPressed: () {
                            ref.read(albumEditorViewModelProvider.notifier).fetchInitialData();
                          },
                          icon: Icon(Icons.refresh, size: 20.sp, color: SnapFitColors.accent),
                          label: Text(
                            '다시 시도',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: SnapFitColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (st == null) {
                return Container(
                  decoration: BoxDecoration(
                    color: SnapFitColors.surfaceOf(context),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: SnapFitColors.accent,
                          strokeWidth: 2,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          '사진첩 불러오는 중...',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: SnapFitColors.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: SnapFitColors.surfaceOf(context),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _GallerySheetHeaderDelegate(
                        onClose: () => Navigator.of(context).pop(),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: AlbumHeaderDelegate(
                        albums: st.albums,
                        current: st.currentAlbum,
                        onTap: () => _showAlbumSelectionSheet(
                          context,
                          ref,
                          st.albums,
                          st.currentAlbum,
                        ),
                      ),
                    ),
                    if (st.files.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: async.isLoading
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 36.w,
                                      height: 36.w,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: SnapFitColors.accent,
                                      ),
                                    ),
                                    SizedBox(height: 12.h),
                                    Text(
                                      '앨범 사진 불러오는 중...',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: SnapFitColors.textSecondaryOf(context),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.photo_outlined,
                                      size: 56.sp,
                                      color: SnapFitColors.textMutedOf(context),
                                    ),
                                    SizedBox(height: 12.h),
                                    Text(
                                      '이 앨범에 사진이 없어요',
                                      style: TextStyle(
                                        fontSize: 15.sp,
                                        color: SnapFitColors.textSecondaryOf(context),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                        sliver: SliverGrid(
                          key: ValueKey(st.currentAlbum?.id),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 6.w,
                            mainAxisSpacing: 6.w,
                            childAspectRatio: 1,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final asset = st.files[i];
                              return GestureDetector(
                                onTap: () {
                                  onSelect?.call(asset);
                                  Navigator.pop(context, asset);
                                },
                                child: GalleryThumbTile(
                                  key: ValueKey(asset.id),
                                  asset: asset,
                                  isSelected: false,
                                  simpleMode: true,
                                ),
                              );
                            },
                            childCount: st.files.length,
                          ),
                        ),
                      ),
                    if (async.isLoading && st.files.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          child: Center(
                            child: SizedBox(
                              width: 28.w,
                              height: 28.w,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: SnapFitColors.accent,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
  return result;
}


/// 📂 앨범 선택 바텀시트 (실서비스 스타일)
Future<void> _showAlbumSelectionSheet(
  BuildContext context,
  WidgetRef ref,
  List<AssetPathEntity> albums,
  AssetPathEntity? current,
) async {
  final selected = await showModalBottomSheet<AssetPathEntity>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return Container(
        decoration: BoxDecoration(
          color: SnapFitColors.surfaceOf(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 12.h),
              Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: SnapFitColors.textMutedOf(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
                child: Row(
                  children: [
                    Text(
                      '앨범 선택',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: SnapFitColors.textPrimaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.only(bottom: 24.h),
                  itemCount: albums.length,
                  itemBuilder: (context, i) {
                    final a = albums[i];
                    final isCurr = a.id == current?.id;
                    final name = a.name == 'Recent' ? '최근' : a.name;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context, a),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                          child: Row(
                            children: [
                              Container(
                                width: 44.w,
                                height: 44.w,
                                decoration: BoxDecoration(
                                  color: isCurr
                                      ? SnapFitColors.accent.withOpacity(0.2)
                                      : SnapFitColors.overlayLightOf(context),
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                child: Icon(
                                  Icons.photo_library_outlined,
                                  size: 24.sp,
                                  color: isCurr
                                      ? SnapFitColors.accent
                                      : SnapFitColors.textSecondaryOf(context),
                                ),
                              ),
                              SizedBox(width: 14.w),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: isCurr ? FontWeight.w700 : FontWeight.w500,
                                    color: SnapFitColors.textPrimaryOf(context),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCurr)
                                Icon(
                                  Icons.check_circle,
                                  size: 22.sp,
                                  color: SnapFitColors.accent,
                                )
                              else
                                Icon(
                                  Icons.chevron_right,
                                  size: 24.sp,
                                  color: SnapFitColors.textMutedOf(context),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (selected != null) {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    await vm.selectAlbum(selected);
    ref.invalidate(albumEditorViewModelProvider);
  }
}