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
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/cover_theme.dart';
import '../../../../../shared/widgets/image_frame_style_picker.dart';
import '../../../domain/entities/album.dart';
import '../../../domain/entities/layer.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../viewmodels/album_view_model.dart';
import '../../viewmodels/home_view_model.dart';
import '../../views/album_spread_screen.dart';

class EditCover extends ConsumerStatefulWidget {
  /// 편집 모드: 홈에서 앨범 선택 후 열었을 때 전달 (저장 성공 시 홈으로 pop)
  final Album? editAlbum;

  const EditCover({super.key, this.editAlbum});

  @override
  ConsumerState<EditCover> createState() => _EditCoverState();
}

class _EditCoverState extends ConsumerState<EditCover> {
  final GlobalKey _coverKey = GlobalKey();

  // 상태/컨트롤러
  late final EditCoverStateManager _state;
  late final CoverSizeController _layout;
  late final TextEditorManager _textEditor;
  late final ToolbarActionHandler _toolbar;
  late final LayerInteractionManager _interaction;
  late final LayerBuilder _layerBuilder;

  // 커버 메타
  Size _coverSize = Size.zero;
  bool _panelVisible = false;
  int _lastSelectedLayerIdHash = 0;
  late CoverSize _selectedCover;
  bool _isSaving = false; // 생성/저장 중 로딩 플래그
  bool _didInvalidateAlbumVm = false;

  @override
  void initState() {
    super.initState();
    _state = EditCoverStateManager();
    _layout = CoverSizeController();
    _selectedCover = coverSizes.firstWhere(
      (s) => s.name == '세로형',
      orElse: () => coverSizes.first,
    );

    // Album VM 연결 기반 에디터/툴바
    _textEditor = TextEditorManager(
      context,
      ref.read(albumEditorViewModelProvider.notifier),
    );
    _toolbar = ToolbarActionHandler(context, ref);

    // 인터랙션 매니저
    _interaction = LayerInteractionManager(
      ref: ref,
      coverKey: _coverKey,
      setState: setState,
      getCoverSize: () => _coverSize,
      onEditText: (layer) => _textEditor.openForExisting(layer),
    );
    // 레이어 빌더
    _layerBuilder = LayerBuilder(_interaction, () => _coverSize);

    // Cover VM + Album VM과 동기화 (앨범 생성 시 선택한 커버 사이즈 유지)
    Future.microtask(() {
      if (!_state.initialized) {
        final editorCover = ref.read(albumEditorViewModelProvider).asData?.value?.selectedCover;
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
    Future.microtask(() => setState(() {})); // 첫 frame 안정화
  }

  /// 현재 커버(CoverLayout)를 PNG 바이트로 캡처
  Future<Uint8List?> _captureCoverBytes() async {
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

    setState(() => _isSaving = true);
    final editorVm = ref.read(albumEditorViewModelProvider.notifier);

    try {
      // 1) 현재 커버를 그대로 캡처해서 합성 이미지 생성
      final coverBytes = await _captureCoverBytes();

      // 2) Firebase 업로드 + 대표 이미지 URL 생성 + 서버 저장
      //    coverImageBytes 로 합성 이미지를 함께 전달
      await editorVm.saveAlbumToBackend(
        _coverSize,
        coverImageBytes: coverBytes,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final albumSt = ref.watch(albumEditorViewModelProvider).asData?.value;
    final albumVm = ref.read(albumEditorViewModelProvider.notifier);
    final coverSt = ref.watch(coverViewModelProvider).asData?.value;
    final coverVm = ref.read(coverViewModelProvider.notifier);
    final layers = albumSt?.layers ?? [];
    final selectedCover = coverSt?.selectedCover ?? coverSizes.first;
    final aspect = selectedCover.ratio;
    final selectedTheme = coverSt?.selectedTheme ?? CoverTheme.classic;
    // 저장/생성 진행 표시: 로컬 플래그만 사용 (전역 VM 로딩에 의해 무한 로딩 방지)
    final isCreating = _isSaving;

    ref.listen<AsyncValue<Album?>>(albumViewModelProvider, (previous, next) {
      next.when(
        data: (album) {
          if (album != null) {
            if (!mounted) return;
            // 요구사항:
            // - + 버튼으로 들어온 신규 생성: 상단은 '완료' (완료 시 홈으로)
            // - 커버 탭/편집으로 들어온 기존 앨범: 상단은 '다음' (다음으로 페이지 편집으로)
            if (widget.editAlbum == null) {
              // 신규 생성(+ 진입): 생성 완료 후 홈으로 복귀 + 목록 갱신
              ref.read(homeViewModelProvider.notifier).refresh();
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
                MaterialPageRoute(builder: (_) => const AlbumSpreadScreen()),
              );
            }
          }
        },
        error: (err, st) {
          debugPrint('Album Creation Error: $err');
          debugPrint('StackTrace: $st');

          if (mounted) {
            final prefix = widget.editAlbum != null ? '앨범 저장 실패: ' : '앨범 생성 실패: ';
            final message = err is Exception ? err.toString().replaceFirst('Exception: ', '') : '$err';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$prefix$message')),
            );
          }
        },
        loading: () {
          // 상단 완료 버튼 + 전체 오버레이로 로딩 표시 중
        },
      );
    });


    return MediaQuery.removeViewInsets(
      removeBottom: true,
      context: context,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalH = constraints.maxHeight;

          // Expanded 영역(커버 캔버스)의 실제 높이
          final canvasHeight = totalH;

          // CoverSelectorWidget 높이 (툴바 정도 높이)
          final selectorHeight = kToolbarHeight;

          // 커버 가로 패딩 (좌우 여백은 기존 로직 유지)
          final coverSide = _layout.getCoverSidePadding(_selectedCover);

          // 커버를 화면 전체 기준 정중앙에 배치
          double coverTop;
          if (_coverSize == Size.zero) {
            // 초기 렌더링 - 화면 중앙 가정
            final estimatedCoverHeight = totalH * 0.5;
            coverTop = (totalH - estimatedCoverHeight) / 2;
          } else {
            // 화면 전체 기준 정중앙
            coverTop = (totalH - _coverSize.height) / 2;
          }

          // 텍스트 편집 모드 / 커버 테마 선택 모드일 때는 커버를 위로 이동 (정중앙 대비 일정 픽셀 위)
          if (_state.openEditText || _state.openCoverTheme) {
            // Move cover upward by a consistent visual offset across devices
            final double normalTop = (totalH - _coverSize.height) / 2;
            coverTop = (normalTop - 80.h).clamp(0, normalTop);
          }

          // 패널 높이 (현재 컨테이너는 kToolbarHeight 높이를 사용)
          final double panelHeight = kToolbarHeight;

          // 커버 하단(y) 계산
          final coverBottom = _coverSize == Size.zero
              ? coverTop
              : coverTop + _coverSize.height;

          // Expanded(canvas) 의 맨 아래 = 툴바가 시작되는 y 좌표
          final toolbarTopInCanvas = canvasHeight;

          // 커버 하단과 툴바 시작선 사이 중앙에 패널의 중앙 배치
          double panelCenter = (coverBottom + toolbarTopInCanvas) / 2;
          double panelTop = panelCenter - panelHeight;

          // 패널이 커버 바로 아래에서 너무 겹치지 않도록 최소 간격 보장
          final double minPanelTop = coverBottom;
          if (panelTop < minPanelTop) {
            panelTop = minPanelTop;
          }

          // 패널이 Expanded(canvas) 영역을 벗어나지 않도록 클램프
          if (panelTop + panelHeight > canvasHeight) {
            panelTop = math.max(0, canvasHeight - panelHeight);
          }

          // 패널 표시 여부 변경 감지 → 다음 프레임에서 애니메이션 트리거
          final currentHash = _interaction.selectedLayerId?.hashCode ?? 0;
          if (currentHash != _lastSelectedLayerIdHash) {
            _lastSelectedLayerIdHash = currentHash;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _panelVisible = _interaction.selectedLayerId != null;
                });
              }
            });
          }
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
                    // 커버 캔버스
                    Expanded(
                      child: Stack(
                        clipBehavior: Clip.none, // ✅ 커버 밖으로 보이게
                        children: [
                          // CoverSelectorWidget positioned directly above the cover, now animated
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOutCubicEmphasized,
                            top: math.max(0, coverTop - selectorHeight - 48.h),
                            left: 0,
                            right: 0,
                            child: Center(
                              child: SizedBox(
                                height: selectorHeight,
                                child: CoverSelectorWidget(
                                  sizes: coverSizes,
                                  selected: _selectedCover,
                                  iconForCover: _iconForCover,
                                  height: selectorHeight,
                                  onSelect: (s) {
                                    coverVm.selectCover(s);
                                    albumVm.selectCover(s);
                                    setState(() => _selectedCover = s);
                                  },
                                ),
                              ),
                            ),
                          ),
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOutCubicEmphasized,
                            top: coverTop,
                            left: coverSide,
                            right: coverSide,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: _interaction.clearSelection,
                              child: Stack(
                                clipBehavior: Clip.none,
                                // ✅ 레이어가 커버 밖으로 나가도 보이게
                                children: [
                                  RepaintBoundary(
                                    key: _coverKey,
                                    child: Container(
                                      clipBehavior: Clip.none, // ✅ 클리핑 방지
                                      child: CoverLayout(
                                          aspect: aspect,
                                          layers: _interaction.sortByZ(layers),
                                          isInteracting: false,
                                          leftSpine: 14.0,
                                          onCoverSizeChanged: (size) {
                                            if (_coverSize == size) return;
                                            WidgetsBinding.instance
                                                .addPostFrameCallback((_) {
                                              if (!mounted) return;
                                              setState(() {
                                                _coverSize = size;
                                              });
                                              albumVm.setCoverCanvasSize(size);
                                              // 홈에서 편집으로 들어온 경우: 실제 캔버스 크기 기준으로 레이어 1회 복원
                                              albumVm.loadPendingEditAlbumIfNeeded(size);
                                            });
                                          },
                                          buildImage: (layer) =>
                                              _layerBuilder.buildImage(layer),
                                          buildText: (layer) =>
                                              _layerBuilder.buildText(layer),
                                          sortedByZ: _interaction.sortByZ,
                                          theme: selectedTheme,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),  // cover
                          // === Sliding Action Panel: 커버 레이아웃 아래, 전체 Stack 상단 레벨 ===
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                            top: panelTop,
                            left: coverSide - 14.0,
                            right: coverSide - 14.0,
                            child: IgnorePointer(
                              ignoring: !_panelVisible,
                              child: AnimatedSlide(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOutCubic,
                                offset: _panelVisible
                                    ? const Offset(0, 0)
                                    : const Offset(1, 0),
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 250),
                                  opacity: _panelVisible ? 1 : 0,
                                  child: Container(
                                    height: kToolbarHeight,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7d7a97).withOpacity(0.92),
                                      borderRadius: BorderRadius.circular(16.r),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          blurRadius: 12.r,
                                          offset: Offset(0, 4.h),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (_interaction.selectedLayerId != null && layers.firstWhere((l) => l.id == _interaction.selectedLayerId,).type == LayerType.text)
                                          Row(
                                            children: [
                                              _buildTextStyleButton(
                                                "라벨",
                                                "tag",
                                              ),
                                              _buildTextStyleButton(
                                                "말풍선",
                                                "bubble",
                                              ),
                                              _buildTextStyleButton(
                                                "노트",
                                                "note",
                                              ),
                                              _buildTextStyleButton(
                                                "캘리",
                                                "calligraphy",
                                              ),
                                              _buildTextStyleButton(
                                                "스티커",
                                                "sticker",
                                              ),
                                              _buildTextStyleButton(
                                                "테이프",
                                                "tape",
                                              ),
                                            ],
                                          ),
                                        if (_interaction.selectedLayerId != null && layers.firstWhere((l) => l.id == _interaction.selectedLayerId).type == LayerType.image)
                                          _buildImageFrameStyleButton(layers),
                                        GestureDetector(
                                          onTap: () {
                                            _interaction.deleteSelected();
                                            setState(() {});
                                          },
                                          child: Container(
                                            width: 36,
                                            height: 36,
                                            margin: const EdgeInsets.only(right: 16),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.8),
                                              shape: BoxShape.circle,
                                            ),
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.delete,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 하단 툴바
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
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
                                // 커버와 키보드가 동시에 부드럽게 올라오도록 동시 실행
                                setState(() => _state.setTextOpen(true));

                                // 키보드와 모달을 바로 표시하면서 애니메이션과 동시에 렌더
                                final effectiveSize = _coverSize == Size.zero
                                    ? const Size(300, 200)
                                    : _coverSize;

                                // 프레임 안정화 전에 바로 모달 띄우기 (딜레이 없음)
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
                  ],  // Column children
                ),
              ),
              Positioned(
                top: kToolbarHeight + MediaQuery.of(context).padding.top,
                right: 16,
                child: GestureDetector(
                  onTap: isCreating ? null : _onCreateAlbum,
                  child: Text(
                    // 요구사항: + 진입은 '완료', 커버탭/편집 진입은 '다음'
                    widget.editAlbum == null ? '완료' : '다음',
                    style: TextStyle(
                      color: isCreating ? Colors.white70 : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
              // 저장 중 전체 화면 로딩 오버레이
              if (isCreating)
                Container(
                  color: Colors.black45,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildImageFrameStyleButton(List<LayerModel> layers) {
    final selectedId = _interaction.selectedLayerId;
    if (selectedId == null) return const SizedBox.shrink();

    final idx = layers.indexWhere((l) => l.id == selectedId);
    final currentKey = idx >= 0 ? (layers[idx].imageBackground ?? '') : '';

    return GestureDetector(
      onTap: () async {
        final id = _interaction.selectedLayerId;
        if (id == null) return;

        final result = await ImageFrameStylePicker.show(
          context,
          currentKey: currentKey,
        );
        if (result != null && mounted) {
          ref.read(albumEditorViewModelProvider.notifier).updateImageFrame(id, result);
          setState(() {});
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        margin: EdgeInsets.only(right: 12.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.95),
              Colors.white.withOpacity(0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8.r,
              offset: Offset(0, 2.h),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_size_select_actual, size: 18.sp, color: const Color(0xFF7d7a97)),
            SizedBox(width: 6.w),
            Text(
              '사진 스타일',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextStyleButton(String label, String key) {
    return GestureDetector(
      onTap: () {
        final id = _interaction.selectedLayerId;
        if (id == null) return;

        final albumVm = ref.read(albumEditorViewModelProvider.notifier);
        albumVm.updateTextStyle(id, key);

        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  IconData _iconForCover(CoverSize s) {
    final ratio = s.ratio;
    if (ratio > 1) return Icons.crop_landscape;
    if (ratio < 1) return Icons.crop_portrait;
    return Icons.crop_square;
  }
}
