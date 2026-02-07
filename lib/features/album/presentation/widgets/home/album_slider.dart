import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../shared/widgets/circle_action_button.dart';
import '../../../../../shared/widgets/confirm_dialog.dart';
import '../../../domain/entities/album.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../viewmodels/home_view_model.dart';
import 'album_cover_card.dart';
import '../../views/add_cover_screen.dart';

/// PageController 보유, 스크롤 시 포커스(페이지) 기반 그림자/스케일 보간
/// 커버 가운데 아래 쪽에 추가/편집/휴지통 원형 버튼 배치
class AlbumSlider extends ConsumerStatefulWidget {
  final List<Album> albums;

  const AlbumSlider({super.key, required this.albums});

  @override
  ConsumerState<AlbumSlider> createState() => _AlbumSliderState();
}

class _AlbumSliderState extends ConsumerState<AlbumSlider> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.7);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int get _currentPage {
    final p = _pageController.page;
    if (p == null) return 0;
    return p.round().clamp(0, widget.albums.length - 1);
  }

  Future<void> _onAddPressed(BuildContext context) async {
    final created = await Navigator.pushNamed(context, '/add_cover');
    if (created == true && context.mounted) {
      await ref.read(homeViewModelProvider.notifier).refresh();
    }
  }

  Future<void> _onDeletePressed(BuildContext context) async {
    if (widget.albums.isEmpty) return;
    final album = widget.albums[_currentPage];
    final confirmed = await ConfirmDialog.showDeleteAlbum(context);
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(homeViewModelProvider.notifier).deleteAlbum(album);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('앨범이 삭제되었습니다.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }

  Future<void> _onEditPressed(BuildContext context) async {
    if (widget.albums.isEmpty) return;
    final album = widget.albums[_currentPage];
    try {
      final vm = ref.read(albumEditorViewModelProvider.notifier);
      await ref.read(albumEditorViewModelProvider.future);
      await vm.prepareAlbumForEdit(album);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddCoverScreen(editAlbum: album),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('앨범 편집을 열 수 없습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        AnimatedBuilder(
          animation: _pageController,
          builder: (context, _) {
            return PageView.builder(
              controller: _pageController,
              itemCount: widget.albums.length,
              itemBuilder: (context, index) {
                final album = widget.albums[index];
                return AlbumCoverCard(
                  album: album,
                  index: index,
                  pageController: _pageController,
                );
              },
            );
          },
        ),
        Positioned(
          bottom: 80.h,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleActionButton(
                icon: Icons.add,
                onPressed: () => _onAddPressed(context),
              ),
              SizedBox(width: 16.w),
              CircleActionButton(
                icon: Icons.edit_outlined,
                onPressed: widget.albums.isEmpty ? null : () => _onEditPressed(context),
              ),
              SizedBox(width: 16.w),
              CircleActionButton(
                icon: Icons.delete_outline,
                onPressed: widget.albums.isEmpty
                    ? null
                    : () => _onDeletePressed(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
