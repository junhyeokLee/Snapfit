import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../../core/constants/cover_theme.dart';
import '../../../domain/entities/album.dart';
import '../../../domain/entities/layer.dart';
import '../../../domain/entities/layer_export_mapper.dart';
import '../../../../../shared/snapfit_image.dart';
import '../../../../../core/cache/snapfit_cache_manager.dart';

/// 날짜 포맷 (yyyy.MM.dd)
String formatAlbumDate(String raw) {
  if (raw.isEmpty) return '----.--.--';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final mm = parsed.month.toString().padLeft(2, '0');
  final dd = parsed.day.toString().padLeft(2, '0');
  return '${parsed.year}.$mm.$dd';
}

/// 커버 비율 파싱
double parseCoverRatio(String raw) {
  if (raw.isEmpty) return 6 / 8;
  final parts = raw.split(':');
  if (parts.length == 2) {
    final w = double.tryParse(parts[0]);
    final h = double.tryParse(parts[1]);
    if (w != null && h != null && h != 0) return w / h;
  }
  final value = double.tryParse(raw);
  if (value != null && value > 0) return value;
  return 6 / 8;
}

/// 커버 테마 해석
CoverTheme resolveCoverTheme(String? label) {
  if (label == null || label.isEmpty) return CoverTheme.classic;
  final normalized = label.trim().toLowerCase();
  for (final theme in CoverTheme.values) {
    if (theme.label.toLowerCase() == normalized) {
      return theme;
    }
  }
  return CoverTheme.classic;
}

/// 커버 레이어 파싱
List<LayerModel>? parseCoverLayers(
  String raw, {
  required Size canvasSize,
}) {
  if (raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final pages = decoded['pages'] as List<dynamic>?;
    final List<dynamic> layerList = (pages != null && pages.isNotEmpty)
        ? ((pages[0] as Map<String, dynamic>)['layers'] as List?) ?? []
        : (decoded['layers'] as List?) ?? [];
    if (layerList.isEmpty) return null;
    return layerList
        .map(
          (l) => LayerExportMapper.fromJson(
            l as Map<String, dynamic>,
            canvasSize: canvasSize,
            isCover: true,
          ),
        )
        .toList();
  } catch (_) {
    return null;
  }
}

/// 정적 이미지 빌드
Widget buildStaticImage(LayerModel layer) {
  final url = layer.previewUrl ?? layer.imageUrl ?? layer.originalUrl ?? '';
  if (url.isEmpty) {
    return Positioned(
      left: layer.position.dx,
      top: layer.position.dy,
      child: Transform.rotate(
        angle: layer.rotation * math.pi / 180,
        child: Transform.scale(
          scale: layer.scale,
          child: Opacity(
            opacity: layer.opacity,
            child: Container(
              width: layer.width,
              height: layer.height,
              color: Colors.grey[300],
            ),
          ),
        ),
      ),
    );
  }
  return Positioned(
    left: layer.position.dx,
    top: layer.position.dy,
    child: Transform.rotate(
      angle: layer.rotation * math.pi / 180,
      alignment: Alignment.center, // [Fix] 중심축 통일
      child: Transform.scale(
        scale: layer.scale,
        alignment: Alignment.center, // [Fix] 중심축 통일
        child: Opacity(
          opacity: layer.opacity,
          child: _buildStaticFramedImage(
            layer,
            SizedBox(
              width: layer.width,
              height: layer.height,
              child: SnapfitImage(
                urlOrGs: url,
                fit: BoxFit.cover,
                cacheManager: snapfitImageCacheManager,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 정적 텍스트 빌드
Widget buildStaticText(LayerModel layer) {
  return Positioned(
    left: layer.position.dx,
    top: layer.position.dy,
    child: Transform.rotate(
      angle: layer.rotation * math.pi / 180,
      alignment: Alignment.center, // [Fix] 중심축 통일
      child: Transform.scale(
        scale: layer.scale,
        alignment: Alignment.center, // [Fix] 중심축 통일
        child: Opacity(
          opacity: layer.opacity,
          child: _buildStaticStyledText(layer),
        ),
      ),
    ),
  );
}

/// 홈 화면용 앨범 상태 헬퍼
///
/// - Draft: 커버/레이어/테마가 전혀 없는 "빈" 앨범이거나 id == 0 인 경우
/// - Live Editing: 목표 페이지(targetPages)를 아직 채우지 못한 경우
/// - Completed: targetPages를 모두 채운 경우 (totalPages >= targetPages)
bool isDraftAlbum(Album album) {
  final hasCoverUrl = (album.coverThumbnailUrl ??
              album.coverPreviewUrl ??
              album.coverImageUrl)
          ?.isNotEmpty ==
      true;
  final hasLayers = album.coverLayersJson.isNotEmpty;
  final hasTheme = album.coverTheme?.isNotEmpty == true;

  final hasVisual = hasCoverUrl || hasLayers || hasTheme;

  // 서버에 실제로 저장되지 않았거나, 커버 정보가 전혀 없는 경우만 Draft로 간주
  if (album.id == 0) return true;
  return !hasVisual;
}

bool isLiveEditingAlbum(Album album) {
  if (isDraftAlbum(album)) return false;
  if (album.targetPages <= 0) {
    // 목표 페이지 미설정: 진행 중으로 간주
    return true;
  }
  return album.totalPages < album.targetPages;
}

bool isCompletedAlbum(Album album) {
  if (isDraftAlbum(album)) return false;
  if (album.targetPages <= 0) return false;
  return album.totalPages >= album.targetPages;
}

/// 앨범 상태 정보 (라벨, 배경색, 글자색) 반환
class AlbumStatusInfo {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool isLocked;

  AlbumStatusInfo({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.isLocked = false,
  });
}

AlbumStatusInfo getAlbumStatusInfo(Album album, String currentUserId) {
  // 1. Busy (남이 편집 중)
  // 1. Busy (남이 편집 중)
  // lockedById가 있는 경우 ID끼리 비교, 없으면(구버전 호환) lockedBy(이름)와 비교하되 이름이 같을 수 있으므로 주의
  // 여기서는 lockedById가 있으면 우선 사용
  if (album.lockedById != null) {
      if (album.lockedById != currentUserId) {
          return AlbumStatusInfo(
            label: '${album.lockedBy ?? "다른 사용자"} 편집 중',
            backgroundColor: const Color(0xFFFFEAEA),
            foregroundColor: const Color(0xFFFF4D4D),
            isLocked: true,
          );
      }
  } else if (album.lockedBy != null && album.lockedBy != currentUserId) {
    // 하위 호환: lockedById가 없는 경우 기존 로직 (이름 비교) 실패 가능성 있음
    return AlbumStatusInfo(
      label: '${album.lockedBy} 편집 중',
      backgroundColor: const Color(0xFFFFEAEA), // Light Red/Orange
      foregroundColor: const Color(0xFFFF4D4D), // Red
      isLocked: true,
    );
  }

  // 2. Done (완료)
  if (isCompletedAlbum(album)) {
    return AlbumStatusInfo(
      label: '작성 완료',
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
    );
  }

  // 3. Working (작성 중) - Default
  return AlbumStatusInfo(
    label: '작성 중',
    backgroundColor: const Color(0xFF00C2E0), // Cyan background
    foregroundColor: Colors.white,             // White text
  );
}
/// 이미지 프레임 정적 렌더링 (LayerBuilder와 로직 동기화)
Widget _buildStaticFramedImage(LayerModel layer, Widget child) {
  switch (layer.imageBackground) {
    case 'round':
      return ClipRRect(borderRadius: BorderRadius.circular(16), child: child);
    case 'polaroid':
      return Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1.2),
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(10), child: child),
      );
    case 'polaroidClassic':
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 36),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFEF5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E4D8), width: 1.4),
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: child),
      );
    case 'sticker':
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black, width: 4),
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(12), child: child),
      );
    default:
      return child;
  }
}

/// 텍스트 스타일 정적 렌더링 (홈/리더 커버 썸네일용 — 저장된 textBackground 모두 표시)
Widget _buildStaticStyledText(LayerModel layer) {
  if (layer.textBackground == null || layer.textBackground!.isEmpty) {
    return SizedBox(
      width: layer.width,
      child: Text(
        layer.text ?? '',
        style: layer.textStyle,
        textAlign: layer.textAlign,
      ),
    );
  }

  final Widget content = Text(
    layer.text ?? '',
    style: layer.textStyle,
    textAlign: layer.textAlign,
  );
  final String bg = layer.textBackground!;

  switch (bg) {
    case 'tag':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.06),
          borderRadius: BorderRadius.circular(999),
        ),
        child: content,
      );
    case 'round':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE0E4EC)),
        ),
        child: content,
      );
    case 'bubble':
    case 'bubbleCenter':
    case 'bubbleCloud':
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.22)),
        ),
        child: content,
      );
    case 'labelSolid':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2C3E50),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          layer.text ?? '',
          style: (layer.textStyle ?? const TextStyle()).copyWith(color: Colors.white),
          textAlign: layer.textAlign,
        ),
      );
    case 'labelOutline':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF00BCD4)),
        ),
        child: content,
      );
    case 'note':
    case 'noteYellow':
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9C4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.brown.withOpacity(0.35)),
        ),
        child: content,
      );
    case 'noteBlue':
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F0FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFBBC8EC)),
        ),
        child: content,
      );
    case 'notePink':
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEFF4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE4B4C7)),
        ),
        child: content,
      );
    case 'noteMint':
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F7F0),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFB0D9CC)),
        ),
        child: content,
      );
    case 'noteLavender':
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E8FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFD4C0EB)),
        ),
        child: content,
      );
    case 'tape':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: LinearGradient(
            colors: [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: content,
      );
    case 'tapeYellow':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF9C4), Color(0xFFFFFDE7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: content,
      );
    case 'tapePink':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFE4EC), Color(0xFFFFF0F4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: content,
      );
    case 'sticker':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black, width: 3),
        ),
        child: content,
      );
    case 'calligraphy':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.amber.shade700),
        ),
        child: content,
      );
    default:
      // 알 수 없는 스타일도 말풍선 스타일로 표시
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.22)),
        ),
        child: content,
      );
  }
}
