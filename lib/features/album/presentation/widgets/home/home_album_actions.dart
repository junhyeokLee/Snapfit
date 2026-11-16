import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/utils/context_extensions.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/navigation/web_app_location.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../viewmodels/cover_view_model.dart';
import '../../viewmodels/home_view_model.dart';
import '../../providers/album_edit_session_provider.dart';
import '../../views/add_cover_screen.dart';
import '../../views/page_editor_screen.dart';
import '../../views/album_reader_screen.dart';
import '../../utils/album_progress.dart';
import '../../../domain/entities/album.dart';
import 'home_delete_album_dialog.dart';
import 'home_album_paper_open_overlay.dart';
import 'album_open_origin.dart';
import '../../../data/api/album_provider.dart';
import '../../../service/album_collaboration_session.dart';
import '../../../../../shared/widgets/snapfit_motion.dart';
import '../../../../social/presentation/views/social_publish_screen.dart';

/// 앨범 액션 관련 헬퍼 클래스
class HomeAlbumActions {
  static bool _isOpeningAlbum = false;
  static String? _openingActor;
  static int _openingRevision = 0;
  static bool _isPreparingEdit = false;
  static String? _preparingEditActor;
  static int _editPreparationRevision = 0;
  static Completer<void>? _readerLifecycle;
  static Future<void> waitForReaderToClose() =>
      _readerLifecycle?.future ?? Future<void>.value();

  /// Publishing starts from the complete saved document, never the compact
  /// library record or the editor's uncommitted canvas.
  static Future<void> onPublishSelected(
    BuildContext context,
    WidgetRef ref,
    Album album,
  ) async {
    final actor = ref.read(albumCollaborationActorProvider);
    if (album.id <= 0) {
      context.showSnack('먼저 앨범을 저장한 뒤 공개해 주세요.');
      return;
    }
    try {
      final saved = await ref
          .read(albumRepositoryProvider)
          .fetchAlbum('${album.id}');
      if (!context.mounted ||
          ref.read(albumCollaborationActorProvider) != actor)
        return;
      await Navigator.of(context).push<void>(
        snapFitRoute<void>(page: SocialPublishScreen(album: saved), settings: WebAppRouteSettings(
            WebAppLocation(WebAppPage.socialPublish, '${saved.id}'),
          )),
      );
    } catch (_) {
      if (context.mounted &&
          ref.read(albumCollaborationActorProvider) == actor) {
        context.showErrorSnack('공개할 앨범을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.');
      }
    }
  }

  /// 앨범 편집 선택 처리
  static Future<void> onEditSelected(
    BuildContext context,
    WidgetRef ref,
    dynamic album, {
    bool startWithPages = false,
    bool startAtFirstIncompletePage = false,
    bool onePageGoal = false,
    bool returnToPreviousOnSave = false,
    bool Function()? canContinue,
    VoidCallback? onEditorClosed,
  }) async {
    if (!context.mounted || canContinue?.call() == false) return;
    final actor = ref.read(albumCollaborationActorProvider);
    if (album is Album && !album.allowsEditing) {
      context.showSnack('보기 전용 앨범이에요. 편집 권한을 요청해 주세요.');
      return;
    }
    // Preparing mutates the shared editor. Two taps must not reset it twice or
    // push duplicate routes while the saved document is still being fetched.
    if (_isPreparingEdit && _preparingEditActor == actor) return;
    _isPreparingEdit = true;
    _preparingEditActor = actor;
    final preparation = ++_editPreparationRevision;
    bool current() =>
        context.mounted &&
        preparation == _editPreparationRevision &&
        ref.read(albumCollaborationActorProvider) == actor &&
        canContinue?.call() != false;
    void accountChanged(String? next) {
      if (next == actor || preparation != _editPreparationRevision) return;
      _editPreparationRevision++;
      _isPreparingEdit = false;
      _preparingEditActor = null;
    }

    final accountChanges = ref.listenManual<String?>(
      albumCollaborationActorProvider,
      (_, next) => accountChanged(next),
    );
    // UI-derived providers may batch A → B → A into an unchanged value. Listen
    // to auth events as well, so an intervening sign-out/account change always
    // invalidates this preparation. Same-account token refreshes remain valid.
    final sessionChanges = ref.listenManual<AsyncValue<String?>>(
      albumEditorOwnerChangesProvider,
      (_, next) {
        if (next.hasValue) accountChanged(next.value);
      },
    );
    try {
      if (!current()) return;
      var editableAlbum = album;
      if (startAtFirstIncompletePage && album is Album && album.id > 0) {
        final freshAlbum = await ref
            .read(albumRepositoryProvider)
            .fetchAlbum('${album.id}');
        if (!current()) return;
        // Access helpers are extension getters, so keep this value typed until
        // permission validation is complete instead of invoking via dynamic.
        if (!freshAlbum.allowsEditing) {
          context.showSnack('보기 전용 앨범이에요. 편집 권한을 요청해 주세요.');
          return;
        }
        editableAlbum = freshAlbum;
      }
      final vm = ref.read(albumEditorViewModelProvider.notifier);
      await ref.read(albumEditorViewModelProvider.future);
      if (!current()) return;
      await vm.prepareAlbumForEdit(editableAlbum);
      // prepareAlbumForEdit 완료 후 상태가 반영될 때까지 대기
      await ref.read(albumEditorViewModelProvider.future);
      if (!current()) return;
      // coverViewModelProvider도 완전히 반영될 때까지 대기
      await ref.read(coverViewModelProvider.future);
      if (!current()) return;
      // 최종 확인: editorState와 coverState가 동기화되었는지 확인하고 수동으로 동기화
      final editorState = ref.read(albumEditorViewModelProvider).asData?.value;
      if (editorState != null) {
        // 확실하게 동기화 (항상 실행하여 상태가 반영되도록 보장)
        ref
            .read(coverViewModelProvider.notifier)
            .selectCover(editorState.selectedCover);
        ref
            .read(coverViewModelProvider.notifier)
            .updateTheme(editorState.selectedTheme);
        // 동기화 후 상태가 반영될 때까지 대기
        await ref.read(coverViewModelProvider.future);
      }
      if (!current()) return;
      final albumId = vm.album?.id;
      if (startAtFirstIncompletePage) {
        // Preparation defers the saved layers until a canvas size is known.
        // Restore once at the same reference size used by PageEditorScreen
        // before inspecting content; its preallocated pages are still empty.
        vm.loadPendingEditAlbumIfNeeded(
          Size(
            kCoverReferenceWidth,
            kCoverReferenceWidth / vm.selectedCover.ratio,
          ),
        );
      }
      // Use the just-loaded pages, not a cached library record: another editor
      // or a monthly-photo append may have changed which page needs attention.
      final pages = vm.pages;
      final firstInterior = pages.indexWhere((page) => !page.isCover);
      final incompletePage = firstIncompleteAlbumPageIndex(pages);
      if (onePageGoal && incompletePage == null) {
        ref.invalidate(homeViewModelProvider);
        context.showSnack('이 앨범의 내지는 이미 완성됐어요.');
        return;
      }
      final initialPage = startAtFirstIncompletePage
          ? incompletePage ?? (firstInterior >= 0 ? firstInterior : 0)
          : 0;
      final editing = Navigator.push(
        context,
        snapFitRoute(page: startWithPages || startAtFirstIncompletePage
              ? PageEditorScreen(
                  initialPageIndex: initialPage,
                  onePageGoal: onePageGoal,
                  returnToPreviousOnSave: returnToPreviousOnSave,
                  initialSelectedLayerId: onePageGoal
                      ? preparedAlbumPageProgress(
                          pages[initialPage],
                        ).firstUnfilledPhotoId
                      : null,
                )
              : AddCoverScreen(editAlbum: album), settings: albumId != null && albumId > 0
              ? WebAppRouteSettings(
                  WebAppLocation(WebAppPage.editor, '$albumId'),
                )
              : null),
      );
      if (onEditorClosed != null) {
        // The preparation lock ends now; refresh the caller only after editing.
        unawaited(
          editing.then((_) {
            if (context.mounted) onEditorClosed();
          }),
        );
      }
    } catch (e) {
      if (current()) {
        context.showErrorSnack('앨범 편집을 열 수 없습니다: $e');
      }
    } finally {
      accountChanges.close();
      sessionChanges.close();
      // Release after navigation starts; callers do not await editor closure.
      // A superseded request must not release a newer account's preparation.
      if (preparation == _editPreparationRevision) {
        _isPreparingEdit = false;
        _preparingEditActor = null;
      }
    }
  }

  /// 앨범 삭제 선택 처리
  static Future<void> onDeleteSelected(
    BuildContext context,
    WidgetRef ref,
    dynamic album,
  ) async {
    final actor = ref.read(albumCollaborationActorProvider);
    if (album is Album && !album.allowsManagement) {
      context.showSnack('앨범 삭제는 소유자만 할 수 있어요.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => const HomeDeleteAlbumDialog(),
    );
    if (confirmed != true ||
        !context.mounted ||
        ref.read(albumCollaborationActorProvider) != actor)
      return;
    try {
      await ref.read(homeViewModelProvider.notifier).deleteAlbum(album);
      if (context.mounted &&
          ref.read(albumCollaborationActorProvider) == actor) {
        context.showSnack('앨범이 삭제되었습니다.');
      }
    } catch (e) {
      if (context.mounted &&
          ref.read(albumCollaborationActorProvider) == actor) {
        context.showErrorSnack('삭제 실패: $e');
      }
    }
  }

  /// 앨범 열기 (리더 화면)
  static Future<void> openAlbum(
    BuildContext context,
    WidgetRef ref,
    dynamic album, {
    void Function(int deletedAlbumId)? onAlbumDeleted,
    AlbumOpenOrigin? Function()? coverOrigin,
    VoidCallback? onReaderOpened,
    bool Function()? canContinue,
  }) async {
    final actor = ref.read(albumCollaborationActorProvider);
    // A request for a previous account must not hold the new account's entry.
    if (_isOpeningAlbum && _openingActor == actor) {
      return;
    }
    _isOpeningAlbum = true;
    _openingActor = actor;
    final revision = ++_openingRevision;
    bool current() =>
        context.mounted &&
        revision == _openingRevision &&
        ref.read(albumCollaborationActorProvider) == actor &&
        canContinue?.call() != false;
    final lifecycle = Completer<void>();
    _readerLifecycle = lifecycle;

    var needsRefresh = false;

    try {
      if (!current()) return;
      // Reading does not mutate album locks. Editing uses server CAS protection.

      // 1. 편집 준비
      final vm = ref.read(albumEditorViewModelProvider.notifier);
      await ref.read(albumEditorViewModelProvider.future);
      if (!current()) return;
      await vm.prepareAlbumForEdit(album);

      if (!current()) {
        return;
      }

      // 2. 진입 (리더 화면으로 이동)
      final initialSpreadIndex = 0;
      final selectedCover = vm.selectedCover;
      final baseCanvasSize = Size(
        kCoverReferenceWidth,
        kCoverReferenceWidth / selectedCover.ratio,
      );
      final fallbackAsset = selectedCover.ratio < 0.88
          ? 'assets/snapfit_home_portrait.jpg'
          : selectedCover.ratio > 1.12
          ? 'assets/snapfit_home_landscape.jpg'
          : 'assets/snapfit_home_square.jpg';
      final openOverlay =
          !kIsWeb && album is Album && !SnapFitMotion.reduced(context)
          ? HomeAlbumPaperOpenOverlay.show(
              context,
              album: album,
              baseCanvasSize: baseCanvasSize,
              fallbackAsset: fallbackAsset,
              origin: coverOrigin?.call(),
            )
          : null;

      if (!current()) return;
      final readerCoverKey = GlobalKey();
      final coverVisible = ValueNotifier<bool>(openOverlay == null);
      final albumId = vm.album?.id;
      final readerSettings = albumId != null && albumId > 0
          ? WebAppRouteSettings(WebAppLocation(WebAppPage.album, '$albumId'))
          : null;
      // Lay out the real reader underneath, then land on its measured cover.
      // Its cover remains hidden until the moving copy reaches the same pixels.
      try {
        final routeResult = Navigator.push<Object?>(
          context,
          kIsWeb
              ? snapFitRoute<Object?>(page: AlbumReaderScreen(initialSpreadIndex: initialSpreadIndex), settings: readerSettings)
              : openOverlay == null
              ? snapFitAlbumOpenRoute<Object?>(
                  settings: readerSettings,
                  page: AlbumReaderScreen(
                    initialSpreadIndex: initialSpreadIndex,
                  ),
                )
              : PageRouteBuilder<Object?>(
                  settings: readerSettings,
                  pageBuilder: (_, __, ___) => AlbumReaderScreen(
                    initialSpreadIndex: initialSpreadIndex,
                    openingCoverKey: readerCoverKey,
                    openingCoverVisible: coverVisible,
                  ),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: SnapFitMotion.fast,
                ),
        );
        onReaderOpened?.call();
        unawaited(
          routeResult.then<void>((_) {
            openOverlay?.dismiss();
          }),
        );
        if (openOverlay != null) {
          await openOverlay.moveTo(readerCoverKey);
          coverVisible.value = true;
          openOverlay.dismiss();
        }
        final result = await routeResult;
        if (!current()) return;

        if (result is Map) {
          final deletedAlbumId = result['deletedAlbumId'];
          if (deletedAlbumId is int) {
            onAlbumDeleted?.call(deletedAlbumId);
            needsRefresh = true;
          }
          final leftAlbumId = result['leftAlbumId'];
          if (leftAlbumId is int) {
            onAlbumDeleted?.call(leftAlbumId);
            needsRefresh = true;
          }
          if (result['updated'] == true) {
            needsRefresh = true;
          }
        } else if (result == true) {
          needsRefresh = true;
        }
      } finally {
        openOverlay?.dismiss();
        coverVisible.dispose();
      }
    } finally {
      if (revision == _openingRevision) {
        _isOpeningAlbum = false;
        _openingActor = null;
      }
      lifecycle.complete();
      if (identical(_readerLifecycle, lifecycle)) _readerLifecycle = null;
      if (context.mounted &&
          ref.read(albumCollaborationActorProvider) == actor &&
          needsRefresh == true) {
        ref.read(homeViewModelProvider.notifier).refresh();
      }
    }
  }
}
