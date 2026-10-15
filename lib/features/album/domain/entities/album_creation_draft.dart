import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../../core/constants/cover_size.dart';
import '../../../../core/constants/cover_theme.dart';
import 'album_page.dart';
import 'layer.dart';
import 'layer_export_mapper.dart';

class AlbumCreationEditorCheckpoint {
  AlbumCreationEditorCheckpoint({
    required List<AlbumPage> pages,
    required this.pageIndex,
    required this.coverCanvas,
    required this.innerCanvas,
    required this.theme,
  }) : pages = List.unmodifiable(
         pages.map(
           (page) => page.copyWith(
             layers: List.unmodifiable(
               page.layers.map((layer) => layer.copyWith()),
             ),
           ),
         ),
       );

  final List<AlbumPage> pages;
  final int pageIndex;
  final Size coverCanvas;
  final Size innerCanvas;
  final CoverTheme theme;

  Map<String, dynamic> toJson() => {
    'pageIndex': pageIndex,
    'coverCanvas': AlbumCreationDraft._size(coverCanvas),
    'innerCanvas': AlbumCreationDraft._size(innerCanvas),
    'theme': theme.name,
    'layers': AlbumCreationDraft._encodePages(
      pages.map((page) => page.layers).toList(),
    ),
    'pages': pages
        .map((page) => {'id': page.id, 'backgroundColor': page.backgroundColor})
        .toList(),
  };

  factory AlbumCreationEditorCheckpoint.fromJson(
    Map<String, dynamic> json, {
    AssetEntity Function(Map<String, dynamic>)? photoDecoder,
  }) {
    final coverCanvas = AlbumCreationDraft._decodeSize(json['coverCanvas']);
    final innerCanvas = AlbumCreationDraft._decodeSize(json['innerCanvas']);
    final metadata = json['pages'] as List;
    final layers = AlbumCreationDraft._decodePages(
      json['layers'], photoDecoder: photoDecoder,
    )!;
    final pageIndex = json['pageIndex'] as int;
    if (metadata.isEmpty ||
        metadata.length > 81 ||
        layers.length != metadata.length ||
        pageIndex < 0 ||
        pageIndex >= metadata.length ||
        ![
          coverCanvas.width,
          coverCanvas.height,
          innerCanvas.width,
          innerCanvas.height,
        ].every((value) => value.isFinite && value > 0)) {
      throw const FormatException('Invalid editor checkpoint');
    }
    return AlbumCreationEditorCheckpoint(
      pages: List.generate(
        metadata.length,
        (index) => AlbumPage(
          id: metadata[index]['id'] as String,
          pageIndex: index,
          isCover: index == 0,
          layers: layers[index],
          backgroundColor: metadata[index]['backgroundColor'] as int?,
        ),
      ),
      pageIndex: pageIndex,
      coverCanvas: coverCanvas,
      innerCanvas: innerCanvas,
      theme: CoverTheme.values.byName(json['theme'] as String),
    );
  }
}

class AlbumCreationDraft {
  const AlbumCreationDraft({
    required this.id,
    required this.updatedAt,
    required this.title,
    required this.cover,
    required this.pageCount,
    required this.step,
    required this.showPhotoFill,
    required this.hasSelectedMode,
    required this.sourceLabel,
    required this.usesPhysicalCanvas,
    required this.preserveTypography,
    this.pages,
    this.basePages,
    this.variants,
    this.canvasSizes = const {},
    this.baseCanvasSize,
    this.templateTitle,
    this.previewUrl,
    this.currentPage = 0,
    this.pendingPhotos = const [],
    this.selectedPhotoId,
    this.selectedSlot,
    this.editedCover,
    this.editedCoverCanvasSize,
    this.createdAlbumId,
    this.editorCheckpoint,
  });

  final String id;
  final DateTime updatedAt;
  final String title;
  final CoverSize cover;
  final int pageCount;
  final int step;
  final bool showPhotoFill;
  final bool hasSelectedMode;
  final String sourceLabel;
  final bool usesPhysicalCanvas;
  final bool preserveTypography;
  final List<List<LayerModel>>? pages;
  final List<List<LayerModel>>? basePages;
  final Map<String, List<List<LayerModel>>>? variants;
  final Map<String, Size> canvasSizes;
  final Size? baseCanvasSize;
  final String? templateTitle;
  final String? previewUrl;
  final int currentPage;
  final List<AssetEntity> pendingPhotos;
  final String? selectedPhotoId;
  final ({int page, String id})? selectedSlot;
  final List<LayerModel>? editedCover;
  final Size? editedCoverCanvasSize;
  final int? createdAlbumId;
  final AlbumCreationEditorCheckpoint? editorCheckpoint;

  AlbumCreationDraft withEditorCheckpoint(
    AlbumCreationEditorCheckpoint checkpoint, {
    required CoverSize cover,
  }) => AlbumCreationDraft(
    id: id,
    updatedAt: DateTime.now(),
    title: title,
    cover: cover,
    pageCount: checkpoint.pages.length - 1,
    step: step,
    showPhotoFill: showPhotoFill,
    hasSelectedMode: hasSelectedMode,
    sourceLabel: sourceLabel,
    usesPhysicalCanvas: usesPhysicalCanvas,
    preserveTypography: preserveTypography,
    pages: pages,
    basePages: basePages,
    variants: variants,
    canvasSizes: canvasSizes,
    baseCanvasSize: baseCanvasSize,
    templateTitle: templateTitle,
    previewUrl: previewUrl,
    currentPage: currentPage,
    pendingPhotos: pendingPhotos,
    selectedPhotoId: selectedPhotoId,
    selectedSlot: selectedSlot,
    editedCover: editedCover,
    editedCoverCanvasSize: editedCoverCanvasSize,
    createdAlbumId: createdAlbumId,
    editorCheckpoint: checkpoint,
  );

  Map<String, dynamic> toJson() => {
    'version': 1,
    'createdAlbumId': createdAlbumId,
    'editorCheckpoint': editorCheckpoint?.toJson(),
    'id': id,
    'updatedAt': updatedAt.toIso8601String(),
    'title': title,
    'cover': {
      'name': cover.name,
      'ratio': cover.ratio,
      'width': cover.realSize.width,
      'height': cover.realSize.height,
      'productId': cover.productId,
    },
    'pageCount': pageCount,
    'step': step,
    'showPhotoFill': showPhotoFill,
    'hasSelectedMode': hasSelectedMode,
    'sourceLabel': sourceLabel,
    'usesPhysicalCanvas': usesPhysicalCanvas,
    'preserveTypography': preserveTypography,
    'pages': _encodePages(pages),
    'basePages': _encodePages(basePages),
    'variants': variants?.map(
      (key, value) => MapEntry(key, _encodePages(value)),
    ),
    'canvasSizes': canvasSizes.map((key, size) => MapEntry(key, _size(size))),
    'baseCanvasSize': baseCanvasSize == null ? null : _size(baseCanvasSize!),
    'templateTitle': templateTitle,
    'previewUrl': previewUrl,
    'currentPage': currentPage,
    'pendingPhotos': pendingPhotos.map(_encodePhoto).toList(),
    'selectedPhotoId': selectedPhotoId,
    'selectedSlot': selectedSlot == null
        ? null
        : {'page': selectedSlot!.page, 'id': selectedSlot!.id},
    'editedCover': editedCover == null ? null : _encodePages([editedCover!]),
    'editedCoverCanvasSize': editedCoverCanvasSize == null
        ? null
        : _size(editedCoverCanvasSize!),
  };

  factory AlbumCreationDraft.fromJson(
    Map<String, dynamic> json, {
    AssetEntity Function(Map<String, dynamic>)? photoDecoder,
  }) {
    if (json['version'] != 1)
      throw const FormatException('Unknown draft version');
    final cover = Map<String, dynamic>.from(json['cover'] as Map);
    final ratio = (cover['ratio'] as num).toDouble();
    final width = (cover['width'] as num).toDouble();
    final height = (cover['height'] as num).toDouble();
    final createdAlbumId = json['createdAlbumId'] as int?;
    if (!ratio.isFinite ||
        ratio <= 0 ||
        !width.isFinite ||
        width <= 0 ||
        !height.isFinite ||
        height <= 0 ||
        (createdAlbumId != null && createdAlbumId <= 0)) {
      throw const FormatException('Invalid draft album dimensions or id');
    }
    final slot = json['selectedSlot'] as Map?;
    return AlbumCreationDraft(
      id: json['id'] as String,
      createdAlbumId: createdAlbumId,
      editorCheckpoint: json['editorCheckpoint'] == null
          ? null
          : AlbumCreationEditorCheckpoint.fromJson(
              Map<String, dynamic>.from(json['editorCheckpoint'] as Map),
              photoDecoder: photoDecoder,
            ),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      title: json['title'] as String,
      cover: CoverSize(
        name: cover['name'] as String,
        ratio: ratio,
        realSize: Size(width, height),
        productId: cover['productId'] as String?,
      ),
      pageCount: json['pageCount'] as int,
      step: (json['step'] as int).clamp(0, 1),
      showPhotoFill: json['showPhotoFill'] as bool,
      hasSelectedMode: json['hasSelectedMode'] as bool,
      sourceLabel: json['sourceLabel'] as String,
      usesPhysicalCanvas: json['usesPhysicalCanvas'] as bool,
      preserveTypography: json['preserveTypography'] as bool,
      pages: _decodePages(json['pages'], photoDecoder: photoDecoder),
      basePages: _decodePages(json['basePages'], photoDecoder: photoDecoder),
      variants: (json['variants'] as Map?)?.map(
        (key, value) => MapEntry(
          key as String, _decodePages(value, photoDecoder: photoDecoder)!,
        ),
      ),
      canvasSizes: (json['canvasSizes'] as Map).map(
        (key, value) => MapEntry(key as String, _decodeSize(value)),
      ),
      baseCanvasSize: json['baseCanvasSize'] == null
          ? null
          : _decodeSize(json['baseCanvasSize']),
      templateTitle: json['templateTitle'] as String?,
      previewUrl: json['previewUrl'] as String?,
      currentPage: json['currentPage'] as int,
      pendingPhotos: (json['pendingPhotos'] as List)
          .map((photo) => _decodePhoto(photo, photoDecoder))
          .toList(),
      selectedPhotoId: json['selectedPhotoId'] as String?,
      selectedSlot: slot == null
          ? null
          : (page: slot['page'] as int, id: slot['id'] as String),
      editedCover: _decodePages(
        json['editedCover'], photoDecoder: photoDecoder,
      )?.firstOrNull,
      editedCoverCanvasSize: json['editedCoverCanvasSize'] == null
          ? null
          : _decodeSize(json['editedCoverCanvasSize']),
    );
  }

  static Map<String, double> _size(Size size) => {
    'width': size.width,
    'height': size.height,
  };
  static Size _decodeSize(dynamic value) => Size(
    (value['width'] as num).toDouble(),
    (value['height'] as num).toDouble(),
  );
  static Map<String, dynamic> _encodePhoto(AssetEntity photo) => {
    'id': photo.id,
    'width': photo.width,
    'height': photo.height,
  };
  static AssetEntity _decodePhoto(
    dynamic json, [AssetEntity Function(Map<String, dynamic>)? decoder]
  ) => decoder?.call(Map<String, dynamic>.from(json as Map)) ?? AssetEntity(
    id: json['id'] as String,
    typeInt: 1,
    width: json['width'] as int,
    height: json['height'] as int,
  );

  // Unit canvas retains logical coordinates and uses the existing layer schema.
  static List<List<Map<String, dynamic>>>? _encodePages(
    List<List<LayerModel>>? pages,
  ) => pages
      ?.map(
        (page) => page
            .map(
              (layer) => {
                ...LayerExportMapper.toJson(
                  layer,
                  canvasSize: const Size(1, 1),
                ),
                if (layer.asset != null)
                  'localPhoto': _encodePhoto(layer.asset!),
                if (layer.frameBaseWidth != null)
                  'frameBaseWidth': layer.frameBaseWidth,
                if (layer.frameBaseHeight != null)
                  'frameBaseHeight': layer.frameBaseHeight,
                if (layer.frameBasePosition != null)
                  'frameBasePosition': {
                    'x': layer.frameBasePosition!.dx,
                    'y': layer.frameBasePosition!.dy,
                  },
              },
            )
            .toList(),
      )
      .toList();

  static List<List<LayerModel>>? _decodePages(
    dynamic pages, {
    AssetEntity Function(Map<String, dynamic>)? photoDecoder,
  }) => (pages as List?)
      ?.map(
        (page) => (page as List).map((value) {
          final json = Map<String, dynamic>.from(value as Map);
          final position = json['frameBasePosition'] as Map?;
          return LayerExportMapper.fromJson(
            json,
            canvasSize: const Size(1, 1),
          ).copyWith(
            asset: json['localPhoto'] == null
                ? null
                : _decodePhoto(json['localPhoto'], photoDecoder),
            frameBaseWidth: (json['frameBaseWidth'] as num?)?.toDouble(),
            frameBaseHeight: (json['frameBaseHeight'] as num?)?.toDouble(),
            frameBasePosition: position == null
                ? null
                : Offset(
                    (position['x'] as num).toDouble(),
                    (position['y'] as num).toDouble(),
                  ),
          );
        }).toList(),
      )
      .toList();
}
