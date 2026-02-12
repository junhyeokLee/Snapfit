import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../domain/entities/album.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../viewmodels/home_view_model.dart';
import '../../views/add_cover_screen.dart';
import 'home_icon_buttons.dart';
import 'home_delete_album_dialog.dart';
import 'home_album_slider_card.dart';

/// PageController 보유, 스크롤 시 포커스(페이지) 기반 그림자/스케일 보간
/// 커버 가운데 아래 쪽에 추가/휴지통 원형 버튼 배치, 휴지통은 현 위치(포커스) 앨범만 삭제
class HomeAlbumSlider extends ConsumerStatefulWidget {
  final List<Album> albums;

  const HomeAlbumSlider({super.key, required this.albums});

  @override
  ConsumerState<HomeAlbumSlider> createState() => _HomeAlbumSliderState();
}

class _HomeAlbumSliderState extends ConsumerState<HomeAlbumSlider> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    // 한 화면에 "가운데 1장 + 양옆 카드가 동시에 보이도록" 설정
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
    final i = p.round().clamp(0, widget.albums.length - 1);
    return i;
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
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => const HomeDeleteAlbumDialog(),
    );
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
      // 연필 아이콘: "앨범 생성/커버 편집" 화면으로 이동해서 커버를 다시 수정할 수 있게 함
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddCoverScreen(editAlbum: album),
        ),
      );
      
      // 편집 후 돌아왔을 때 홈 화면 갱신
      if (context.mounted) {
        await ref.read(homeViewModelProvider.notifier).refresh();
      }
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
                return HomeAlbumSliderCard(
                  key: ValueKey('${album.id}_${album.coverLayersJson.hashCode}'),
                  album: album,
                  index: index,
                  pageController: _pageController,
                );
              },
            );
          },
        ),
        // 커버 가운데 아래 쪽 원형 버튼: 추가 / 휴지통 (현 위치 앨범만 삭제)
        Positioned(
          bottom: 80.h,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HomeCircleActionButton(
                icon: Icons.add,
                onPressed: () => _onAddPressed(context),
              ),
              SizedBox(width: 16.w),
              HomeCircleActionButton(
                icon: Icons.edit_outlined,
                onPressed: widget.albums.isEmpty ? null : () => _onEditPressed(context),
              ),
              SizedBox(width: 16.w),
              HomeCircleActionButton(
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
