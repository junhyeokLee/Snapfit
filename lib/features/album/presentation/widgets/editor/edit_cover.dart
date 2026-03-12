import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:typed_data' as ui;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/cover_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/cover/cover.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/edit_toolbar.dart';
import 'package:snap_fit/features/album/presentation/controllers/cover_size_controller.dart';
import 'package:snap_fit/features/album/presentation/controllers/text_editor_manager.dart';
import 'package:snap_fit/features/album/presentation/controllers/toolbar_action_handler.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_interaction_manager.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_builder.dart';
import 'package:snap_fit/features/album/presentation/controllers/edit_cover_state_manager.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/edit_cover_selector.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/layer_manager_panel.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/cover_theme.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/utils/screen_logger.dart';
import '../../../../../shared/widgets/image_frame_style_picker.dart';
import '../../../domain/entities/album.dart';
import '../../../domain/entities/layer.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../viewmodels/album_view_model.dart';
import '../../viewmodels/home_view_model.dart';
import '../../viewmodels/gallery_notifier.dart'; // Add import
import '../../../../../shared/widgets/album_bottom_sheet.dart';
import '../../views/page_editor_screen.dart';
import './layer_action_panel.dart';
import './text_style_picker_sheet.dart';
import './edit_cover_top_bar.dart';
import './page_editor_overlays.dart';

class EditCover extends ConsumerStatefulWidget {
  /// 편집 모드: 홈에서 앨범 선택 후 열었을 때 전달 (저장 성공 시 홈으로 pop)
  final Album? editAlbum;

  /// 앨범 생성 플로우에서 사용되는지 여부 (생성 후 페이지 편집 화면으로 이동)
  final bool isFromCreateFlow;

  /// 앨범 생성 완료 콜백 (플로우에서 사용)
  final Function(int albumId)? onAlbumCreated;

  /// 플로우 AppBar '완료' 버튼용 액션 등록 (등록된 콜백이 _onCreateAlbum 호출)
  final void Function(VoidCallback)? onRegisterCompleteAction;

  /// 앨범 생성 플로우에서 넘어온 초기 커버 사이즈
  final CoverSize? initialCoverSize;

  /// 앨범 제목 (생성 플로우에서 사용)
  final String? albumTitle;

  /// 목표 페이지 수 (생성 플로우에서 사용)
  final int? targetPages;

  /// 상단 앱바 표시 여부 (PageEditorScreen 내에 임베딩될 때 false)
  final bool showAppBar;

  /// 하단 툴바 표시 여부 (PageEditorScreen 내 포함 시 중복 방지 위해 false 설정)
  final bool showBottomToolbar;

  /// 외부에서 전달받은 인터랙션 매니저 (PageEditorScreen 통합용)
  final LayerInteractionManager? interaction;
  final GlobalKey? canvasKey;
  final Function(Size)? onSizeChanged;

  const EditCover({
    super.key,
    this.editAlbum,
    this.isFromCreateFlow = false,
    this.onAlbumCreated,
    this.onRegisterCompleteAction,
    this.initialCoverSize,
    this.albumTitle,
    this.targetPages,
    this.showAppBar = true,
    this.showBottomToolbar = true,
    this.interaction,
    this.canvasKey,
    this.onSizeChanged,
  });

  @override
  ConsumerState<EditCover> createState() => EditCoverState();
}

class EditCoverState extends ConsumerState<EditCover> {
  final GlobalKey _coverKey = GlobalKey();
  final ValueNotifier<bool> showCoverSelectorNotifier = ValueNotifier(false);

  void openCoverSelector() {
    setState(() {
      _showCoverSelectorPanel = true;
    });
  }

  // 상태/컨트롤러
  late final EditCoverStateManager _state;
  late final CoverSizeController _layout;
  late final TextEditorManager _textEditor;
  late final ToolbarActionHandler _toolbar;
  late final LayerInteractionManager _interaction;
  late final LayerBuilder _layerBuilder;

  // 커버 메타
  Size _coverSize = Size.zero;
  late CoverSize _selectedCover;
  bool _isSaving = false; // 생성/저장 중 로딩 플래그
  bool _didInvalidateAlbumVm = false;
  bool _didRegisterCompleteAction = false;
  bool _didLogWidget = false;
  bool _showCoverSelectorPanel = false;
  
  // 저장 진행률 상태
  double _saveProgress = 0.0;
  Timer? _progressTimer;

  void _simulateProgress() {
    _saveProgress = 0.0;
    _progressTimer?.cancel();
    // 80ms 간격으로 빠르게 올라가다가 85% 이후 매우 서서히 크리프
    // → 자연스럽게 "준비 중" 느낌 유지, 멈춘 것처럼 보이지 않음
    _progressTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (_saveProgress < 0.85) {
          _saveProgress += 0.05;   // 85%까지 빠르게 (~1.4초)
        } else if (_saveProgress < 0.97) {
          _saveProgress += 0.003; // 85~97%: 극도로 느리게 (자연스러운 대기)
        } else {
          timer.cancel(); // 97%에서 멈춤 (완료 시 100% 점프)
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _state = EditCoverStateManager();
    _layout = CoverSizeController();
    _selectedCover = widget.initialCoverSize ??
        coverSizes.firstWhere(
          (s) => s.name == '정사각형',
          orElse: () => coverSizes.first,
        );

    // Album VM 연결 기반 에디터/툴바
    _textEditor = TextEditorManager(
      context,
      ref.read(albumEditorViewModelProvider.notifier),
    );
    _toolbar = ToolbarActionHandler(context, ref);

    // 인터랙션 매니저 (PageEditorScreen에서 전달받은 경우 우선 사용)
    _interaction = widget.interaction ?? LayerInteractionManager(
      ref: ref,
      coverKey: widget.canvasKey ?? _coverKey,
      setState: setState,
      // [10단계 Fix] 커버 편집 시에도 500xH 논리 좌표계를 사용함
      getCoverSize: () {
        final ratio = _selectedCover.ratio > 0 ? _selectedCover.ratio : 1.0;
        return Size(kCoverReferenceWidth, kCoverReferenceWidth / ratio);
      },
      onEditText: (layer) => _textEditor.openForExisting(layer),
      showSelectionControls: true, 
      showHandles: false, // 핸들 숨김, 테두리는 표시
    );
    // 레이어 빌더
    _layerBuilder = LayerBuilder(_interaction, () {
      final ratio = _selectedCover.ratio > 0 ? _selectedCover.ratio : 1.0;
      return Size(kCoverReferenceWidth, kCoverReferenceWidth / ratio);
    });

    // Cover VM + Album VM과 동기화 (앨범 생성 시 선택한 커버 사이즈 유지)
    Future.microtask(() {
      if (!mounted) return;
      if (!_state.initialized) {
        final editorCover = ref.read(albumEditorViewModelProvider).asData?.value.selectedCover;
        if (editorCover != null) {
          _selectedCover = editorCover;
          ref.read(coverViewModelProvider.notifier).selectCover(editorCover);
        } else {
          ref.read(coverViewModelProvider.notifier).selectCover(_selectedCover);
        }
        _state.initialized = true;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 다른 화면/이전 요청에서 남아있을 수 있는 전역 로딩 상태를 끊어준다.
    // initState에서는 InheritedWidget(ProviderScope) 참조가 불가해서 여기서 1회만 수행.
    if (!_didInvalidateAlbumVm) {
      _didInvalidateAlbumVm = true;
      ref.invalidate(albumViewModelProvider);
    }
    if (!_didLogWidget) {
      _didLogWidget = true;
      ScreenLogger.widget(
        'EditCover',
        widget.isFromCreateFlow ? '커버 편집 (플로우 Step 2)' : (widget.editAlbum != null ? '기존 앨범 커버 편집' : '신규 커버 편집'),
      );
    }
    // 플로우 AppBar '다음' 버튼이 이 메서드를 호출하도록 1회만 등록 (빌드 완료 후 실행해 setState during build 방지)
    if (!_didRegisterCompleteAction && widget.onRegisterCompleteAction != null) {
      _didRegisterCompleteAction = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onRegisterCompleteAction!(_onCreateAlbum);
      });
    }
    Future.microtask(() => setState(() {})); // 첫 frame 안정화
  }

  /// 현재 커버(CoverLayout)를 PNG 바이트로 캡처
  Future<Uint8List?> captureCoverBytes() async {
    try {
      final boundary =
          _coverKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      // 업로드 용량 최적화:
      // - pixelRatio를 과도하게 높이면 PNG 용량이 크게 증가함
      // - 이후 _resizePngBytes로 최대 변 길이를 제한
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null) return null;
      return await _resizePngBytes(bytes, maxDimension: 1024);
    } catch (e) {
      debugPrint('Cover capture error: $e');
      return null;
    }
  }

  /// PNG 바이트를 지정한 최대 변 길이로 리사이즈(다운스케일) 후 PNG로 재인코딩
  /// - 외부 패키지 없이 `ui.instantiateImageCodec` 사용
  /// - PNG는 포맷 특성상 JPEG/WebP보다 클 수 있지만, 해상도만 줄여도 용량이 크게 감소
  Future<Uint8List> _resizePngBytes(
    Uint8List pngBytes, {
    required int maxDimension,
  }) async {
    final ui.Codec codec = await ui.instantiateImageCodec(pngBytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image src = frame.image;

    final int w = src.width;
    final int h = src.height;
    final int longest = w > h ? w : h;

    // 이미 충분히 작으면 그대로 사용
    if (longest <= maxDimension) return pngBytes;

    final double scale = maxDimension / longest;
    final int targetW = (w * scale).round().clamp(1, maxDimension);
    final int targetH = (h * scale).round().clamp(1, maxDimension);

    final ui.Codec resizedCodec = await ui.instantiateImageCodec(
      pngBytes,
      targetWidth: targetW,
      targetHeight: targetH,
    );
    final ui.FrameInfo resizedFrame = await resizedCodec.getNextFrame();
    final ui.ByteData? out =
        await resizedFrame.image.toByteData(format: ui.ImageByteFormat.png);
    return out?.buffer.asUint8List() ?? pngBytes;
  }

  Future<void> _onCreateAlbum() async {
    if (_coverSize == Size.zero) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("화면 준비 중입니다. 잠시 후 다시 시도해주세요.")));
      return;
    }

    if (_isSaving) return; // 중복 클릭 방지

    setState(() {
      _isSaving = true;
      _simulateProgress();
    });
    
    final editorVm = ref.read(albumEditorViewModelProvider.notifier);

    try {
      final currentLayers = ref.read(albumEditorViewModelProvider).value?.layers ?? [];
      List<LayerModel>? sortedLayers;
      if (currentLayers.isNotEmpty) {
        sortedLayers = _interaction.sortByZ(currentLayers);
        editorVm.updatePageLayers(sortedLayers);
      }

      // 1) 현재 커버를 그대로 캡처해서 합성 이미지 생성
      final coverBytes = await captureCoverBytes();

      // 2) Firebase 업로드 + 대표 이미지 URL 생성 + 서버 저장
      //    coverImageBytes 로 합성 이미지를 함께 전달
      final createdAlbumId = await editorVm.saveAlbumToBackend(
        _coverSize,
        coverImageBytes: coverBytes,
        title: widget.albumTitle,
        targetPages: widget.targetPages,
        overrideLayers: sortedLayers,
      );
      
      if (createdAlbumId != null) {
        // 성공 시: 진행률 즉시 100%, 딜레이 없이 바로 화면 전환
        _progressTimer?.cancel();
        if (mounted) setState(() => _saveProgress = 1.0);

        // 짧은 tick으로 100% UI가 한 번 그려지게 한 뒤 즉시 이동
        await Future.microtask(() {});

        if (!mounted) return;
        
        // --- Navigation Logic Moved Here ---
        if (widget.isFromCreateFlow) {
           // 앨범 생성 플로우: 생성 완료 후 콜백 호출
           if (widget.onAlbumCreated != null) {
             widget.onAlbumCreated!(createdAlbumId);
           } else {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('앨범이 성공적으로 생성되었습니다!')),
             );
             Navigator.pushReplacement(
               context,
               MaterialPageRoute(builder: (_) => const PageEditorScreen(initialPageIndex: 1)),
             );
           }
        } else if (widget.editAlbum == null) {
           // 신규 생성(+ 진입): 목록 갱신 후 홈으로 복귀
           await ref.read(homeViewModelProvider.notifier).refresh();
           if (!mounted) return;
           
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('앨범이 성공적으로 생성되었습니다!')),
           );
           Navigator.popUntil(context, (route) => route.isFirst);
        } else {
           // 기존 앨범(커버 탭/편집): 다음 단계(페이지 편집)로 이동
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('저장되었습니다.')),
           );
           Navigator.push(
             context,
             MaterialPageRoute(builder: (_) => const PageEditorScreen()),
           );
        }
      } else {
         // 실패 (ID 반환 없음)
         if (mounted) setState(() => _isSaving = false);
      }
    } catch (e) {
      debugPrint('Error in _onCreateAlbum: $e');
      if (mounted) setState(() => _isSaving = false);
    } finally {
      // 성공 시에는 네비게이션이 일어나므로 _isSaving을 false로 돌리지 않음 (오버레이 유지)
      // 실패 케이스는 위에서 처리
      _progressTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final albumSt = ref.watch(albumEditorViewModelProvider).asData?.value;
    final albumVm = ref.read(albumEditorViewModelProvider.notifier);
    final coverSt = ref.watch(coverViewModelProvider).asData?.value;
    final coverVm = ref.read(coverViewModelProvider.notifier);
    final layers = albumSt?.layers ?? [];

    // 커버 사이즈 우선순위:
    // - 편집 모드: albumSt(서버 데이터) > coverSt > _selectedCover
    // - 생성 플로우: initialCoverSize > coverSt > albumSt > _selectedCover (Step1 선택값이 항상 우선)
    final selectedCover = widget.editAlbum != null
        ? (albumSt?.selectedCover ?? coverSt?.selectedCover ?? _selectedCover)
        : (widget.initialCoverSize ??
            coverSt?.selectedCover ??
            albumSt?.selectedCover ??
            _selectedCover);
    final aspect = selectedCover.ratio;

    // 테마도 동일한 우선순위 적용
    final selectedTheme = widget.editAlbum != null
        ? (albumSt?.selectedTheme ?? coverSt?.selectedTheme ?? CoverTheme.classic)
        : (coverSt?.selectedTheme ?? albumSt?.selectedTheme ?? CoverTheme.classic);

    // 커버 배경색: 현재 페이지(커버 페이지)의 backgroundColor를 그대로 사용
    // - AlbumEditorViewModel은 resetForCreate 시 index 0을 커버 페이지로 생성
    // - 데코 탭에서 updatePageBackgroundColor 호출 시, 현재 페이지의 backgroundColor가 변경됨
    final int? coverBgInt = albumVm.currentPage?.backgroundColor;
    final Color? coverBackgroundColor =
        coverBgInt != null ? Color(coverBgInt) : null;

    // _selectedCover 동기화
    if (_selectedCover != selectedCover) {
      _selectedCover = selectedCover;
    }
    // 저장/생성 진행 표시: 로컬 플래그만 사용 (전역 VM 로딩에 의해 무한 로딩 방지)
    final isCreating = _isSaving;

    ref.listen<AsyncValue<Album?>>(albumViewModelProvider, (previous, next) {
      next.when(
        data: (album) {
          // 성공 로직은 _onCreateAlbum에서 직접 처리함 (진행률 제어 및 네비게이션 통합)
        },
        error: (err, st) {
          debugPrint('Album Creation Error: $err');
          if (mounted) {
            setState(() => _isSaving = false); // 에러 발생 시 로딩 해제
            
            final prefix = widget.editAlbum != null ? '앨범 저장 실패: ' : '앨범 생성 실패: ';
            final message = err is Exception ? err.toString().replaceFirst('Exception: ', '') : '$err';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$prefix$message')),
            );
          }
        },
        loading: () {},
      );
    });


    return MediaQuery.removeViewInsets(
      removeBottom: true,
      context: context,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (details) {
                  if (!_interaction.isInCover(details.globalPosition)) {
                    _interaction.clearSelection();
                  }
                },
                child: Column(
                  children: [
                    // 탑바 (플로우가 아닐 때만 && showAppBar가 true일 때만)
                    if (!widget.isFromCreateFlow && widget.showAppBar)
                      EditCoverTopBar(
                        isCreating: isCreating,
                        isEditMode: widget.editAlbum != null,
                        onAction: _onCreateAlbum,
                      ),

                    // 커버 캔버스: Expanded (하단 툴바가 오버레이로 빠졌으므로 전체 높이 사용)
                    Expanded(
                      child: Container(
                        color: Colors
                            .transparent, // 상위(스냅핏 만들기/리더) 배경과 자연스럽게 이어지도록 투명 처리
                        child: LayoutBuilder(
                          builder: (context, canvasConstraints) {
                          final coverSide = _layout.getCoverSidePadding(selectedCover);

                          // Refactor: AlbumReader와 동일한 Center 구조




                          // 레이어 상태 동기화 (삭제된 레이어 캐시 정리)
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) _interaction.syncLayers(layers);
                          });

                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // 1. 커버 본체 (Center 정렬 - AlbumReaderCoverEditor와 동일 구조)
                              Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: coverSide),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onTap: _interaction.clearSelection,
                                    child: LayoutBuilder(
                                      builder: (context, coverConstraints) {
                                        final double availW = coverConstraints.maxWidth;
                                        final double availH = canvasConstraints.maxHeight;
                                        final double logicalW = kCoverReferenceWidth;
                                        final double logicalH = logicalW / aspect;

                                        // 모든 커버 유형이 같은 '최대 변' 길이를 갖도록 스케일 계산
                                        // → 정사각형(500×500)이 세로형(375×500)보다 면적이 더 크게 표시됨
                                        final double maxLogicalDim = logicalW > logicalH ? logicalW : logicalH;
                                        final double scaleByMaxDim = availW / maxLogicalDim;
                                        // 높이가 가용 영역을 넘지 않도록 제한
                                        final double scaleByHeight = availH / logicalH;
                                        final double scale = scaleByMaxDim < scaleByHeight ? scaleByMaxDim : scaleByHeight;
                                        final double displayW = logicalW * scale;
                                        final double displayH = logicalH * scale;
                                        debugPrint('[CoverSize] aspect=$aspect maxLogicalDim=${maxLogicalDim.toStringAsFixed(0)} scaleByMaxDim=${scaleByMaxDim.toStringAsFixed(3)} scaleByH=${scaleByHeight.toStringAsFixed(3)} → scale=${scale.toStringAsFixed(3)} displayW=${displayW.toStringAsFixed(0)} displayH=${displayH.toStringAsFixed(0)}');

                                        return SizedBox(
                                          width: displayW,
                                          height: displayH,
                                          child: FittedBox(
                                            fit: BoxFit.contain,
                                            child: SizedBox(
                                              width: logicalW,
                                              height: logicalH,
                                              child: CoverLayout(
                                                aspect: aspect,
                                                layers: _interaction.sortByZ(layers),
                                                isInteracting: _interaction.isInteractingNow,
                                                leftSpine: 14.0,
                                                backgroundColor: coverBackgroundColor,
                                                contentKey: widget.canvasKey ?? _coverKey,
                                                onCoverSizeChanged: (size) {
                                                  if (_coverSize == size) return;
                                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                                    if (!mounted) return;

                                                    setState(() {
                                                      _coverSize = size;
                                                    });
                                                    albumVm.setCoverCanvasSize(size);
                                                    widget.onSizeChanged?.call(size);
                                                    // 홈에서 편집으로 들어온 경우: 실제 캔버스 크기 기준으로 레이어 1회 복원
                                                    albumVm.loadPendingEditAlbumIfNeeded(size);
                                                  });
                                                },
                                                buildImage: (layer) => _layerBuilder.buildImage(layer, isCover: true),
                                                buildText: (layer) => _layerBuilder.buildText(layer, isCover: true),
                                                sortedByZ: _interaction.sortByZ,
                                                theme: selectedTheme,
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    ),
                                  ),
                                ),
                              ),

                        ],
                          ); // Stack
                        }, // LayoutBuilder builder
                      ), // LayoutBuilder
                    ), // Container
                  ), // Expanded
                  ],  // Column children
                ),
              ),

              // 하단 툴바 (Overlay) - AlbumReader와 동일하게 Positioned로 배치
              if (widget.showBottomToolbar)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 20.w),
                        decoration: BoxDecoration(
                          color: SnapFitColors.surfaceOf(context).withValues(alpha: 0.9), // theme support
                          borderRadius: BorderRadius.circular(18.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: SnapFitColors.isDark(context) ? 0.2 : 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Builder(
                          builder: (context) {
                            LayerModel? selected;
                            final selectedId = _interaction.selectedLayerId;
                            if (selectedId != null) {
                              final idx = layers.indexWhere(
                                (l) => l.id == selectedId,
                              );
                              if (idx != -1) selected = layers[idx];
                            }
                            return EditToolbar(
                              vm: albumVm,
                              selected: selected,
                              onAddText: () async {
                                setState(() => _state.setTextOpen(true));
                                final effectiveSize = _coverSize == Size.zero
                                    ? const Size(300, 200)
                                    : _coverSize;
                                Future.microtask(() async {
                                  await _textEditor.openAndCreateNew(
                                    Size(
                                      effectiveSize.width * 0.92,
                                      effectiveSize.height * 0.18,
                                    ),
                                  );
                                  if (mounted) {
                                    setState(() => _state.setTextOpen(false));
                                  }
                                });
                              },
                              onAddPhoto: () {
                                final size = _interaction.getCoverSize();
                                if (size.width > 0 && size.height > 0) {
                                  _toolbar.addPhoto(size);
                                }
                              },
                              onOpenCoverSelector: () async {
                                setState(() => _state.setThemeOpen(true));
                                await _toolbar.openCoverTheme();
                                if (mounted) {
                                  setState(() => _state.setThemeOpen(false));
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

              _buildLayerActionPanel(layers, albumVm),

              // 저장 중 진행률 오버레이
              if (isCreating)
                PageEditorSaveOverlay(progress: _saveProgress),
            ],
          );
        },
      ),
    );
  }

  /// 레이어 선택 액션 패널 오버레이 빌드
  /// PageEditorScreen에 임베딩된 경우(showBottomToolbar: false)에는 상위에서 하나만 표시하므로 여기선 숨김
  Widget _buildLayerActionPanel(List<LayerModel> layers, AlbumEditorViewModel albumVm) {
    if (_interaction.selectedLayerId == null) return const SizedBox.shrink();
    if (!widget.showBottomToolbar) return const SizedBox.shrink(); // 상위 LayerActionPanel 사용

    return Positioned(
      bottom: widget.showBottomToolbar ? 100.h : 20.h,
      left: 20.w,
      right: 20.w,
      child: LayerActionPanel(
        layers: layers,
        interaction: _interaction,
        textEditor: _textEditor,
        onRefresh: () => setState(() {}),
        onOpenGallery: (layer) => _openGalleryForSelected(layer),
        onOpenDecorateSheet: (layer) => _openDecorateSheetForLayer(layer),
      ),
    );
  }


  Future<void> _openGalleryForSelected(LayerModel layer) async {
    final gallery = ref.read(galleryProvider);
    if (gallery.albums.isEmpty) {
      await ref.read(galleryProvider.notifier).fetchInitialData();
    }
    
    final asset = await showPhotoSelectionSheet(context, ref);
    if (asset != null) {
      ref.read(albumEditorViewModelProvider.notifier).updateLayer(
        layer.copyWith(asset: asset, imageUrl: null, originalUrl: null, previewUrl: null),
      );
    }
  }

  void _openDecorateSheetForLayer(LayerModel layer) {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    if (layer.type == LayerType.image) {
      final currentKey = vm.findLayerById(layer.id)?.imageBackground ?? layer.imageBackground ?? '';
      ImageFrameStylePicker.show(context, currentKey: currentKey).then((key) {
        if (key != null && mounted) {
          vm.updateImageFrame(layer.id, key);
          setState(() {});
        }
      });
    } else {
      final currentKey = vm.findLayerById(layer.id)?.textBackground ?? layer.textBackground ?? '';
      TextStylePickerSheet.show(context, currentKey: currentKey).then((key) {
        if (key != null && mounted) {
          vm.updateTextStyle(layer.id, key);
          setState(() {});
        }
      });
    }
  }
}
