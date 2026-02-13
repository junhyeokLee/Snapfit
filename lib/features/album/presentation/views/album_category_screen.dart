import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../domain/entities/album.dart';
import '../viewmodels/home_view_model.dart';
import '../widgets/home/list_album_card.dart';
import '../widgets/home/home_album_actions.dart';
import '../widgets/home/home_album_helpers.dart';

enum AlbumCategory {
  recent,
  completed,
  shared,
}

class AlbumCategoryScreen extends ConsumerStatefulWidget {
  final AlbumCategory category;
  final List<Album> initialAlbums;
  final String currentUserId;

  const AlbumCategoryScreen({
    super.key,
    required this.category,
    required this.initialAlbums,
    required this.currentUserId,
  });

  @override
  ConsumerState<AlbumCategoryScreen> createState() => _AlbumCategoryScreenState();
}

class _AlbumCategoryScreenState extends ConsumerState<AlbumCategoryScreen> {
  late List<Album> _albums;
  bool _isReordering = false;
  bool _isEditMode = false;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _albums = List.from(widget.initialAlbums);
  }

  String get _title {
    switch (widget.category) {
      case AlbumCategory.recent:
        return '최근 작업 중인 앨범';
      case AlbumCategory.completed:
        return '완료된 앨범';
      case AlbumCategory.shared:
        return '공유된 앨범';
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final Album item = _albums.removeAt(oldIndex);
      _albums.insert(newIndex, item);
      _isReordering = true;
    });
  }

  Future<void> _saveOrder() async {
    try {
      final ids = _albums.map((e) => e.id).toList();
      await ref.read(homeViewModelProvider.notifier).reorderByCategory(_albums);
      
      if (mounted) {
        setState(() => _isReordering = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('순서가 저장되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: SnapFitColors.backgroundOf(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: SnapFitColors.textPrimaryOf(context), size: 20.w),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: SnapFitColors.textPrimaryOf(context), fontSize: 16.sp),
                decoration: InputDecoration(
                  hintText: '앨범 제목 또는 테마 검색',
                  hintStyle: TextStyle(color: SnapFitColors.textSecondaryOf(context), fontSize: 16.sp),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                },
              )
            : Text(
                _title,
                style: TextStyle(
                  color: SnapFitColors.textPrimaryOf(context),
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
        actions: [
          if (!_isEditMode)
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search, color: SnapFitColors.textPrimaryOf(context)),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchQuery = '';
                    _searchController.clear();
                  }
                });
              },
            ),
          IconButton(
            icon: Icon(_isEditMode ? Icons.check : Icons.edit_note_rounded, 
              color: _isEditMode ? SnapFitColors.accent : SnapFitColors.textPrimaryOf(context),
              size: 28.sp,
            ),
            onPressed: () {
              setState(() {
                _isEditMode = !_isEditMode;
                if (!_isEditMode && _isReordering) {
                  // Exit edit mode -> potentially save? 
                  // But user might want explicit save.
                  // For now, let's keep the 'Save' button logic separate or auto-save.
                }
              });
            },
          ),
          if (_isReordering && _isEditMode)
            TextButton(
              onPressed: _saveOrder,
              child: const Text('저장', style: TextStyle(color: SnapFitColors.accent, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _albums.isEmpty
          ? Center(
              child: Text(
                '앨범이 없습니다.',
                style: TextStyle(color: SnapFitColors.textSecondaryOf(context)),
              ),
            )
          : (() {
              final filteredAlbums = _albums.where((album) {
                if (_searchQuery.isEmpty) return true;
                final theme = (album.coverTheme ?? '').toLowerCase();
                final title = (album.title ?? '').toLowerCase();
                final q = _searchQuery.toLowerCase();
                return theme.contains(q) || title.contains(q) || album.id.toString().contains(q);
              }).toList();

              if (filteredAlbums.isEmpty) {
                return Center(
                  child: Text(
                    '검색 결과가 없습니다.',
                    style: TextStyle(color: SnapFitColors.textSecondaryOf(context)),
                  ),
                );
              }

              return ReorderableListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.w),
                itemCount: filteredAlbums.length,
                onReorder: _onReorder,
                buildDefaultDragHandles: false, // 커스텀 핸들 사용
                itemBuilder: (context, index) {
                  final album = filteredAlbums[index];

                  return Padding(
                    key: ValueKey(album.id),
                    padding: EdgeInsets.only(bottom: 12.w),
                    child: Row(
                      children: [
                        Expanded(
                          child: ListAlbumCard(
                            album: album,
                            currentUserId: widget.currentUserId,
                            onTap: () => HomeAlbumActions.openAlbum(context, ref, album),
                          ),
                        ),
                        if (_isEditMode) ...[
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.red.withOpacity(0.8), size: 24.w),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('앨범 삭제'),
                                  content: const Text('정말 이 앨범을 삭제하시겠습니까?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('삭제', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await ref.read(homeViewModelProvider.notifier).deleteAlbum(album);
                                setState(() {
                                  _albums.removeWhere((a) => a.id == album.id);
                                });
                              }
                            },
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: Padding(
                              padding: EdgeInsets.all(8.w),
                              child: Icon(Icons.drag_handle, color: SnapFitColors.textSecondaryOf(context), size: 24.w),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            })(),
    );
  }
}
