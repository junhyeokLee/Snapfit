import 'dart:convert';
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
    return Container(color: Colors.grey[300]);
  }
  return SnapfitImage(
    urlOrGs: url,
    fit: BoxFit.cover,
    cacheManager: snapfitImageCacheManager,
  );
}

/// 정적 텍스트 빌드
Widget buildStaticText(LayerModel layer) {
  return Text(
    layer.text ?? '',
    style: layer.textStyle,
    textAlign: layer.textAlign,
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
