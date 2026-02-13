import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../viewmodels/cover_view_model.dart';
import '../../viewmodels/home_view_model.dart';
import '../../views/add_cover_screen.dart';
import '../../views/album_reader_screen.dart';
import 'home_delete_album_dialog.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/utils/screen_logger.dart';
import '../../../data/api/album_provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';


/// 앨범 액션 관련 헬퍼 클래스
class HomeAlbumActions {
  /// 앨범 편집 선택 처리
  static Future<void> onEditSelected(
    BuildContext context,
    WidgetRef ref,
    dynamic album,
  ) async {
    try {
      final vm = ref.read(albumEditorViewModelProvider.notifier);
      await ref.read(albumEditorViewModelProvider.future);
      await vm.prepareAlbumForEdit(album);
      // prepareAlbumForEdit 완료 후 상태가 반영될 때까지 대기
      await ref.read(albumEditorViewModelProvider.future);
      // coverViewModelProvider도 완전히 반영될 때까지 대기
      await ref.read(coverViewModelProvider.future);
      // 최종 확인: editorState와 coverState가 동기화되었는지 확인하고 수동으로 동기화
      final editorState = ref.read(albumEditorViewModelProvider).asData?.value;
      final coverState = ref.read(coverViewModelProvider).asData?.value;
      if (editorState != null) {
        // 확실하게 동기화 (항상 실행하여 상태가 반영되도록 보장)
        ref.read(coverViewModelProvider.notifier).selectCover(editorState.selectedCover);
        ref.read(coverViewModelProvider.notifier).updateTheme(editorState.selectedTheme);
        // 동기화 후 상태가 반영될 때까지 대기
        await ref.read(coverViewModelProvider.future);
      }
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

  /// 앨범 삭제 선택 처리
  static Future<void> onDeleteSelected(
    BuildContext context,
    WidgetRef ref,
    dynamic album,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
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



  /// 앨범 열기 (리더 화면)
  static Future<void> openAlbum(
    BuildContext context,
    WidgetRef ref,
    dynamic album,
  ) async {
    // 1. 잠금 시도 (Lock)
    final repository = ref.read(albumRepositoryProvider);
    try {
      await repository.lockAlbum(album.id);
    } catch (e) {
      if (!context.mounted) return;
      // 잠금 실패 (다른 사용자가 편집 중)
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: SnapFitColors.surfaceOf(ctx),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          title: Text(
            '편집 제한',
            style: TextStyle(
              color: SnapFitColors.textPrimaryOf(ctx),
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
            ),
          ),
          content: Text(
            '현재 다른 사용자가 편집 중입니다.\n잠시 후 다시 시도해 주세요.',
            style: TextStyle(
              color: SnapFitColors.textSecondaryOf(ctx),
              fontSize: 14.sp,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('확인', style: TextStyle(color: SnapFitColors.accent)),
            ),
          ],
        ),
      );
      return;
    }

    // 2. 편집 준비
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    await ref.read(albumEditorViewModelProvider.future);
    await vm.prepareAlbumForEdit(album);
    
    if (!context.mounted) {
      // 만약 준비 중 화면이 닫혔다면 잠금 해제 필요
      try {
        await repository.unlockAlbum(album.id);
      } catch (_) {}
      return;
    }

    // 3. 진입
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AlbumReaderScreen()),
    );

    // 4. 복귀 시 잠금 해제 (Unlock)
    try {
      await repository.unlockAlbum(album.id);
    } catch (e) {
      debugPrint('HomeAlbumActions: Unlock failed: $e');
    }
  }
}
