import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'gallery_thumb_tile.dart';


class AlbumHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<AssetPathEntity> albums;
  final AssetPathEntity? current;
  final VoidCallback onTap;

  AlbumHeaderDelegate({
    required this.albums,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 앨범명 + 화살표
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  current != null ? (current!.name == 'Recent' ? '최근' : current!.name) : '최근',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, color: Colors.black),
              ],
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

class _AlbumSelectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final AssetPathEntity? current;
  final VoidCallback onClose;

  _AlbumSelectionHeaderDelegate({
    required this.current,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container();
  }

  @override
  double get maxExtent => 56;
  @override
  double get minExtent => 56;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}


/// 📸 공통 사진 선택 바텀시트
/// 사진 선택 시 시트를 닫고 [AssetEntity]를 반환. 취소 시 null.
/// [onSelect]가 있으면 선택 시 호출한 뒤 pop(선택한 사진 반환).
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
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) {
          scrollController.addListener(() {
            final vm = ref.read(albumEditorViewModelProvider.notifier);
            if (scrollController.position.pixels >=
                scrollController.position.maxScrollExtent - 300) {
              vm.loadMore();
            }
          });

          return Consumer(
            builder: (context, ref, _) {
              final async = ref.watch(albumEditorViewModelProvider);
              final st = async.asData?.value;
              if (st == null) {
                return const Center(child: CircularProgressIndicator());
              }

              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    // ✅ 앨범 헤더
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
                    // ✅ 썸네일 그리드
                    SliverPadding(
                      padding: const EdgeInsets.all(6),
                      sliver: SliverGrid(
                        key: ValueKey(st.currentAlbum?.id),
                        gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
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
                              ),
                            );
                          },
                          childCount: st.files.length,
                        ),
                      ),
                    ),
                    // ✅ 로딩 인디케이터
                    SliverToBoxAdapter(
                      child: async.isLoading
                          ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                          : const SizedBox.shrink(),
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


/// 📂 앨범 선택 바텀시트
Future<void> _showAlbumSelectionSheet(
    BuildContext context,
    WidgetRef ref,
    List<AssetPathEntity> albums,
    AssetPathEntity? current,
    ) async {
  final selected = await showModalBottomSheet<AssetPathEntity>(
    context: context,
    isScrollControlled: false,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) {
      return SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _AlbumSelectionHeaderDelegate(
                current: current,
                onClose: () => Navigator.of(context).pop(),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, i) {
                  final a = albums[i];
                  final isCurr = a.id == current?.id;
                  return ListTile(
                    title: Text(
                      a.name == 'Recent' ? '최근' : a.name,
                      style: TextStyle(
                        color: isCurr ? Colors.blueAccent : Colors.black87,
                        fontWeight:
                        isCurr ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, a),
                  );
                },
                childCount: albums.length,
              ),
            ),
          ],
        ),
      );
    },
  );

  if (selected != null) {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    await vm.selectAlbum(selected);
    ref.invalidate(albumEditorViewModelProvider); // ✅ setState 대체
  }
}