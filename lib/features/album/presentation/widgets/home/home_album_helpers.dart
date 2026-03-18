import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../../../../../core/constants/cover_theme.dart';
import '../../../../../core/constants/snapfit_colors.dart';
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

class AlbumProgressInfo {
  final int completedPages;
  final int targetPages;

  const AlbumProgressInfo({
    required this.completedPages,
    required this.targetPages,
  });

  bool get hasTarget => targetPages > 0;

  double get ratio =>
      hasTarget ? (completedPages / targetPages).clamp(0.0, 1.0) : 0.0;

  String get percentLabel => hasTarget ? '${(ratio * 100).round()}%' : '목표 없음';

  String get pageProgressLabel => hasTarget
      ? '$completedPages/$targetPages 페이지 진행 중'
      : '$completedPages 페이지 진행 중';
}

AlbumProgressInfo calculateAlbumProgress(Album album) {
  final int fallbackCompleted = _countCompletedInnerPagesFromCoverLayersJson(
    album.coverLayersJson,
  );
  final int completed = math.max(album.totalPages, fallbackCompleted);
  final int target = album.targetPages > 0 ? album.targetPages : 0;
  final int clampedCompleted = target > 0
      ? completed.clamp(0, target)
      : completed;

  return AlbumProgressInfo(
    completedPages: clampedCompleted,
    targetPages: target,
  );
}

Color sharedAlbumCoverToneColor(Album album) {
  final fallback = const Color(0xFFE8E2D0);

  final theme = (album.coverTheme ?? '').toLowerCase();
  if (theme.contains('classic2')) return const Color(0xFFDBDDE6);
  if (theme.contains('nature')) return const Color(0xFFDDE9DA);
  if (theme.contains('architecture')) return const Color(0xFFE5E1D6);
  if (theme.contains('abstract')) return const Color(0xFFE4DFF1);
  if (theme.contains('texture')) return const Color(0xFFE2DDD4);

  final toneKey = _extractCoverToneKey(album.coverLayersJson);
  if (toneKey != null) {
    final k = toneKey.toLowerCase();
    if (k.contains('pink') || k.contains('rose') || k.contains('coral')) {
      return const Color(0xFFF0D9DA);
    }
    if (k.contains('blue') || k.contains('navy')) {
      return const Color(0xFFD8E1F0);
    }
    if (k.contains('mint') || k.contains('green') || k.contains('teal')) {
      return const Color(0xFFDDEADE);
    }
    if (k.contains('orange') || k.contains('yellow') || k.contains('gold')) {
      return const Color(0xFFF0E2CB);
    }
    if (k.contains('lavender') || k.contains('purple')) {
      return const Color(0xFFE5DEF2);
    }
    if (k.contains('gray') || k.contains('grey')) {
      return const Color(0xFFE3E3E3);
    }
    if (k.contains('cream') || k.contains('beige') || k.contains('paper')) {
      return const Color(0xFFE9E2D5);
    }
  }

  return fallback;
}

/// 커버 레이어 파싱
List<LayerModel>? parseCoverLayers(String raw, {required Size canvasSize}) {
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
  final hasAssetUrl = url.startsWith('asset:');
  final assetPath = hasAssetUrl ? url.substring('asset:'.length) : null;
  final imageChild = url.isEmpty
      ? (layer.asset != null
            ? AssetEntityImage(layer.asset!, fit: BoxFit.cover)
            : Container(
                width: layer.width,
                height: layer.height,
                color: Colors.grey[300],
              ))
      : hasAssetUrl
      ? Image.asset(assetPath!, fit: BoxFit.cover)
      : SnapfitImage(
          urlOrGs: url,
          fit: BoxFit.cover,
          cacheManager: snapfitImageCacheManager,
        );

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
            child: SizedBox(
              width: layer.width,
              height: layer.height,
              child: imageChild,
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
              child: imageChild,
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
  final hasCoverUrl =
      (album.coverThumbnailUrl ?? album.coverPreviewUrl ?? album.coverImageUrl)
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
  final progress = calculateAlbumProgress(album);
  if (!progress.hasTarget) {
    // 목표 페이지 미설정: 진행 중으로 간주
    return true;
  }
  return progress.completedPages < progress.targetPages;
}

bool isCompletedAlbum(Album album) {
  if (isDraftAlbum(album)) return false;
  final progress = calculateAlbumProgress(album);
  if (!progress.hasTarget) return false;
  return progress.completedPages >= progress.targetPages;
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
    foregroundColor: Colors.white, // White text
  );
}

int _countCompletedInnerPagesFromCoverLayersJson(String raw) {
  if (raw.isEmpty) return 0;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return 0;

    final pages = decoded['pages'];
    if (pages is! List) return 0;

    var completed = 0;
    for (final page in pages) {
      if (page is! Map) continue;
      final isCover = page['isCover'] == true || page['index'] == 0;
      if (isCover) continue;

      final layers = page['layers'];
      if (layers is! List) continue;

      final hasMeaningfulLayer = layers.any(_isMeaningfulProgressLayer);
      if (hasMeaningfulLayer) completed++;
    }
    return completed;
  } catch (_) {
    return 0;
  }
}

bool _isMeaningfulProgressLayer(dynamic rawLayer) {
  if (rawLayer is! Map) return false;
  final layer = rawLayer.cast<String, dynamic>();

  final type = (layer['type'] as String? ?? '').toUpperCase();
  final payload =
      (layer['payload'] as Map?)?.cast<String, dynamic>() ?? const {};

  if (type == 'TEXT') {
    final text = payload['text'] as String?;
    return text != null && text.trim().isNotEmpty;
  }

  final preview = payload['previewUrl'] as String?;
  final image = payload['imageUrl'] as String?;
  final original = payload['originalUrl'] as String?;
  final url = preview ?? image ?? original;
  return url != null && url.trim().isNotEmpty;
}

String? _extractCoverToneKey(String raw) {
  if (raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    final pages = decoded['pages'];
    if (pages is! List || pages.isEmpty) return null;
    final first = pages.first;
    if (first is! Map) return null;
    final layers = first['layers'];
    if (layers is! List || layers.isEmpty) return null;

    for (final rawLayer in layers.reversed) {
      if (rawLayer is! Map) continue;
      final layer = rawLayer.cast<String, dynamic>();
      final payload =
          (layer['payload'] as Map?)?.cast<String, dynamic>() ?? const {};
      final imageBackground = payload['imageBackground'] as String?;
      if (imageBackground != null && imageBackground.trim().isNotEmpty) {
        return imageBackground;
      }
      final textBackground = payload['textBackground'] as String?;
      if (textBackground != null && textBackground.trim().isNotEmpty) {
        return textBackground;
      }
    }
  } catch (_) {
    return null;
  }
  return null;
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

Color _roundBgColor(String bg) {
  switch (bg) {
    case 'roundGray':
      return SnapFitStylePalette.gray;
    case 'roundPink':
      return SnapFitStylePalette.pink;
    case 'roundBlue':
      return SnapFitStylePalette.blue;
    case 'roundMint':
      return SnapFitStylePalette.mint;
    case 'roundLavender':
      return SnapFitStylePalette.lavender;
    case 'roundOrange':
      return SnapFitStylePalette.orange;
    case 'roundGreen':
      return SnapFitStylePalette.green;
    case 'roundCream':
      return SnapFitStylePalette.cream;
    case 'roundNavy':
      return SnapFitStylePalette.navy;
    case 'roundRose':
      return SnapFitStylePalette.rose;
    case 'roundCoral':
      return SnapFitStylePalette.coral;
    case 'roundBeige':
      return SnapFitStylePalette.beige;
    case 'roundTeal':
      return SnapFitStylePalette.teal;
    case 'roundLemon':
      return SnapFitStylePalette.lemon;
    default:
      return SnapFitStylePalette.white;
  }
}

Color _roundBorderColor(String bg) {
  if (bg == 'round') return const Color(0xFFE0E4EC);
  return Color.lerp(_roundBgColor(bg), Colors.black, 0.08) ??
      const Color(0xFFE0E4EC);
}

Color _squareBgColor(String bg) {
  switch (bg) {
    case 'squareGray':
      return SnapFitStylePalette.gray;
    case 'squarePink':
      return SnapFitStylePalette.pink;
    case 'squareBlue':
      return SnapFitStylePalette.blue;
    case 'squareMint':
      return SnapFitStylePalette.mint;
    case 'squareLavender':
      return SnapFitStylePalette.lavender;
    case 'squareOrange':
      return SnapFitStylePalette.orange;
    case 'squareGreen':
      return SnapFitStylePalette.green;
    case 'squareCream':
      return SnapFitStylePalette.cream;
    case 'squareNavy':
      return SnapFitStylePalette.navy;
    case 'squareRose':
      return SnapFitStylePalette.rose;
    case 'squareCoral':
      return SnapFitStylePalette.coral;
    case 'squareBeige':
      return SnapFitStylePalette.beige;
    case 'squareTeal':
      return SnapFitStylePalette.teal;
    case 'squareLemon':
      return SnapFitStylePalette.lemon;
    default:
      return SnapFitStylePalette.white;
  }
}

Color _squareBorderColor(String bg) {
  if (bg == 'square') return const Color(0xFFE0E4EC);
  return Color.lerp(_squareBgColor(bg), Colors.black, 0.08) ??
      const Color(0xFFE0E4EC);
}

Color _roundSoftBgColor(String bg) {
  switch (bg) {
    case 'roundSoftGray':
      return SnapFitStylePalette.gray;
    case 'roundSoftPink':
      return SnapFitStylePalette.pink;
    case 'roundSoftBlue':
      return SnapFitStylePalette.blue;
    case 'roundSoftMint':
      return SnapFitStylePalette.mint;
    case 'roundSoftLavender':
      return SnapFitStylePalette.lavender;
    case 'roundSoftOrange':
      return SnapFitStylePalette.orange;
    case 'roundSoftGreen':
      return SnapFitStylePalette.green;
    case 'roundSoftCream':
      return SnapFitStylePalette.cream;
    case 'roundSoftNavy':
      return SnapFitStylePalette.navy;
    case 'roundSoftRose':
      return SnapFitStylePalette.rose;
    case 'roundSoftCoral':
      return SnapFitStylePalette.coral;
    case 'roundSoftBeige':
      return SnapFitStylePalette.beige;
    case 'roundSoftTeal':
      return SnapFitStylePalette.teal;
    case 'roundSoftLemon':
      return SnapFitStylePalette.lemon;
    default:
      return SnapFitStylePalette.white;
  }
}

Color _bubbleFillColor(String bg) {
  if (bg.endsWith('Gray')) return SnapFitStylePalette.gray;
  if (bg.endsWith('Pink')) return SnapFitStylePalette.pink;
  if (bg.endsWith('Blue')) return SnapFitStylePalette.blue;
  if (bg.endsWith('Mint')) return SnapFitStylePalette.mint;
  if (bg.endsWith('Lavender')) return SnapFitStylePalette.lavender;
  if (bg.endsWith('Orange')) return SnapFitStylePalette.orange;
  if (bg.endsWith('Green')) return SnapFitStylePalette.green;
  if (bg.endsWith('Cream')) return SnapFitStylePalette.cream;
  if (bg.endsWith('Navy')) return SnapFitStylePalette.navy;
  if (bg.endsWith('Rose')) return SnapFitStylePalette.rose;
  if (bg.endsWith('Coral')) return SnapFitStylePalette.coral;
  if (bg.endsWith('Beige')) return SnapFitStylePalette.beige;
  if (bg.endsWith('Teal')) return SnapFitStylePalette.teal;
  if (bg.endsWith('Lemon')) return SnapFitStylePalette.lemon;
  return SnapFitStylePalette.white;
}

Color _labelOvalBgColor(String bg) {
  switch (bg) {
    case 'labelGray':
      return SnapFitStylePalette.labelGray;
    case 'labelPink':
      return SnapFitStylePalette.labelPink;
    case 'labelBlue':
      return SnapFitStylePalette.labelBlue;
    case 'labelMint':
      return SnapFitStylePalette.labelMint;
    case 'labelLavender':
      return SnapFitStylePalette.labelLavender;
    case 'labelOrange':
      return SnapFitStylePalette.labelOrange;
    case 'labelGreen':
      return SnapFitStylePalette.labelGreen;
    case 'labelWhite':
      return SnapFitStylePalette.labelWhite;
    case 'labelCream':
      return SnapFitStylePalette.labelCream;
    default:
      return const Color(0xFFE0F7FA);
  }
}

Color _labelSolidBgColor(String bg) {
  switch (bg) {
    case 'labelSolidGray':
      return const Color(0xFF616161);
    case 'labelSolidPink':
      return const Color(0xFFAD1457);
    case 'labelSolidBlue':
      return const Color(0xFF1565C0);
    case 'labelSolidMint':
      return const Color(0xFF00695C);
    case 'labelSolidRed':
      return const Color(0xFFC62828);
    case 'labelSolidGreen':
      return const Color(0xFF2E7D32);
    case 'labelSolidOrange':
      return const Color(0xFFE65100);
    case 'labelSolidLavender':
      return const Color(0xFF5E35B1);
    case 'labelSolidCream':
      return const Color(0xFFF5F0E6);
    default:
      return const Color(0xFF2C3E50);
  }
}

Color _tagBorderColor(String bg) {
  switch (bg) {
    case 'tagGray':
      return SnapFitStylePalette.tagGray;
    case 'tagPink':
      return SnapFitStylePalette.tagPink;
    case 'tagBlue':
      return SnapFitStylePalette.tagBlue;
    case 'tagMint':
      return SnapFitStylePalette.tagMint;
    case 'tagLavender':
      return SnapFitStylePalette.tagLavender;
    case 'tagOrange':
      return SnapFitStylePalette.tagOrange;
    case 'tagGreen':
      return SnapFitStylePalette.tagGreen;
    case 'tagRed':
      return const Color(0xFFE57373);
    default:
      return const Color(0xFFB0B0B0);
  }
}

Color _tapeSolidBgColor(String bg) {
  switch (bg) {
    case 'tapeKraft':
      return SnapFitStylePalette.tapeKraft;
    case 'tapeGold':
      return SnapFitStylePalette.tapeGold;
    case 'tapeSolidWhite':
      return SnapFitStylePalette.labelWhite;
    case 'tapeSolidGray':
      return const Color(0xFFE0E0E0);
    case 'tapeSolidPink':
      return const Color(0xFFFFCDD2);
    case 'tapeSolidBlue':
      return const Color(0xFFBBDEFB);
    case 'tapeSolidMint':
      return const Color(0xFFB2DFDB);
    case 'tapeSolidLavender':
      return const Color(0xFFD1C4E9);
    case 'tapeSolidOrange':
      return const Color(0xFFFFE0B2);
    case 'tapeSolidGreen':
      return const Color(0xFFC8E6C9);
    default:
      return SnapFitStylePalette.tapeKraft;
  }
}

(Color, Color) _noteGridColors(String bg) {
  switch (bg) {
    case 'noteGridBlue':
      return (SnapFitStylePalette.blue, const Color(0xFFBBDEFB));
    case 'noteGridPink':
      return (SnapFitStylePalette.pink, const Color(0xFFFFCDD2));
    case 'noteGridMint':
      return (SnapFitStylePalette.mint, const Color(0xFF80CBC4));
    case 'noteGridLavender':
      return (SnapFitStylePalette.lavender, const Color(0xFFB39DDB));
    case 'noteGridOrange':
      return (SnapFitStylePalette.orange, const Color(0xFFFFCC80));
    case 'noteGridGray':
      return (SnapFitStylePalette.gray, const Color(0xFFBDBDBD));
    default:
      return (const Color(0xFFFFFDE7), const Color(0xFFE8E0B0));
  }
}

(Color, Color) _tapeDotsColors(String bg) {
  switch (bg) {
    case 'tapeDotsPink':
      return (SnapFitStylePalette.labelPink, SnapFitStylePalette.tagPink);
    case 'tapeDotsMint':
      return (SnapFitStylePalette.mint, SnapFitStylePalette.tagMint);
    case 'tapeDotsLavender':
      return (SnapFitStylePalette.lavender, SnapFitStylePalette.tagLavender);
    case 'tapeDotsOrange':
      return (SnapFitStylePalette.orange, SnapFitStylePalette.tagOrange);
    case 'tapeDotsGray':
      return (
        SnapFitStylePalette.stripeGrayBase,
        SnapFitStylePalette.stripeGrayStripe,
      );
    default:
      return (const Color(0xFFFFE0B2), const Color(0xFFFFCC80));
  }
}

(Color, Color) _tapeDoubleColors(String bg) {
  switch (bg) {
    case 'tapeDoublePink':
      return (SnapFitStylePalette.pink, const Color(0xFFFFCDD2));
    case 'tapeDoubleMint':
      return (SnapFitStylePalette.mint, const Color(0xFFA7FFEB));
    case 'tapeDoubleBlue':
      return (const Color(0xFFE3F2FD), const Color(0xFF90CAF9));
    case 'tapeDoubleLavender':
      return (SnapFitStylePalette.lavender, SnapFitStylePalette.tagLavender);
    case 'tapeDoubleGray':
      return (
        SnapFitStylePalette.stripeGrayBase,
        SnapFitStylePalette.stripeGrayStripe,
      );
    default:
      return (const Color(0xFFE3F2FD), const Color(0xFF90CAF9));
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
    case 'roundGray':
    case 'roundPink':
    case 'roundBlue':
    case 'roundMint':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _roundBgColor(bg),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _roundBorderColor(bg)),
        ),
        child: content,
      );
    case 'square':
    case 'squareGray':
    case 'squarePink':
    case 'squareBlue':
    case 'squareMint':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _squareBgColor(bg),
          borderRadius: BorderRadius.zero,
          border: Border.all(color: _squareBorderColor(bg)),
        ),
        child: content,
      );
    case 'roundSoft':
    case 'roundSoftGray':
    case 'roundSoftPink':
    case 'roundSoftBlue':
    case 'roundSoftMint':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _roundSoftBgColor(bg),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: content,
      );
    case 'bubble':
    case 'bubbleGray':
    case 'bubblePink':
    case 'bubbleBlue':
    case 'bubbleMint':
    case 'bubbleCenter':
    case 'bubbleCenterGray':
    case 'bubbleCenterPink':
    case 'bubbleCenterBlue':
    case 'bubbleCenterMint':
    case 'bubbleRight':
    case 'bubbleRightGray':
    case 'bubbleRightPink':
    case 'bubbleRightBlue':
    case 'bubbleRightMint':
    case 'bubbleSquare':
    case 'bubbleSquareGray':
    case 'bubbleSquarePink':
    case 'bubbleSquareBlue':
    case 'bubbleSquareMint':
    case 'bubbleSquareCenter':
    case 'bubbleSquareCenterGray':
    case 'bubbleSquareCenterPink':
    case 'bubbleSquareCenterBlue':
    case 'bubbleSquareCenterMint':
    case 'bubbleSquareRight':
    case 'bubbleSquareRightGray':
    case 'bubbleSquareRightPink':
    case 'bubbleSquareRightBlue':
    case 'bubbleSquareRightMint':
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: BoxDecoration(
          color: _bubbleFillColor(bg),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _bubbleFillColor(bg) == Colors.white
                ? Colors.black.withOpacity(0.22)
                : (Color.lerp(_bubbleFillColor(bg), Colors.black, 0.12) ??
                      Colors.black26),
          ),
        ),
        child: content,
      );
    case 'label':
    case 'labelGray':
    case 'labelPink':
    case 'labelBlue':
    case 'labelMint':
    case 'labelLavender':
    case 'labelOrange':
    case 'labelGreen':
    case 'labelWhite':
    case 'labelCream':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _labelOvalBgColor(bg),
          borderRadius: BorderRadius.circular(999),
        ),
        child: content,
      );
    case 'tag':
    case 'tagGray':
    case 'tagPink':
    case 'tagBlue':
    case 'tagMint':
    case 'tagLavender':
    case 'tagOrange':
    case 'tagGreen':
    case 'tagRed':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _tagBorderColor(bg),
            style: BorderStyle.solid,
          ),
        ),
        child: content,
      );
    case 'labelSolid':
    case 'labelSolidGray':
    case 'labelSolidPink':
    case 'labelSolidBlue':
    case 'labelSolidMint':
    case 'labelSolidRed':
    case 'labelSolidGreen':
    case 'labelSolidOrange':
    case 'labelSolidLavender':
    case 'labelSolidCream':
      final solidBg = _labelSolidBgColor(bg);
      final solidTextColor = (bg == 'labelSolidCream')
          ? const Color(0xFF5D4037)
          : Colors.white;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: solidBg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          layer.text ?? '',
          style: (layer.textStyle ?? const TextStyle()).copyWith(
            color: solidTextColor,
          ),
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
    case 'labelGold':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF5E6C8), Color(0xFFE8D4A8), Color(0xFFD4B896)],
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: content,
      );
    case 'labelNeon':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF00E5FF), width: 2),
        ),
        child: content,
      );
    case 'labelRose':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8BBD9), Color(0xFFF48FB1)],
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: content,
      );
    case 'note':
    case 'noteYellow':
    case 'noteTorn':
    case 'noteTornYellow':
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9C4),
          borderRadius: BorderRadius.zero,
        ),
        child: content,
      );
    case 'noteBlue':
    case 'noteTornBlue':
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F0FF),
          borderRadius: BorderRadius.zero,
        ),
        child: content,
      );
    case 'notePink':
    case 'noteTornPink':
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEFF4),
          borderRadius: BorderRadius.zero,
        ),
        child: content,
      );
    case 'noteMint':
    case 'noteTornMint':
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F7F0),
          borderRadius: BorderRadius.zero,
        ),
        child: content,
      );
    case 'noteLavender':
    case 'noteTornLavender':
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E8FF),
          borderRadius: BorderRadius.zero,
        ),
        child: content,
      );
    case 'noteOrange':
    case 'noteTornOrange':
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0E0),
          borderRadius: BorderRadius.zero,
        ),
        child: content,
      );
    case 'noteGray':
    case 'noteTornGray':
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.zero,
        ),
        child: content,
      );
    case 'noteBeige':
    case 'noteTornBeige':
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F0E8),
          borderRadius: BorderRadius.zero,
        ),
        child: content,
      );
    case 'noteGold':
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.zero,
        ),
        child: content,
      );
    case 'noteCream':
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF0),
          borderRadius: BorderRadius.zero,
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
    case 'tapeMint':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        decoration: BoxDecoration(
          color: const Color(0xFFD8F0E8),
          borderRadius: BorderRadius.circular(4),
        ),
        child: content,
      );
    case 'tapeLavender':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        decoration: BoxDecoration(
          color: const Color(0xFFEDE4F5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: content,
      );
    case 'tapeGray':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        decoration: BoxDecoration(
          color: const Color(0xFFE8E8E8),
          borderRadius: BorderRadius.circular(4),
        ),
        child: content,
      );
    case 'tapeDots':
    case 'tapeDotsPink':
    case 'tapeDotsMint':
    case 'tapeDotsLavender':
      final dotsColors = _tapeDotsColors(bg);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        decoration: BoxDecoration(
          color: dotsColors.$1,
          borderRadius: BorderRadius.circular(4),
        ),
        child: content,
      );
    case 'tapeKraft':
    case 'tapeGold':
    case 'tapeSolidWhite':
    case 'tapeSolidGray':
    case 'tapeSolidPink':
    case 'tapeSolidBlue':
    case 'tapeSolidMint':
    case 'tapeSolidLavender':
    case 'tapeSolidOrange':
    case 'tapeSolidGreen':
      final solidBg = _tapeSolidBgColor(bg);
      final solidTextColor =
          (bg == 'tapeKraft' ||
              bg == 'tapeGold' ||
              solidBg.computeLuminance() > 0.6)
          ? const Color(0xFF5D4037)
          : Colors.white;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: solidBg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          layer.text ?? '',
          style: (layer.textStyle ?? const TextStyle()).copyWith(
            color: solidTextColor,
          ),
          textAlign: layer.textAlign,
        ),
      );
    case 'tapeDouble':
    case 'tapeDoublePink':
    case 'tapeDoubleMint':
      final doubleColors = _tapeDoubleColors(bg);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: doubleColors.$1,
          borderRadius: BorderRadius.circular(4),
        ),
        child: content,
      );
    case 'highlightYellow':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEB3B).withOpacity(0.55),
          borderRadius: BorderRadius.zero,
        ),
        child: content,
      );
    case 'highlightGreen':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFB8E986).withOpacity(0.65),
          borderRadius: BorderRadius.zero,
        ),
        child: content,
      );
    case 'highlightPink':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFB6C1).withOpacity(0.7),
          borderRadius: BorderRadius.zero,
        ),
        child: content,
      );
    case 'stampRed':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFC62828),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          layer.text ?? '',
          style: (layer.textStyle ?? const TextStyle()).copyWith(
            color: const Color(0xFFFFF8E7),
            fontWeight: FontWeight.w700,
          ),
          textAlign: layer.textAlign,
        ),
      );
    case 'stampBlue':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1565C0),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          layer.text ?? '',
          style: (layer.textStyle ?? const TextStyle()).copyWith(
            color: const Color(0xFFFFF8E7),
            fontWeight: FontWeight.w700,
          ),
          textAlign: layer.textAlign,
        ),
      );
    case 'ticket':
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF0),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFE8DCC8)),
        ),
        child: content,
      );
    case 'ribbon':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE91E63),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          layer.text ?? '',
          style: (layer.textStyle ?? const TextStyle()).copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          textAlign: layer.textAlign,
        ),
      );
    case 'quote':
      return Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 16, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(8),
          border: const Border(
            left: BorderSide(color: Color(0xFF00C2E0), width: 5),
          ),
        ),
        child: content,
      );
    case 'chalkboard':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF263238),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF546E7A), width: 2),
        ),
        child: Text(
          layer.text ?? '',
          style: (layer.textStyle ?? const TextStyle()).copyWith(
            color: const Color(0xFFECEFF1),
            fontWeight: FontWeight.w600,
          ),
          textAlign: layer.textAlign,
        ),
      );
    case 'caption':
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: content,
      );
    case 'noteGrid':
    case 'noteGridBlue':
    case 'noteGridPink':
      final gridColors = _noteGridColors(bg);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: gridColors.$1,
          borderRadius: BorderRadius.zero,
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
