import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/utils/app_logger.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/cover_size.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import '../../domain/entities/layer.dart';
import '../widgets/editor/selection_frame.dart';

/// 스타일 레이어 인터랙션 관리자
/// 이미지/텍스트 레이어의 드래그, 회전, 확대/축소를 처리.
class LayerInteractionManager {
  final WidgetRef ref;
  final GlobalKey coverKey; // 커버 영역의 위치/크기를 얻기 위한 키
  final void Function(void Function()) setState; // UI 업데이트 함수
  final Size Function() getCoverSize; // 커버 크기 getter
  final void Function(LayerModel layer) onEditText; // 텍스트 편집 콜백
  /// 레이어 탭 시 콜백 (메뉴 표시용)
  final void Function(LayerModel layer)? onLayerTap;

  /// 이미지 플레이스홀더(사진 없음) 탭 시 콜백 – 페이지 편집에서 바로 갤러리 진입용
  final void Function(LayerModel layer)? onTapPlaceholder;

  /// 읽기 전용 미리보기 모드 (제스처 없음, 레이어만 표시)
  final bool _isPreviewMode;

  /// 선택 시 테두리/핸들 표시 여부 (EditCover에서는 false로 설정하여 기존 UI 유지)
  final bool showSelectionControls;

  /// 선택 핸들 표시 여부 (false면 테두리만 표시)
  final bool showHandles;

  // ==================== 레이어 상태 저장소 ====================
  final Map<String, Offset> _pos = {}; // 레이어 위치 (좌상단 기준)
  final Map<String, double> _scale = {}; // 레이어 배율 (1.0 = 원본 크기)
  final Map<String, double> _rot = {}; // 레이어 회전 (라디안)
  final Map<String, Size> _refBaseSize = {}; // 레이어 원본 크기
  final Map<String, int> _z = {}; // Z-index (레이어 쌓임 순서)
  final Map<String, GlobalKey> _layerKeys =
      {}; // 각 레이어의 Transform 노드용 키 (글로벌 좌표 계산용)
  int _zCounter = 0; // Z-index 카운터

  // ==================== 인터랙션 상태 ====================
  String? _selectedLayerId; // 현재 선택된 레이어 ID
  String? _editingLayerId; // 현재 편집 중인 레이어 ID (텍스트만)

  /// 현재 제스처(이동/확대/회전) 중인지 여부
  bool get isInteractingNow => _gestureStates.isNotEmpty;

  // ==================== 제스처 추적 ====================
  final Map<String, _GestureState> _gestureStates = {}; // 제스처 시작 시점의 상태 저장

  /// 리사이즈(핸들 드래그) 상태
  _ResizeState? _resizeState;

  /// 이미지 슬롯 안에서 "사진만" 이동시키는 모드 (툴바 토글)
  bool _imagePanMode = false;

  // ==================== 스냅 가이드 표시 ====================
  bool _showVerticalGuide = false; // 세로 중앙선 표시 여부
  bool _showHorizontalGuide = false; // 가로 중앙선 표시 여부
  bool _showDiagonalGuide = false; // 대각선 표시 여부

  // ==================== 애니메이션 ====================
  Ticker? _activeTicker; // 현재 실행 중인 애니메이션 티커

  // ==================== 물리 파라미터 ====================

  // 스케일 제한
  static const double _minScale = 0.3; // 최소 배율 (30%)
  static const double _maxScale = 3.0; // 최대 배율 (300%)
  static const double _scaleOvershoot = 0.3; // 범위 초과 시 저항 계수

  // 회전 설정
  static const double _rotationResponsiveness = 0.90; // 회전 감도 (0~1)
  static const double _rotationDeadzone = 0.001; // 회전 데드존 (의도하지 않은 회전 방지)
  // static const double _rotationDeadzone = 0.10; // 회전 데드존 (의도하지 않은 회전 방지)

  // 드래그 설정
  static const double _dragMaxSpeed = 12.0; // 프레임당 최대 이동 거리 (픽셀)

  // 스냅 동작
  static const double _snapThreshold = 24.0; // 스냅 활성화 거리 (픽셀) — 조금 더 멀리서도 잡히게
  static const double _snapCenterExactThreshold =
      4.0; // 이 거리 이내면 중앙에 정확히 맞춤 (픽셀)
  static const double _snapStrength =
      0.4; // 스냅 당김 강도 (0~1) — 약하게 해서 원하는 위치 맞추기 쉽게
  // static const double _angleSnapThreshold = 0.087; // 각도 스냅 임계값 (~5도)
  static const double _angleSnapThreshold =
      0.12; // 각도 스냅 임계값 (~7도) — 너무 세지 않게 약간 완화
  // static const double _angleSnapStrength = 0.35; // 각도 스냅 강도 (0~1)
  static const double _angleSnapStrength = 0.25; // 각도 스냅 강도 — 0/90도 근처에서 확실히 스냅

  // 스냅 각도 목록 (0°, 45°, 90°, 135°, 180°, -45°, -90°, -135°)
  static const List<double> _snapAngles = [
    0.0,
    math.pi / 4,
    math.pi / 2,
    3 * math.pi / 4,
    math.pi,
    -math.pi / 4,
    -math.pi / 2,
    -3 * math.pi / 4,
  ];

  LayerInteractionManager({
    required this.ref,
    required this.coverKey,
    required this.setState,
    required this.getCoverSize,
    required this.onEditText,
    this.onLayerTap,
    this.onTapPlaceholder,
    bool isPreviewMode = false,
    this.showSelectionControls = true,
    this.showHandles = true,
  }) : _isPreviewMode = isPreviewMode;

  /// 읽기 전용 미리보기용 (앨범 보기, 커버 카드 등) – 제스처 없이 레이어만 표시
  static LayerInteractionManager preview(
    WidgetRef ref,
    Size Function() getCoverSize,
  ) {
    return LayerInteractionManager(
      ref: ref,
      coverKey: GlobalKey(),
      setState: (_) {},
      getCoverSize: getCoverSize,
      onEditText: (_) {},
      onTapPlaceholder: null,
      isPreviewMode: true,
    );
  }

  // ==================== Getters / Setters ====================

  /// 외부(export용) zIndex 조회
  int getZIndex(String layerId) {
    return _z[layerId] ?? 0;
  }

  String? get selectedLayerId => _selectedLayerId;

  bool get isImagePanMode => _imagePanMode;

  GlobalKey _getLayerKey(String id) {
    return _layerKeys.putIfAbsent(id, () => GlobalKey());
  }

  /// 현재 선택된 레이어의 화면(Global) 좌표 Rect를 계산
  /// - PageEditorScreen에서 툴바 위치를 잡을 때 사용
  Rect? getSelectedLayerGlobalRect() {
    final selectedId = _selectedLayerId;
    if (selectedId == null) return null;
    final key = _layerKeys[selectedId];
    if (key == null) return null;
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;

    // Transform(회전/스케일)까지 모두 반영된 실제 그리기 영역의
    // 축 기준 경계 박스를 계산한다.
    final size = box.size;
    final points = <Offset>[
      box.localToGlobal(Offset.zero),
      box.localToGlobal(Offset(size.width, 0)),
      box.localToGlobal(Offset(0, size.height)),
      box.localToGlobal(Offset(size.width, size.height)),
    ];

    double minX = points.first.dx;
    double maxX = points.first.dx;
    double minY = points.first.dy;
    double maxY = points.first.dy;
    for (final p in points.skip(1)) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// 현재 선택된 레이어의 "테두리 중앙 아래" 지점(Global 좌표)
  Offset? getSelectedLayerBottomCenterGlobal() {
    final rect = getSelectedLayerGlobalRect();
    if (rect == null) return null;
    return Offset(rect.center.dx, rect.bottom);
  }

  /// 현재 선택된 레이어의 "테두리 중앙 위" 지점(Global 좌표)
  Offset? getSelectedLayerTopCenterGlobal() {
    final rect = getSelectedLayerGlobalRect();
    if (rect == null) return null;
    return Offset(rect.center.dx, rect.top);
  }

  /// 커버(캔버스)의 화면(Global) 좌표 Rect
  Rect? getCoverGlobalRect() {
    final ctx = coverKey.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    final size = box.size;
    return Rect.fromLTWH(topLeft.dx, topLeft.dy, size.width, size.height);
  }

  /// 현재 선택된 이미지 레이어에 대해 사진 이동 모드를 토글
  void toggleImagePanMode() {
    _imagePanMode = !_imagePanMode;
    setState(() {});
  }

  /// 편집 모드 설정 (텍스트 레이어 전용)
  void setEditing(String? id) => _editingLayerId = id;

  /// 레이어의 기본 크기 설정 (초기화 시 호출)
  void setBaseSize(String id, Size baseSize) => _refBaseSize[id] = baseSize;

  // ==================== 유틸리티 메서드 ====================
  /// 주어진 글로벌 좌표가 커버 영역 안에 있는지 확인
  bool isInCover(Offset globalPosition) {
    final ctx = coverKey.currentContext;
    if (ctx == null) return false;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return false;
    final topLeft = box.localToGlobal(Offset.zero);
    final size = box.size;
    return Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      size.width,
      size.height,
    ).contains(globalPosition);
  }

  /// 레이어 위치를 커버 영역 내로 제한하지 않음 (자유 이동 가능)
  Offset _clampPosition(Offset pos, Size childSize, Size coverSize) {
    return pos;
  }

  /// 레이어 목록을 Z-index 순으로 정렬
  /// 템플릿에서 로드한 레이어는 LayerModel.zIndex를 사용하고,
  /// 에디터에서 순서를 바꾼 경우 _z 캐시를 사용한다.
  List<LayerModel> sortByZ(List<LayerModel> list) {
    final l = List<LayerModel>.from(list);
    for (final layer in l) {
      _z.putIfAbsent(layer.id, () => layer.zIndex);
    }

    final byZ = List<LayerModel>.from(l)
      ..sort((a, b) {
        final aBg = _isBackgroundLayer(a);
        final bBg = _isBackgroundLayer(b);
        if (aBg != bBg) return aBg ? -1 : 1;
        final za = _z[a.id] ?? a.zIndex;
        final zb = _z[b.id] ?? b.zIndex;
        if (za != zb) return za.compareTo(zb);
        return a.id.compareTo(b.id);
      });

    // 2) list 순서와 _z 순서가 다르면, 선택/드래그로 맨 앞 올린 직후 VM 반영이 한 프레임 늦을 수 있음.
    //    이때 _z를 list로 덮어쓰면 선택한 레이어가 잠깐 뒤로 그려지는 문제가 있으므로,
    //    먼저 byZ(_z 기준)로 그려서 맨 앞 유지. 다음 프레임에 VM이 반영되면 l과 byZ가 일치함.
    //    패널에서 드래그로 순서를 바꾼 경우는 syncZOrder()로 _z가 이미 list와 맞춰져 있음.
    if (!_sameOrderById(l, byZ)) {
      return byZ;
    }

    return byZ;
  }

  static bool _sameOrderById(List<LayerModel> a, List<LayerModel> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  /// 레이어 목록의 순서를 그대로 Z-index에 반영 (레이어 패널에서 드래그한 순서 동기화용)
  void syncZOrder(List<LayerModel> orderedLayers) {
    _z.clear();
    _zCounter = 0;
    final backgrounds = orderedLayers.where(_isBackgroundLayer);
    final nonBackgrounds = orderedLayers.where((l) => !_isBackgroundLayer(l));
    for (final layer in [...backgrounds, ...nonBackgrounds]) {
      _z[layer.id] = ++_zCounter;
    }
    setState(() {});
  }

  /// 레이어 선택
  void setSelectedLayer(String layerId) {
    setState(() {
      _selectedLayerId = layerId;
      // 새 레이어를 선택할 때는 항상 사진 위치 조정 모드를 초기화
      _imagePanMode = false;
    });
  }

  /// 선택 해제 및 가이드라인 숨김
  void clearSelection() {
    setState(() {
      _selectedLayerId = null;
      _editingLayerId = null;
      // 선택이 해제되면 사진 위치 조정 모드도 항상 OFF
      _imagePanMode = false;
      _showVerticalGuide = false;
      _showHorizontalGuide = false;
      _showDiagonalGuide = false;
    });
  }

  /// 선택된 레이어 삭제
  void deleteSelected() {
    final id = _selectedLayerId;
    if (id == null) return;

    // ViewModel에서 레이어 제거
    ref.read(albumEditorViewModelProvider.notifier).removeLayerById(id);

    // 로컬 상태 정리
    setState(() {
      _pos.remove(id);
      _scale.remove(id);
      _rot.remove(id);
      _refBaseSize.remove(id);
      _z.remove(id);
      _gestureStates.remove(id);
      _selectedLayerId = null;
      _imagePanMode = false;
    });
  }

  /// 활성 레이어 목록과 내부 상태 동기화 (삭제된 레이어 상태 정리)
  void syncLayers(List<LayerModel> activeLayers) {
    if (_pos.isEmpty) return;

    final activeIds = activeLayers.map((l) => l.id).toSet();
    final inactiveIds = _pos.keys
        .where((id) => !activeIds.contains(id))
        .toList();

    if (inactiveIds.isNotEmpty) {
      setState(() {
        for (final id in inactiveIds) {
          _pos.remove(id);
          _scale.remove(id);
          _rot.remove(id);
          _z.remove(id);
          _refBaseSize.remove(id);
          _gestureStates.remove(id);
          if (_selectedLayerId == id) _selectedLayerId = null;
          if (_editingLayerId == id) _editingLayerId = null;
        }
      });
    }
  }

  // ==================== 레이어 빌더 ====================

  /// 제스처를 처리할 수 있는 인터랙티브 레이어 위젯 생성
  Widget buildInteractiveLayer({
    required LayerModel layer,
    required double baseWidth,
    required double baseHeight,
    required Widget child,
    bool isCover = false,
  }) {
    // [Fix] putIfAbsent 대신 실시간 동기화.
    // 현재 제스처 중이 아니거나 프리뷰 모드라면 VM의 최신 상태(rescale 결과 등)를 강제 반영함.
    final bool isInteracting =
        _selectedLayerId == layer.id && _gestureStates.containsKey(layer.id);

    if (!isInteracting || _isPreviewMode) {
      _pos[layer.id] = layer.position;
      _scale[layer.id] = layer.scale;
      _rot[layer.id] = layer.rotation * math.pi / 180;
    }
    _z.putIfAbsent(layer.id, () => ++_zCounter);

    // 레이어 기준 크기 업데이트 (커버 리사이즈 등으로 변경될 수 있음)
    // 항상 최신 baseWidth/baseHeight로 동기화해야 제스처 시작 시 튀지 않음
    _refBaseSize[layer.id] = Size(baseWidth, baseHeight);

    final bool isNewLayer = !_pos.containsKey(
      layer.id,
    ); // _pos로 체크 (위쪽에서 putIfAbsent 했으므로 여기선 항상 존재하지만 논리적으로)

    // 디버깅: 레이어 초기화 로그
    if (isNewLayer) {
      final coverSize = getCoverSize();
      AppLogger.debug(
        '[LayerInteraction] Init layer ${layer.id.substring(0, 8)}: '
        'type=${layer.type.name}, '
        'pos=(${_pos[layer.id]!.dx.toStringAsFixed(1)}, ${_pos[layer.id]!.dy.toStringAsFixed(1)}), '
        'baseSize=(${baseWidth.toStringAsFixed(1)}x${baseHeight.toStringAsFixed(1)}), '
        'scale=${_scale[layer.id]!.toStringAsFixed(2)}, '
        'canvas=(${coverSize.width.toStringAsFixed(1)}x${coverSize.height.toStringAsFixed(1)})',
      );
    }

    if (_isPreviewMode) {
      return Positioned(
        left: layer.position.dx, // [Fix] 프리뷰 모드에선 내부 _pos 캐시 대신 원본 직접 사용
        top: layer.position.dy,
        child: Transform.rotate(
          angle: layer.rotation * math.pi / 180, // [Fix] _rot 대신 원본 직접 사용
          alignment: Alignment.center,
          child: Transform.scale(
            scale: layer.scale, // [Fix] _scale 대신 원본 직접 사용
            alignment: Alignment.center,
            child: SizedBox(
              width: baseWidth,
              height: layer.type == LayerType.text ? null : baseHeight,
              child: child,
            ),
          ),
        ),
      );
    }

    final coverSize = getCoverSize();
    final isSelected = _selectedLayerId == layer.id; // 선택 여부
    final isEditing = _editingLayerId == layer.id; // 편집 중 여부

    return Stack(
      clipBehavior: Clip.none, // 자식이 경계 밖으로 나갈 수 있음
      children: [
        // 레이어 본체
        Positioned(
          left: _pos[layer.id]!.dx,
          top: _pos[layer.id]!.dy,
          child: Transform.rotate(
            key: _getLayerKey(layer.id),
            angle: _rot[layer.id]!,
            alignment: Alignment.center, // 명시적 중심축 설정
            child: Transform.scale(
              scale: _scale[layer.id]!,
              alignment: Alignment.center, // 명시적 중심축 설정
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: baseWidth,
                    height: layer.type == LayerType.text ? null : baseHeight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        AppLogger.debug(
                          '[LayerInteraction] Tap on ${layer.id} (type=${layer.type.name})',
                        );
                        AppLogger.debug(
                          '[LayerInteraction] Layer Size: ${layer.width.toStringAsFixed(1)} x ${layer.height.toStringAsFixed(1)}',
                        );
                        AppLogger.debug(
                          '[LayerInteraction] RefBaseSize: ${_refBaseSize[layer.id]}',
                        );
                        AppLogger.debug(
                          '[LayerInteraction] Scale: ${_scale[layer.id]}',
                        );
                        _handleTap(layer);
                      },
                      onScaleStart: (d) => _handleScaleStart(layer, d),
                      onScaleUpdate: (d) => _handleScaleUpdate(
                        layer,
                        d,
                        baseWidth,
                        baseHeight,
                        isCover: isCover,
                      ),
                      onScaleEnd: (d) => _handleScaleEnd(layer, d),
                      child: SelectionFrame(
                        isSelected:
                            isSelected && !isEditing && showSelectionControls,
                        showHandles: showHandles,
                        onDelete: deleteSelected,
                        onResizeStart: (pos, d) =>
                            _handleResizeStart(layer, pos, d),
                        onResizeUpdate: (pos, d) => _handleResizeUpdate(
                          layer,
                          pos,
                          d,
                          baseWidth,
                          baseHeight,
                          isCover: isCover,
                        ),
                        onResizeEnd: (pos, d) =>
                            _handleResizeEnd(layer, pos, d),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          curve: Curves.easeOut,
                          width: baseWidth,
                          height: baseHeight,
                          child: layer.type == LayerType.text
                              ? child
                              : ClipRRect(child: child),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== 제스처 핸들러 ====================

  /// 탭 이벤트 처리
  void _handleTap(LayerModel layer) {
    // 이미지 플레이스홀더(사진 없음) 탭 시 바로 갤러리 진입 (페이지 편집용)
    final isImagePlaceholder =
        layer.type == LayerType.image &&
        layer.asset == null &&
        (layer.previewUrl ?? layer.imageUrl ?? layer.originalUrl) == null;
    if (isImagePlaceholder && onTapPlaceholder != null) {
      onTapPlaceholder!(layer);
      return;
    }

    if (_selectedLayerId != layer.id) {
      final isBackground = _isBackgroundLayer(layer);
      setState(() {
        _selectedLayerId = layer.id;
        _editingLayerId = null;
        if (!isBackground) {
          _z[layer.id] = ++_zCounter;
        }
      });
      if (!isBackground) _bringLayerToFrontInPage(layer.id);
      onLayerTap?.call(layer);
    } else {
      if (layer.type == LayerType.text) {
        setState(() => _editingLayerId = layer.id);
        onEditText(layer);
      } else {
        clearSelection();
      }
    }
  }

  /// 제스처 시작 이벤트 처리 (손가락을 댄 순간)
  void _handleScaleStart(LayerModel layer, ScaleStartDetails details) {
    _stopAnimation(); // 진행 중인 애니메이션 중지

    // 제스처 시작 시점의 상태 저장 (상대적 변화 계산에 사용)
    _gestureStates[layer.id] = _GestureState(
      initialScale: _scale[layer.id]!,
      initialRotation: _rot[layer.id]!,
      initialPosition: _pos[layer.id]!,
      baseSize: _refBaseSize[layer.id]!,
      hasSnapped: false, // 스냅 햅틱 피드백 플래그 초기화
    );

    final isBackground = _isBackgroundLayer(layer);
    setState(() {
      _selectedLayerId = layer.id;
      _editingLayerId = null;
      if (!isBackground) {
        _z[layer.id] = ++_zCounter; // 맨 앞으로 가져오기
      }
    });
    if (!isBackground) _bringLayerToFrontInPage(layer.id);
  }

  /// 선택된 레이어를 페이지 레이어 리스트에서 맨 위(맨 앞)로 올림 — 레이어 바텀시트 순서와 동기화
  void _bringLayerToFrontInPage(String layerId) {
    final state = ref.read(albumEditorViewModelProvider).value;
    if (state == null) return;
    final layers = state.layers;
    if (layers.isEmpty) return;
    final idx = layers.indexWhere((l) => l.id == layerId);
    if (idx < 0 || idx >= layers.length - 1) return;
    if (_isBackgroundLayer(layers[idx])) return;
    ref
        .read(albumEditorViewModelProvider.notifier)
        .reorderLayer(idx, layers.length - 1);
  }

  bool _isBackgroundLayer(LayerModel layer) {
    if (layer.type != LayerType.decoration) return false;
    final cover = getCoverSize();
    final fillsCanvas =
        layer.position.dx.abs() <= 0.1 &&
        layer.position.dy.abs() <= 0.1 &&
        (layer.width - cover.width).abs() <= 1.0 &&
        (layer.height - cover.height).abs() <= 1.0;
    if (fillsCanvas) return true;
    final key = layer.imageBackground ?? '';
    return key.startsWith('paper') ||
        key == 'darkVignette' ||
        key == 'notebookPunchPage';
  }

  /// 제스처 업데이트 이벤트 처리 (손가락을 움직이는 동안)
  void _handleScaleUpdate(
    LayerModel layer,
    ScaleUpdateDetails details,
    double baseWidth,
    double baseHeight, {
    bool isCover = false,
  }) {
    if (_editingLayerId == layer.id) return; // 편집 중이면 제스처 무시

    // 사진 위치 조정 모드: 프레임은 고정, 안의 이미지(offset)만 이동
    if (_imagePanMode && layer.type == LayerType.image) {
      _handleImagePanUpdate(layer, details, baseWidth, baseHeight);
      return;
    }

    final gestureState = _gestureStates[layer.id];
    if (gestureState == null) return; // 상태가 없으면 무시

    final coverSize = getCoverSize();
    final baseSize = Size(baseWidth, baseHeight);

    // ==================== 스케일 처리 ====================
    final rawScale = details.scale;
    final slowedScaleDelta = (rawScale - 1.0) * 0.85 + 1.0;
    double targetScale = gestureState.initialScale * slowedScaleDelta;

    if (targetScale < _minScale) {
      targetScale = _minScale - (_minScale - targetScale) * _scaleOvershoot;
    } else if (targetScale > _maxScale) {
      targetScale = _maxScale + (targetScale - _maxScale) * _scaleOvershoot;
    }

    // ==================== 회전 처리 ====================
    double rotationDelta = details.rotation * _rotationResponsiveness;
    if (rotationDelta.abs() < _rotationDeadzone) rotationDelta = 0.0;
    double targetRotation = gestureState.initialRotation + rotationDelta;

    bool angleSnapped = false;
    for (final angle in _snapAngles) {
      final diff = _angleDifference(targetRotation, angle);
      if (diff.abs() < _angleSnapThreshold) {
        targetRotation = _lerpAngle(targetRotation, angle, _angleSnapStrength);
        angleSnapped = true;
        break;
      }
    }

    // ==================== 드래그 처리 ====================
    // focalPointDelta: 이전 프레임부터의 손가락 이동 거리 (Global/Screen logical pixels)
    Offset rawDelta = details.focalPointDelta;

    // [Inner Page Fix] 부모 위젯(Canvas)이 Transform.scale 등으로 변형된 경우,
    // 이동 거리(Delta)를 해당 스케일로 나누어 로지컬 공간(300x400)에 맞게 정규화함.
    final parentScale = _getParentScale();
    if (parentScale > 0) {
      rawDelta = rawDelta / parentScale;
    }

    // 개선된 드래그 감도 보정
    final currentScale = gestureState.initialScale * details.scale;
    if (currentScale > 0) {
      // 축소 시 더 둔감하게, 확대 시 적당히 민감하게 — 반비례가 아니라 정비례로 변경
      // 스케일이 작아질수록 이동량을 줄여야 자연스러움 → rawDelta * scale
      final normalized = math.pow(currentScale, 0.55);
      rawDelta = rawDelta * normalized.toDouble();
    }

    // 속도 제한: 프레임당 이동 거리가 너무 크면 제한₩₩
    // (빠르게 드래그해도 레이어가 날아가지 않도록)
    final deltaDistance = rawDelta.distance;
    if (deltaDistance > _dragMaxSpeed) {
      // 방향은 유지하고 크기만 제한
      rawDelta = rawDelta * (_dragMaxSpeed / deltaDistance);
    }

    // 텍스트 레이어 드래그 감도 조정 및 실제 크기 보정
    // (baseSize 재계산 코드 삭제됨)

    // 회전된 레이어의 로컬 좌표계로 변환
    // (레이어가 회전되어 있어도 드래그 방향이 자연스럽게 느껴지도록)
    final cos = math.cos(targetRotation);
    final sin = math.sin(targetRotation);
    final localDelta = Offset(
      rawDelta.dx * cos - rawDelta.dy * sin,
      rawDelta.dx * sin + rawDelta.dy * cos,
    );

    // 현재 레이어 중심점 계산
    Offset center = Offset(
      _pos[layer.id]!.dx + (baseSize.width * _scale[layer.id]!) / 2,
      _pos[layer.id]!.dy + (baseSize.height * _scale[layer.id]!) / 2,
    );

    // 새로운 중심점 = 현재 중심점 + 이동 변화량
    Offset newCenter = center + localDelta;

    // 스케일 기반 동적 스냅 강도 (축소 시 스냅 약해짐)
    final dynamicScale = (gestureState.initialScale * details.scale).clamp(
      0.3,
      3.0,
    );
    // 가로/세로 스냅 강도 대폭 약화 (대각선과 동일한 강도 유지 가능)
    final baseSnap = _snapStrength * math.pow(dynamicScale, 0.20);

    // 가로/세로는 과도하게 빨려들지 않도록 더 약하게 (원하는 위치 맞추기 쉽게)
    final dynamicSnapStrength = baseSnap * 0.28;

    // ==================== 위치 스냅 처리 ====================
    // [Spine fix] 스냅 기준점: 커버인 경우 Spine 제외 중앙
    final centerX = isCover
        ? kCoverSpineWidth + (coverSize.width - kCoverSpineWidth) / 2
        : coverSize.width / 2;

    final coverCenter = Offset(centerX, coverSize.height / 2);

    bool verticalSnap = false; // 세로 중앙선 스냅 여부
    bool horizontalSnap = false; // 가로 중앙선 스냅 여부
    bool diagonalSnap = false; // 대각선 스냅 여부

    // 세로 중앙선 스냅 (X축)
    final xDist = (newCenter.dx - coverCenter.dx).abs();
    if (xDist < _snapThreshold) {
      // 거리에 따라 스냅 강도 조절 (가까울수록 강하게)
      final proximity = 1.0 - (xDist / _snapThreshold);
      final strength =
          dynamicSnapStrength * proximity * proximity; // 2차 함수로 부드럽게
      newCenter = Offset(
        newCenter.dx + (coverCenter.dx - newCenter.dx) * strength,
        newCenter.dy,
      );
      verticalSnap = true;
    }

    // 가로 중앙선 스냅 (Y축)
    final yDist = (newCenter.dy - coverCenter.dy).abs();
    if (yDist < _snapThreshold) {
      final proximity = 1.0 - (yDist / _snapThreshold);
      final strength = dynamicSnapStrength * proximity * proximity;
      newCenter = Offset(
        newCenter.dx,
        newCenter.dy + (coverCenter.dy - newCenter.dy) * strength,
      );
      horizontalSnap = true;
    }

    // 가로·세로 모두 스냅 중이고 중앙에 매우 가까우면 정확히 중앙으로 고정 (가이드라인과 일치)
    if (verticalSnap && horizontalSnap) {
      final distToCenter = (newCenter - coverCenter).distance;
      if (distToCenter < _snapCenterExactThreshold) {
        newCenter = coverCenter;
      }
    }

    // 대각선 스냅 1: 좌상단 → 우하단 (dx = dy)
    final diagDist1 = (newCenter.dx - newCenter.dy).abs();
    if (diagDist1 < _snapThreshold) {
      final proximity = 1.0 - (diagDist1 / _snapThreshold);
      final strength = dynamicSnapStrength * proximity * proximity;
      final target = (newCenter.dx + newCenter.dy) / 2;
      newCenter = Offset(
        newCenter.dx + (target - newCenter.dx) * strength,
        newCenter.dy + (target - newCenter.dy) * strength,
      );
      diagonalSnap = true;
    }

    // 대각선 스냅 2: 우상단 → 좌하단 (dx + dy = width)
    final diagDist2 = (newCenter.dx + newCenter.dy - coverSize.width).abs();
    if (diagDist2 < _snapThreshold) {
      final proximity = 1.0 - (diagDist2 / _snapThreshold);
      final strength = dynamicSnapStrength * proximity * proximity;
      final target = (coverSize.width - newCenter.dx + newCenter.dy) / 2;
      newCenter = Offset(
        newCenter.dx + (coverSize.width - target - newCenter.dx) * strength,
        newCenter.dy + (target - newCenter.dy) * strength,
      );
      diagonalSnap = true;
    }

    // 각도 스냅 시 모든 가이드라인 표시
    if (angleSnapped) {
      verticalSnap = horizontalSnap = diagonalSnap = true;
    }

    // === 중앙 스냅 가이드 표시 ===
    final showVertical = verticalSnap;
    final showHorizontal = horizontalSnap;
    final showDiagonal = diagonalSnap;

    // final isSnapped = showVertical || showHorizontal;
    final isSnapped = showVertical || showHorizontal || showDiagonal;
    final wasSnapped = gestureState.hasSnapped;

    if (isSnapped && !wasSnapped) {
      gestureState.hasSnapped = true;
    }

    if (!isSnapped) {
      gestureState.hasSnapped = false;
    }

    // 가이드 표시 규칙
    setState(() {
      _showVerticalGuide = showVertical;
      _showHorizontalGuide = showHorizontal;
      _showDiagonalGuide = false;
    });

    // 중심점을 좌상단 좌표로 변환
    final childSize = Size(
      baseSize.width * targetScale,
      baseSize.height * targetScale,
    );
    Offset newPos = Offset(
      newCenter.dx - childSize.width / 2,
      newCenter.dy - childSize.height / 2,
    );

    // 경계 내로 제한
    newPos = _clampPosition(newPos, childSize, coverSize);

    // 상태 업데이트 (화면 갱신)
    setState(() {
      _scale[layer.id] = targetScale;
      _rot[layer.id] = targetRotation;
      _pos[layer.id] = newPos;
    });
  }

  /// 이미지 슬롯 안에서 사진 자체를 드래그로 이동시킬 때 호출
  void _handleImagePanUpdate(
    LayerModel layer,
    ScaleUpdateDetails details,
    double baseWidth,
    double baseHeight,
  ) {
    // 부모 Transform.scale 보정
    Offset delta = details.focalPointDelta;
    final parentScale = _getParentScale();
    if (parentScale > 0) {
      delta = delta / parentScale;
    }

    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final current = vm.findLayerById(layer.id) ?? layer;
    final prevOffset = current.imageOffset ?? Offset.zero;
    var nextOffset = prevOffset + delta;

    // alignment(-1~1)로 매핑할 때 적당한 범위를 주기 위해,
    // 레이어 박스 크기의 절반을 기준으로 클램프
    final maxDx = baseWidth * 0.5;
    final maxDy = baseHeight * 0.5;
    nextOffset = Offset(
      nextOffset.dx.clamp(-maxDx, maxDx),
      nextOffset.dy.clamp(-maxDy, maxDy),
    );

    vm.updateLayer(current.copyWith(imageOffset: nextOffset));
  }

  /// 제스처 종료 이벤트 처리 (손가락을 뗀 순간)
  // lib/features/album/presentation/controllers/layer_interaction_manager.dart

  /// 제스처 종료 이벤트 처리
  void _handleScaleEnd(LayerModel layer, ScaleEndDetails details) {
    final scale = _scale[layer.id]!;
    final rotation = _rot[layer.id]!;

    // 1. 회전 및 스케일 스냅 처리 (기존 로직 유지)
    double? targetRot;
    double minDiff = double.infinity;
    for (final angle in _snapAngles) {
      final diff = _angleDifference(rotation, angle).abs();
      if (diff < minDiff) {
        minDiff = diff;
        targetRot = angle;
      }
    }
    if (minDiff < _angleSnapThreshold * 0.5) {
      _animateRotation(layer.id, targetRot!);
    }
    if (scale < _minScale || scale > _maxScale) {
      _animateScale(layer.id, scale.clamp(_minScale, _maxScale));
    }

    // 변경된 로컬 상태를 ViewModel의 전역 상태로 업데이트 (rotation은 도로 저장)
    final updatedLayer = layer.copyWith(
      position: _pos[layer.id],
      scale: _scale[layer.id],
      rotation: _rot[layer.id]! * 180 / math.pi,
    );
    ref.read(albumEditorViewModelProvider.notifier).updateLayer(updatedLayer);

    // 가이드라인 숨김 및 제스처 상태 해제
    setState(() {
      _showVerticalGuide = false;
      _showHorizontalGuide = false;
      _showDiagonalGuide = false;
      _gestureStates.remove(layer.id);
    });
  }

  // ==================== 리사이즈 핸들러 ====================

  void _handleResizeStart(
    LayerModel layer,
    ResizeHandlePosition handle,
    DragStartDetails details,
  ) {
    // 현재 스케일/위치 기준으로 리사이즈 시작 상태 저장
    final baseSize = _refBaseSize[layer.id] ?? Size(layer.width, layer.height);
    _resizeState = _ResizeState(
      layerId: layer.id,
      handle: handle,
      initialScale: _scale[layer.id] ?? layer.scale,
      baseSize: baseSize,
    );
    setState(() {
      _selectedLayerId = layer.id;
      _editingLayerId = null;
    });
  }

  void _handleResizeUpdate(
    LayerModel layer,
    ResizeHandlePosition handle,
    DragUpdateDetails details,
    double baseWidth,
    double baseHeight, {
    bool isCover = false,
  }) {
    final state = _resizeState;
    if (state == null || state.layerId != layer.id) return;

    // 드래그 거리의 크기에 비례해서 스케일을 변경 (단일 축이 아닌 균일 스케일)
    // corner 방향 드래그 기준: x, y 이동을 모두 반영하되 과도한 변화는 클램프
    Offset delta = details.delta;
    // 부모 Transform.scale 보정
    final parentScale = _getParentScale();
    if (parentScale > 0) {
      delta = delta / parentScale;
    }

    // 핸들 방향에 따라 부호를 일관되게 맞추기 위해, 각 코너별로 기준 부호를 준다.
    double direction = 1.0;
    switch (handle) {
      case ResizeHandlePosition.topLeft:
        direction = -1.0;
        break;
      case ResizeHandlePosition.topRight:
        direction = (-delta.dx + delta.dy) >= 0 ? 1.0 : -1.0;
        break;
      case ResizeHandlePosition.bottomLeft:
        direction = (delta.dx - delta.dy) >= 0 ? 1.0 : -1.0;
        break;
      case ResizeHandlePosition.bottomRight:
        direction = 1.0;
        break;
    }

    final magnitude = (delta.dx.abs() + delta.dy.abs()) * 0.5 * direction;
    double scaleDelta = magnitude / 120.0;
    scaleDelta = scaleDelta.clamp(-0.4, 0.4); // 한 프레임당 변화량 제한

    double targetScale = (state.initialScale + scaleDelta).clamp(
      _minScale,
      _maxScale,
    );

    setState(() {
      _scale[layer.id] = targetScale;
    });
  }

  void _handleResizeEnd(
    LayerModel layer,
    ResizeHandlePosition handle,
    DragEndDetails details,
  ) {
    final state = _resizeState;
    _resizeState = null;
    if (state == null || state.layerId != layer.id) return;

    final scale = _scale[layer.id] ?? layer.scale;
    final rotation = _rot[layer.id] ?? (layer.rotation * math.pi / 180);

    // 제스처 종료와 동일하게 ViewModel에 최종 스케일/회전 적용
    final updatedLayer = layer.copyWith(
      position: _pos[layer.id],
      scale: scale,
      rotation: rotation * 180 / math.pi,
    );
    ref.read(albumEditorViewModelProvider.notifier).updateLayer(updatedLayer);
  }

  // ==================== 애니메이션 메서드 ====================

  /// 회전 애니메이션 (180ms)
  void _animateRotation(String layerId, double target) {
    const duration = Duration(milliseconds: 180);
    final start = _rot[layerId]!;
    int elapsed = 0;

    _startAnimation((dt) {
      elapsed += (dt * 1000).toInt();
      final t = (elapsed / duration.inMilliseconds).clamp(0.0, 1.0);
      setState(() {
        // easeOutCubic 커브로 부드러운 감속
        _rot[layerId] = _lerpAngle(
          start,
          target,
          Curves.easeOutCubic.transform(t),
        );
      });
      return t >= 1.0; // 완료 여부
    });
  }

  /// 스케일 애니메이션 (180ms)
  void _animateScale(String layerId, double target) {
    const duration = Duration(milliseconds: 180);
    final start = _scale[layerId]!;
    int elapsed = 0;

    _startAnimation((dt) {
      elapsed += (dt * 1000).toInt();
      final t = (elapsed / duration.inMilliseconds).clamp(0.0, 1.0);
      setState(() {
        // easeOutExpo 커브로 더 빠른 감속
        _scale[layerId] =
            start + (target - start) * Curves.easeOutExpo.transform(t);
      });
      return t >= 1.0; // 완료 여부
    });
  }

  /// 애니메이션 시작 (Ticker 기반)
  /// onTick: 각 프레임마다 호출되는 콜백, true 반환 시 애니메이션 종료
  void _startAnimation(bool Function(double dtSeconds) onTick) {
    _stopAnimation(); // 기존 애니메이션 중지

    Duration? lastTime;
    _activeTicker = Ticker((Duration elapsed) {
      // 델타 타임 계산 (이전 프레임부터 경과한 시간)
      final dt = lastTime == null
          ? 1 / 60
          : (elapsed - lastTime!).inMicroseconds / 1e6;
      lastTime = elapsed;

      // 프레임 드롭 방지: 델타 타임을 30fps 이하로 제한
      if (onTick(dt.clamp(0.0, 1 / 30))) _stopAnimation();
    });
    _activeTicker!.start();
  }

  /// 현재 실행 중인 애니메이션 중지
  void _stopAnimation() {
    _activeTicker?.stop();
    _activeTicker?.dispose();
    _activeTicker = null;
  }

  // ==================== 수학 유틸리티 ====================

  /// 두 각도의 최단 차이 계산 (-π ~ π 범위)
  /// 예: 350° 와 10° 의 차이는 20° (340°가 아님)
  double _angleDifference(double a, double b) {
    double diff = (a - b) % (2 * math.pi);
    if (diff > math.pi) diff -= 2 * math.pi;
    if (diff < -math.pi) diff += 2 * math.pi;
    return diff;
  }

  /// 각도 선형 보간 (최단 경로로)
  /// a: 시작 각도, b: 목표 각도, t: 보간 비율 (0~1)
  double _lerpAngle(double a, double b, double t) {
    return a + _angleDifference(b, a) * t;
  }

  /// [Inner Page Fix] 부모 위젯(Canvas)이 화면상에 실측 렌더링된 물리적 스케일을 계산함.
  /// (예: 300x400 캔버스가 340x453으로 렌더링된 경우 약 1.13배)
  double _getParentScale() {
    final ctx = coverKey.currentContext;
    if (ctx == null) return 1.0;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return 1.0;

    // (1,0) 로컬 오프셋이 글로벌 화면상에서 얼마나 떨어져 있는지 확인하여 스케일 산출
    try {
      final p0 = box.localToGlobal(Offset.zero);
      final p1 = box.localToGlobal(const Offset(1, 0));
      return (p1 - p0).distance;
    } catch (_) {
      return 1.0;
    }
  }
}

/// Provider 전달용 파라미터 객체
class LayerInteractionManagerArgs {
  final GlobalKey coverKey;
  final void Function(void Function()) setState;
  final Size Function() getCoverSize;
  final void Function(LayerModel layer) onEditText;

  LayerInteractionManagerArgs({
    required this.coverKey,
    required this.setState,
    required this.getCoverSize,
    required this.onEditText,
  });
}

// ==================== 내부 클래스 ====================

/// 제스처 시작 시점의 상태를 저장하는 클래스
/// (상대적인 변화를 계산하기 위해 필요)
class _GestureState {
  final double initialScale; // 제스처 시작 시점의 스케일
  final double initialRotation; // 제스처 시작 시점의 회전각
  final Offset initialPosition; // 제스처 시작 시점의 위치
  final Size baseSize; // 레이어 원본 크기
  bool hasSnapped;

  _GestureState({
    required this.initialScale,
    required this.initialRotation,
    required this.initialPosition,
    required this.baseSize,
    required this.hasSnapped,
  });
}

class _ResizeState {
  final String layerId;
  final ResizeHandlePosition handle;
  final double initialScale;
  final Size baseSize;

  _ResizeState({
    required this.layerId,
    required this.handle,
    required this.initialScale,
    required this.baseSize,
  });
}

/// 대각선 가이드라인을 그리는 CustomPainter
class _DiagonalGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // 좌상단 → 우하단 대각선
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);

    // 우상단 → 좌하단 대각선
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false; // 항상 동일한 모양
}
