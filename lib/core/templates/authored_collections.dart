import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/cover_size.dart';
import 'studio_decoration_catalog.dart';
import 'template_catalog_categories.dart';

part 'authored_petal.dart';
part 'authored_wander.dart';
part 'authored_good.dart';
part 'authored_lightbound.dart';
part 'authored_editorial_drafts.dart';
part 'authored_journey.dart';
part 'authored_small_days.dart';
part 'authored_free_expansion.dart';
part 'authored_free_layouts.dart';
part 'authored_life_collections.dart';
part 'authored_life_layouts.dart';
part 'authored_wind_atlas.dart';
part 'authored_prose_study.dart';
part 'authored_prose_album.dart';
part 'authored_luminous_edition.dart';

/// Original authored compositions. Never used as fallback output for AI.
enum CollectionAspect {
  portrait,
  square,
  landscape;

  // Authored source geometry is independent of the selectable print catalog.
  CoverSize get cover => legacyCoverSizes[index];
  Size get canvas => Size(500, 500 / cover.realSize.aspectRatio);
}

class AuthoredCollection {
  const AuthoredCollection(
    this.id,
    this.title,
    this.subtitle,
    this.category, {
    required this.bundledId,
  });
  final String id, title, subtitle, category;
  final int bundledId;

  List<String> get styleTags => collectionStyleTags[id] ?? const [];

  int get innerPageCount =>
      (document(CollectionAspect.square)['pages'] as List).length;

  List<String> get chapters => switch (id) {
    'lightbound' => lightboundSpreadNames,
    'journey' => EditorialVolume.journey.chapters,
    'small-days' => EditorialVolume.smallDays.chapters,
    'wind-atlas' => windAtlasSpreads,
    proseStudyId => proseAlbumSpreads,
    'petal_archive' => ['설레는 준비', '우리의 약속', '함께한 마음', '오후의 여운', '오래 남길 편지'],
    'lost_and_found' => ['여행의 시작', '낯선 길 위에서', '동네의 맛', '주머니 속 기록', '돌아오는 길'],
    'good_things' => ['좋은 아침', '취향을 모아서', '밖에서 보낸 시간', '작은 기록들', '다음의 우리'],
    _ => FreeCollectionVolume.byId(id)?.chapters ?? const [],
  };

  Map<String, dynamic> document(CollectionAspect aspect) {
    final current = switch (id) {
      'lightbound' => buildLightboundWeddingDraft(aspect),
      'journey' => EditorialVolume.journey.document(aspect),
      'small-days' => EditorialVolume.smallDays.document(aspect),
      'wind-atlas' => buildWindAtlas(aspect),
      proseStudyId => buildProseAlbum(aspect),
      _ => FreeCollectionVolume.byId(id)?.document(aspect),
    };
    if (current != null) return current;
    final pages = switch (id) {
      'petal_archive' => _petal(aspect),
      'lost_and_found' => _wander(aspect),
      'good_things' => _good(aspect),
      _ => throw StateError('Unknown collection: $id'),
    };
    return {
      'id': 'snapfit_original_${id}_${aspect.name}',
      'title': title,
      'source': 'snapfit-authored',
      'aiGenerated': false,
      'version': 2,
      'chapters': [
        for (var i = 0; i < chapters.length; i++)
          {'title': chapters[i], 'from': 1 + i * 4, 'to': 4 + i * 4},
      ],
      'innerPageCount': pages.length - 1,
      'aspect': aspect.name,
      'designWidth': aspect.canvas.width,
      'designHeight': aspect.canvas.height,
      'cover': pages.first,
      'pages': pages.skip(1).toList(),
    };
  }

  Map<String, dynamic> catalogDocument() => {
    ...document(CollectionAspect.square),
    'variants': {for (final a in CollectionAspect.values) a.name: document(a)},
  };
}

const baselineAuthoredCollections = [
  AuthoredCollection(
    'lightbound',
    lightboundWeddingTitle,
    '빛과 마음을 담은 웨딩 기록',
    '웨딩',
    bundledId: -9301,
  ),
  AuthoredCollection(
    'journey',
    '여행의 결',
    '낯선 곳에서 모은 사진과 문장',
    '여행',
    bundledId: -9302,
  ),
  AuthoredCollection(
    'small-days',
    '작은 날의 기록',
    '평범한 하루에서 발견한 좋은 순간',
    '일상',
    bundledId: -9303,
  ),
];

final authoredCollections = List<AuthoredCollection>.unmodifiable([
  ...baselineAuthoredCollections,
  for (final volume in FreeCollectionVolume.values)
    AuthoredCollection(
      volume.id,
      volume.title,
      volume.subtitle,
      volume.category,
      bundledId: volume.bundledId,
    ),
  const AuthoredCollection(
    windAtlasId,
    windAtlasTitle,
    '바람과 풍경, 사진과 문장으로 엮은 여행',
    '여행',
    bundledId: windAtlasBundledId,
  ),
  const AuthoredCollection(
    proseStudyId,
    proseStudyTitle,
    '사진 곁의 짧은 기록, 함께한 날의 스물네 장면',
    '커플·기념일',
    bundledId: proseAlbumBundledId,
  ),
]);

/// Archive for saved-document compatibility and regression tests, never a menu.
const retiredAuthoredCollections = [
  AuthoredCollection(
    'petal_archive',
    _petalTitle,
    '꽃처럼 간직한 날들',
    '웨딩',
    bundledId: -9201,
  ),
  AuthoredCollection(
    'lost_and_found',
    _wanderTitle,
    '여행에서 모은 작은 조각',
    '여행',
    bundledId: -9202,
  ),
  AuthoredCollection(
    'good_things',
    _goodTitle,
    '좋아하는 순간 수집',
    '일상',
    bundledId: -9203,
  ),
];
const _petalTitle = '꽃처럼 피어난 날';
const _wanderTitle = '낯선 곳의 조각들';
const _goodTitle = '좋아하는 순간들';
const _editorial = 'assets/templates/original_editorial/images/';

class _Sheet {
  _Sheet(
    this.collection,
    this.aspect,
    this.index,
    String background, {
    this.ink = '#28282B',
    this.display = 'Cormorant Garamond',
    this.displayWeight = 400,
  }) {
    box('paper', 0, 0, 1, 1, background);
  }
  final String collection;
  final CollectionAspect aspect;
  final int index;
  final String ink, display;
  final int displayWeight;
  final layers = <Map<String, dynamic>>[];
  double get unit => math.min(aspect.canvas.width, aspect.canvas.height);
  double get ratio => aspect.canvas.aspectRatio;
  bool get wide => aspect == CollectionAspect.landscape;

  void _add(
    String id,
    String type,
    double x,
    double y,
    double w,
    double h,
    Map<String, dynamic> data,
  ) => layers.add({
    'id': '${collection}_${aspect.name}_${index}_$id',
    'type': type,
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    'z': layers.length,
    ...data,
  });
  void box(String id, double x, double y, double w, double h, String color) =>
      _add(id, 'decoration', x, y, w, h, {
        'fillColor': color,
        'cornerRadius': 0,
      });
  void photo(
    String id,
    String path,
    double x,
    double y,
    double w,
    double h, {
    String shape = 'none',
    double rotation = 0,
  }) => _add(id, 'image', x, y, w, h, {
    'imageUrl': 'asset:$path',
    'frame': shape,
    'rotation': rotation,
  });
  void circle(
    String id,
    String path,
    double x,
    double y,
    double w, {
    String shape = 'studioOval',
  }) => photo(id, path, x, y, w, w * ratio, shape: shape);
  void material(
    String id,
    String key,
    double x,
    double y,
    double w, {
    double? h,
    double rotation = 0,
  }) {
    final spec = studioDecorationById(key)!;
    _add(
      id,
      spec.assetPath == null ? 'decoration' : 'sticker',
      x,
      y,
      w,
      h ?? w * ratio / spec.aspectRatio,
      {
        if (spec.assetPath != null) 'imageUrl': 'asset:${spec.assetPath}',
        if (spec.assetPath == null) 'style': key,
        'rotation': rotation,
      },
    );
  }

  void ornament(
    String id,
    String shape,
    String color,
    double x,
    double y,
    double w, {
    double? h,
    double rotation = 0,
  }) => _add(id, 'decoration', x, y, w, h ?? w * ratio, {
    'style': shape,
    'fillColor': color,
    'rotation': rotation,
  });
  void text(
    String id,
    String value,
    double x,
    double y,
    double w,
    double h, {
    double size = .027,
    String color = '#28282B',
    String font = 'NotoSans',
    int weight = 400,
    String align = 'left',
    double lineHeight = 1.2,
  }) => _add(id, 'text', x, y, w, h, {
    'text': value,
    'align': align,
    'style': {
      'fontFamily': font,
      'fontSize': unit * size,
      'fontWeight': weight,
      'color': color,
      'letterSpacing': 0,
      'height': lineHeight,
    },
  });
  void title(
    String value, {
    double x = .08,
    double y = .09,
    double w = .84,
    double h = .13,
    double size = .075,
    String? color,
    String align = 'left',
  }) => text(
    'title',
    value,
    x,
    y,
    w,
    h,
    size: size,
    color: color ?? ink,
    font: RegExp(r'[가-힣]').hasMatch(value)
        ? (display == 'Cormorant Garamond' ? 'Eulyoo' : 'NotoSans')
        : display,
    weight: displayWeight,
    align: align,
  );

  void copy(
    String value,
    double x,
    double y,
    double w,
    double h, {
    double size = .031,
    String? color,
    String align = 'left',
  }) => text(
    'copy_${layers.length}',
    value,
    x,
    y,
    w,
    h,
    size: size,
    color: color ?? ink,
    align: align,
    lineHeight: 1.35,
  );

  void kicker(String value, {double y = .06, String? color}) =>
      text('kicker', value, .08, y, .84, .04, size: .019, color: color ?? ink);

  Map<String, dynamic> finish(String name, String role) {
    folio(name, color: ink);
    return {
      ...json,
      'name': name,
      'role': role,
      'spreadIndex': index == 0 ? 0 : (index + 1) ~/ 2,
      'side': index == 0 ? 'cover' : (index.isOdd ? 'left' : 'right'),
    };
  }

  void folio(String label, {String color = '#696A68'}) {
    text('folio_label', label, .08, .93, .73, .04, size: .018, color: color);
    text(
      'folio_number',
      index == 0 ? 'VOL. 01' : index.toString().padLeft(2, '0'),
      .82,
      .93,
      .1,
      .04,
      size: .018,
      color: color,
      align: 'right',
    );
  }

  Map<String, dynamic> get json => {
    'strictLayout': true,
    'designWidth': aspect.canvas.width,
    'designHeight': aspect.canvas.height,
    'layers': layers,
  };
}
