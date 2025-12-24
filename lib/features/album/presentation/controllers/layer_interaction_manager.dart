import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import '../../data/models/layer.dart';
import '../viewmodels/album_view_model.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

/// 스타일 레이어 인터랙션 관리자
/// 이미지/텍스트 레이어의 드래그, 회전, 확대/축소를 처리.
class LayerInteractionManager {
  final WidgetRef ref;
  final GlobalKey coverKey; // 커버 영역의 위치/크기를 얻기 위한 키
  final void Function(void Function()) setState; // UI 업데이트 함수
  final Size Function() getCoverSize; // 커버 크기 getter
  final void Function(LayerModel layer) onEditText; // 텍스트 편집 콜백

  // ==================== 레이어 상태 저장소 ====================
  final Map<String, Offset> _pos = {}; // 레이어 위치 (좌상단 기준)
  final Map<String, double> _scale = {}; // 레이어 배율 (1.0 = 원본 크기)
  final Map<String, double> _rot = {}; // 레이어 회전 (라디안)
  final Map<String, Size> _refBaseSize = {}; // 레이어 원본 크기
  final Map<String, int> _z = {}; // Z-index (레이어 쌓임 순서)
  int _zCounter = 0; // Z-index 카운터

  // ==================== 인터랙션 상태 ====================
  String? _selectedLayerId; // 현재 선택된 레이어 ID
  String? _editingLayerId; // 현재 편집 중인 레이어 ID (텍스트만)

  // ==================== 제스처 추적 ====================
  final Map<String, _GestureState> _gestureStates = {}; // 제스처 시작 시점의 상태 저장

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
  static const double _snapThreshold = 18.0; // 스냅 활성화 거리 (픽셀)
  static const double _snapStrength = 0.5; // 스냅 당김 강도 (0~1)
  // static const double _angleSnapThreshold = 0.087; // 각도 스냅 임계값 (~5도)
  static const double _angleSnapThreshold = 0.2; // 각도 스냅 임계값 (~5도)
  // static const double _angleSnapStrength = 0.35; // 각도 스냅 강도 (0~1)
  static const double _angleSnapStrength = 0.05; // 각도 스냅 강도 약하게 조정


  // 스냅 각도 목록 (0°, 45°, 90°, 135°, 180°, -45°, -90°, -135°)
  static const List<double> _snapAngles = [
    0.0, math.pi/4, math.pi/2, 3*math.pi/4,
    math.pi, -math.pi/4, -math.pi/2, -3*math.pi/4
  ];

  LayerInteractionManager({
    required this.ref,
    required this.coverKey,
    required this.setState,
    required this.getCoverSize,
    required this.onEditText,
  });

  // ==================== Getters / Setters ====================

  /// 외부(export용) zIndex 조회
  int getZIndex(String layerId) {
    return _z[layerId] ?? 0;
  }

  String? get selectedLayerId => _selectedLayerId;

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
    return Rect.fromLTWH(topLeft.dx, topLeft.dy, size.width, size.height)
        .contains(globalPosition);
  }

  /// 레이어 위치를 커버 영역 내로 제한하지 않음 (자유 이동 가능)
  Offset _clampPosition(Offset pos, Size childSize, Size coverSize) {
    return pos;
  }

  /// 레이어 목록을 Z-index 순으로 정렬
  List<LayerModel> sortByZ(List<LayerModel> list) {
    final l = List<LayerModel>.from(list);
    l.sort((a, b) => (_z[a.id] ?? 0).compareTo(_z[b.id] ?? 0));
    return l;
  }

  /// 선택 해제 및 가이드라인 숨김
  void clearSelection() {
    setState(() {
      _selectedLayerId = null;
      _editingLayerId = null;
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
    });
  }

  // ==================== 레이어 빌더 ====================

  /// 제스처를 처리할 수 있는 인터랙티브 레이어 위젯 생성
  Widget buildInteractiveLayer({
    required LayerModel layer,
    required double baseWidth,
    required double baseHeight,
    required Widget child,
  }) {
    _pos.putIfAbsent(layer.id, () => layer.position);
    _scale.putIfAbsent(layer.id, () => layer.scale);
    _rot.putIfAbsent(layer.id, () => layer.rotation);
    _z.putIfAbsent(layer.id, () => ++_zCounter);
    _refBaseSize.putIfAbsent(layer.id, () => Size(baseWidth, baseHeight));

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
            angle: _rot[layer.id]!, // 회전 적용
            child: Transform.scale(
              scale: _scale[layer.id]!, // 스케일 적용
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: baseWidth,
                    height: layer.type == LayerType.text ? null : baseHeight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent, // 빈 공간도 터치 감지
                      onTap: () {
                        _handleTap(layer);
                      },
                      onScaleStart: (d) => _handleScaleStart(layer, d),
                      onScaleUpdate: (d) => _handleScaleUpdate(layer, d, baseWidth, baseHeight),
                      onScaleEnd: (d) => _handleScaleEnd(layer, d),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        curve: Curves.easeOut,
                        // BoxDecoration의 border는 내부 영역을 잠식하여 콘텐츠가 잘릴 수 있으므로
                        // foregroundDecoration을 사용해 테두리를 레이아웃 외곽에 그리도록 처리
                        foregroundDecoration: isSelected && !isEditing
                            ? BoxDecoration(
                                border: Border.all(color: Colors.white, width: 1),
                              )
                            : null,
                        child: layer.type == LayerType.text
                            ? child
                            : ClipRRect(child: child),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 스냅 가이드라인 (조건부 렌더링)
        if (_showVerticalGuide) _buildGuide(coverSize, isVertical: true),
        if (_showHorizontalGuide) _buildGuide(coverSize, isVertical: false),
        if (_showDiagonalGuide) _buildDiagonalGuide(coverSize),
      ],
    );
  }

  /// 세로/가로 스냅 가이드라인 생성 (통합 메서드)
  Widget _buildGuide(Size coverSize, {required bool isVertical}) {
    return Positioned(
      left: isVertical ? coverSize.width / 2 - 1.5 : 0,
      top: isVertical ? 0 : coverSize.height / 2 - 1.5,
      width: isVertical ? 1 : coverSize.width,
      height: isVertical ? coverSize.height : 1,
      child: AnimatedOpacity(
        opacity: 1,
        duration: const Duration(milliseconds: 500),
        child: Container(
          decoration: BoxDecoration(
            // 중앙이 밝고 양쪽이 투명한 그라데이션
            gradient: LinearGradient(
              begin: isVertical ? Alignment.topCenter : Alignment.centerLeft,
              end: isVertical ? Alignment.bottomCenter : Alignment.centerRight,
              colors: [
                Colors.black.withOpacity(0.1),
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 대각선 스냅 가이드라인 생성
  Widget _buildDiagonalGuide(Size coverSize) {
    return Positioned(
      left: 0,
      top: 0,
      width: coverSize.width,
      height: coverSize.height,
      child: IgnorePointer( // 터치 이벤트 무시
        child: AnimatedOpacity(
          opacity: 0.7,
          duration: const Duration(milliseconds: 200), // 100
          child: CustomPaint(painter: _DiagonalGuidePainter()),
        ),
      ),
    );
  }

  // ==================== 제스처 핸들러 ====================

  /// 탭 이벤트 처리
  void _handleTap(LayerModel layer) {
    if (_selectedLayerId != layer.id) {
      setState(() {
        _selectedLayerId = layer.id;
        _editingLayerId = null;
        _z[layer.id] = ++_zCounter;
      });
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

    setState(() {
      _selectedLayerId = layer.id;
      _editingLayerId = null;
      _z[layer.id] = ++_zCounter; // 맨 앞으로 가져오기
    });
  }

  /// 제스처 업데이트 이벤트 처리 (손가락을 움직이는 동안)
  void _handleScaleUpdate(
      LayerModel layer,
      ScaleUpdateDetails details,
      double baseWidth,
      double baseHeight,
      ) {
    if (_editingLayerId == layer.id) return; // 편집 중이면 제스처 무시

    final gestureState = _gestureStates[layer.id];
    if (gestureState == null) return; // 상태가 없으면 무시

    final coverSize = getCoverSize();
    final baseSize = Size(baseWidth, baseHeight);

    // ==================== 스케일 처리 ====================
    // ✅ 텍스트 스케일 반응 상향 (더 빠르게 커지고 작아짐)
    final rawScale = details.scale;
    // 기존 0.50 → 0.85로 상향 (체감 크기 변화 증가)
    final slowedScaleDelta = (rawScale - 1.0) * 0.85 + 1.0;
    double targetScale = gestureState.initialScale * slowedScaleDelta;

    // 범위 초과 시 저항 적용 (고무줄 효과)
    if (targetScale < _minScale) {
      targetScale = _minScale - (_minScale - targetScale) * _scaleOvershoot;
    } else if (targetScale > _maxScale) {
      targetScale = _maxScale + (targetScale - _maxScale) * _scaleOvershoot;
    }

    // ==================== 회전 처리 ====================
    // 제스처 회전량에 감도 적용
    double rotationDelta = details.rotation * _rotationResponsiveness;

    // 데드존: 미세한 회전은 무시 (의도하지 않은 회전 방지)
    if (rotationDelta.abs() < _rotationDeadzone) rotationDelta = 0.0;

    // 목표 회전각 = 초기 회전각 + 회전 변화량
    double targetRotation = gestureState.initialRotation + rotationDelta;

    // 각도 스냅: 특정 각도에 가까우면 자석처럼 달라붙음
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
    // focalPointDelta: 이전 프레임부터의 손가락 이동 거리
    Offset rawDelta = details.focalPointDelta;

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
    final dynamicScale = (gestureState.initialScale * details.scale).clamp(0.3, 3.0);
    // 가로/세로 스냅 강도 대폭 약화 (대각선과 동일한 강도 유지 가능)
    final baseSnap = _snapStrength * math.pow(dynamicScale, 0.20);

    // 가로/세로는 과도하게 빨려들지 않도록 더 약하게 0.5배 감소
    final dynamicSnapStrength = baseSnap * 0.5;

    // ==================== 위치 스냅 처리 ====================
    final coverCenter = Offset(coverSize.width / 2, coverSize.height / 2);
    bool verticalSnap = false; // 세로 중앙선 스냅 여부
    bool horizontalSnap = false; // 가로 중앙선 스냅 여부
    bool diagonalSnap = false; // 대각선 스냅 여부

    // 세로 중앙선 스냅 (X축)
    final xDist = (newCenter.dx - coverCenter.dx).abs();
    if (xDist < _snapThreshold) {
      // 거리에 따라 스냅 강도 조절 (가까울수록 강하게)
      final proximity = 1.0 - (xDist / _snapThreshold);
      final strength = dynamicSnapStrength * proximity * proximity; // 2차 함수로 부드럽게
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
    final childSize = Size(baseSize.width * targetScale, baseSize.height * targetScale);
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

  /// 제스처 종료 이벤트 처리 (손가락을 뗀 순간)
  void _handleScaleEnd(LayerModel layer, ScaleEndDetails details) {
    final scale = _scale[layer.id]!;
    final rotation = _rot[layer.id]!;

    // 회전 스냅: 가장 가까운 각도로 부드럽게 회전
    double? targetRot;
    double minDiff = double.infinity;
    for (final angle in _snapAngles) {
      final diff = _angleDifference(rotation, angle).abs();
      if (diff < minDiff) {
        minDiff = diff;
        targetRot = angle;
      }
    }
    // 충분히 가까우면 애니메이션으로 스냅
    if (minDiff < _angleSnapThreshold * 0.5) {
      _animateRotation(layer.id, targetRot!);
    }

    // 스케일 스냅: 범위를 벗어난 경우 범위 내로 복귀
    if (scale < _minScale || scale > _maxScale) {
      _animateScale(layer.id, scale.clamp(_minScale, _maxScale));
    }
    // 가이드라인 숨김
    setState(() {
      _showVerticalGuide = false;
      _showHorizontalGuide = false;
      _showDiagonalGuide = false;
    });

    // 제스처 상태 정리
    _gestureStates.remove(layer.id);
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
        _rot[layerId] = _lerpAngle(start, target, Curves.easeOutCubic.transform(t));
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
        _scale[layerId] = start + (target - start) * Curves.easeOutExpo.transform(t);
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
      final dt = lastTime == null ? 1/60 : (elapsed - lastTime!).inMicroseconds / 1e6;
      lastTime = elapsed;

      // 프레임 드롭 방지: 델타 타임을 30fps 이하로 제한
      if (onTick(dt.clamp(0.0, 1/30))) _stopAnimation();
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