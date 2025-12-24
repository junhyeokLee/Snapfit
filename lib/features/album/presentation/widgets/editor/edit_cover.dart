import 'dart:math' as math;
import 'package:flutter/material.dart';
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
import '../../../data/models/cover_size.dart';
import '../../../data/models/layer.dart';
import '../../../data/models/cover_theme.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../viewmodels/album_view_model.dart';

class EditCover extends ConsumerStatefulWidget {
  const EditCover({super.key});

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

    // Cover VM 초기화
    Future.microtask(() {
      if (!_state.initialized) {
        ref.read(coverViewModelProvider.notifier).selectCover(_selectedCover);
        _state.initialized = true;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Future.microtask(() => setState(() {})); // 첫 frame 안정화
  }

  void _onCreateAlbum() {
    final editorVm = ref.read(albumEditorViewModelProvider.notifier);
    final albumVm = ref.read(albumViewModelProvider.notifier);

    // 1. 현재 커버 레이어 상태를 JSON으로 변환
    final coverLayersJson = editorVm.exportCoverLayersJson(_coverSize);

    // 2. 커버 비율 (현재 선택된 커버)
    final coverRatio = _selectedCover.ratio;

    // 3. 서버에 앨범 생성 요청
    albumVm.createAlbum(
      coverLayersJson: coverLayersJson,
      coverRatio: coverRatio,
    );
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
                                  Container(
                                    key: _coverKey,
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
                                ],
                              ),
                            ),
                          ),
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
                                      color: Colors.black.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(0),
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
                                          Row(
                                            children: [
                                              _buildImageFrameButton("베이직", "polaroid"),
                                              _buildImageFrameButton("스티커", "sticker"),
                                              _buildImageFrameButton("빈티지", "vintage"),
                                              _buildImageFrameButton("필름", "film"),
                                            ],
                                          ),
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
                  ],
                ),
              ),
              Positioned(
                top: kToolbarHeight + MediaQuery.of(context).padding.top,
                right: 16,
                child: GestureDetector(
                  onTap: _onCreateAlbum,
                  child: const Text(
                    '생성',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildImageFrameButton(String label, String key) {
    return GestureDetector(
      onTap: () {
        final id = _interaction.selectedLayerId;
        if (id == null) return;

        final albumVm = ref.read(albumEditorViewModelProvider.notifier);
        albumVm.updateImageFrame(id, key);

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
