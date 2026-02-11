import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/edit_cover.dart';

import '../../../../core/constants/cover_size.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../../../shared/widgets/snapfit_gradient_background.dart';
import '../../data/api/album_provider.dart';
import '../../domain/entities/album.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../viewmodels/cover_view_model.dart';


/// 커버 편집 화면 (앨범 생성/편집 공통)
/// - editAlbum == null && albumId == null: 앨범 생성 모드 (새 커버 만들기)
/// - editAlbum != null: 앨범 편집 모드 (기존 커버 수정, 이미 prepareAlbumForEdit 호출됨)
/// - albumId != null: 앨범 ID로 앨범을 로드하여 편집 모드로 진입
/// 
/// 참고: 앨범 내부 페이지 편집은 AlbumSpreadScreen 사용
class AddCoverScreen extends ConsumerStatefulWidget {
  /// 편집 모드: 홈에서 앨범 선택 후 이 화면으로 올 때 전달 (이미 prepareAlbumForEdit 호출됨)
  final Album? editAlbum;
  
  /// 앨범 ID로 앨범을 로드하여 편집 모드로 진입 (앨범 생성 플로우에서 사용)
  final int? albumId;

  /// 앨범 생성 플로우에서 사용되는지 여부 (생성 후 페이지 편집 화면으로 이동)
  final bool isFromCreateFlow;

  /// 앨범 생성 플로우에서 선택된 커버 사이즈
  final CoverSize? initialCoverSize;

  /// 앨범 생성 완료 콜백 (플로우에서 사용)
  final Function(int albumId)? onAlbumCreated;

  /// 플로우 AppBar의 '완료' 버튼이 눌렸을 때 호출할 액션 등록 (플로우에서만 사용)
  final void Function(VoidCallback)? onRegisterCompleteAction;

  const AddCoverScreen({
    super.key,
    this.editAlbum,
    this.albumId,
    this.isFromCreateFlow = false,
    this.initialCoverSize,
    this.onAlbumCreated,
    this.onRegisterCompleteAction,
  });

  @override
  ConsumerState<AddCoverScreen> createState() => _AddCoverScreenState();
}

class _AddCoverScreenState extends ConsumerState<AddCoverScreen> {
  late final ScrollController _gridController;
  bool _initialized = false;
  late CoverSize _selectedCover;

  @override
  void initState() {
    super.initState();
    final mode = widget.editAlbum != null
        ? '기존 앨범 커버 편집'
        : widget.isFromCreateFlow
            ? '앨범 생성 플로우 · 커버 편집 (Step 2)'
            : '신규 앨범 커버 생성';
    ScreenLogger.enter('AddCoverScreen', mode);
    _gridController = ScrollController()
      ..addListener(() {
        final vm = ref.read(albumEditorViewModelProvider.notifier);
        if (_gridController.position.pixels >=
            _gridController.position.maxScrollExtent - 300) {
          vm.loadMore();
        }
      });

    // 플로우에서 넘어온 경우, 이미 선택된 커버 사이즈가 있을 수 있으므로 우선 사용
    _selectedCover = widget.initialCoverSize ??
        coverSizes.firstWhere(
          (s) => s.name == '정사각형',
          orElse: () => coverSizes.first,
        );

    // Provider 수정은 build 사이클 이후에 일어나야 하므로 항상 비동기로 처리한다.
    Future.microtask(() async {
      if (_initialized) return;

      if (widget.editAlbum == null && widget.albumId == null) {
        // 생성 플로우(신규 생성): 선택된 커버로 바로 초기화
        ref
            .read(albumEditorViewModelProvider.notifier)
            .resetForCreate(initialCover: _selectedCover);
      } else if (widget.editAlbum != null) {
        // 편집 모드: 에디터에 이미 로드됨 → 커버 VM만 동기화
        final editorSt =
            ref.read(albumEditorViewModelProvider).asData?.value;
        if (editorSt != null) {
          ref
              .read(coverViewModelProvider.notifier)
              .selectCover(editorSt.selectedCover);
          ref
              .read(coverViewModelProvider.notifier)
              .updateTheme(editorSt.selectedTheme);
        }
      } else if (widget.albumId != null) {
        // 앨범 ID로 앨범을 로드하여 편집 모드로 진입
        try {
          final albumRepository = ref.read(albumRepositoryProvider);
          final album =
              await albumRepository.fetchAlbum(widget.albumId.toString());
          await ref
              .read(albumEditorViewModelProvider.notifier)
              .prepareAlbumForEdit(album);

          // 커버 VM 동기화
          final editorSt =
              ref.read(albumEditorViewModelProvider).asData?.value;
          if (editorSt != null) {
            ref
                .read(coverViewModelProvider.notifier)
                .selectCover(editorSt.selectedCover);
            ref
                .read(coverViewModelProvider.notifier)
                .updateTheme(editorSt.selectedTheme);
          }
        } catch (e) {
          // 앨범 로드 실패 시 빈 커버로 시작
          ref
              .read(albumEditorViewModelProvider.notifier)
              .resetForCreate(initialCover: _selectedCover);
        }
      }

      _initialized = true;
    });
  }

  @override
  void dispose() {
    _gridController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(albumEditorViewModelProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final fixedMediaQuery = MediaQuery.of(context).copyWith(
          viewInsets: EdgeInsets.zero,   // 키보드가 viewInsets를 밀어내는걸 완전 무시
          padding: EdgeInsets.zero,      // SafeArea 밀림 제거
        );

        return MediaQuery(
          data: fixedMediaQuery,
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: SnapFitColors.backgroundOf(context),
            body: Container(
              color: SnapFitColors.backgroundOf(context),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: EditCover(
                      editAlbum: widget.editAlbum,
                      isFromCreateFlow: widget.isFromCreateFlow,
                      onAlbumCreated: widget.onAlbumCreated,
                      onRegisterCompleteAction: widget.onRegisterCompleteAction,
                      initialCoverSize: _selectedCover,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}