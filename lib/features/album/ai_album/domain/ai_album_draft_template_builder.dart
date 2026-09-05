import 'package:flutter/material.dart';

import '../../domain/entities/layer.dart';
import 'ai_album_models.dart';

enum AiAlbumDraftEditorReadinessReason {
  ready,
  emptyRecommendedPhotos,
  pageCountMismatch,
  missingLocalImageAsset,
}

class AiAlbumDraftEditorReadiness {
  const AiAlbumDraftEditorReadiness(this.reason);

  final AiAlbumDraftEditorReadinessReason reason;

  bool get isReady => reason == AiAlbumDraftEditorReadinessReason.ready;
}

class AiAlbumDraftTemplateBuilder {
  const AiAlbumDraftTemplateBuilder();

  bool isEditorReady(AlbumRecommendationDraft draft) {
    return validateEditorReady(draft).isReady;
  }

  AiAlbumDraftEditorReadiness validateEditorReady(
    AlbumRecommendationDraft draft,
  ) {
    if (draft.recommendedPhotos.isEmpty) {
      return const AiAlbumDraftEditorReadiness(
        AiAlbumDraftEditorReadinessReason.emptyRecommendedPhotos,
      );
    }
    if (draft.pageCount < 1) {
      return const AiAlbumDraftEditorReadiness(
        AiAlbumDraftEditorReadinessReason.pageCountMismatch,
      );
    }
    final pages = build(draft);
    if (pages.length != draft.pageCount + 1) {
      return const AiAlbumDraftEditorReadiness(
        AiAlbumDraftEditorReadinessReason.pageCountMismatch,
      );
    }
    final imageLayers = pages.expand(
      (page) => page.where((layer) => layer.type == LayerType.image),
    );
    if (!imageLayers.any((layer) => layer.asset != null)) {
      return const AiAlbumDraftEditorReadiness(
        AiAlbumDraftEditorReadinessReason.missingLocalImageAsset,
      );
    }
    return const AiAlbumDraftEditorReadiness(
      AiAlbumDraftEditorReadinessReason.ready,
    );
  }

  List<List<LayerModel>> build(AlbumRecommendationDraft draft) {
    final pages = <List<LayerModel>>[_coverLayers(draft)];

    final photoById = {
      for (final photo in draft.recommendedPhotos) photo.assetId: photo,
    };

    final storyPhotoIds = <String>{};
    for (final section in draft.storySections) {
      final photos = section.photoAssetIds
          .where(photoById.containsKey)
          .map((id) => photoById[id]!)
          .take(4)
          .toList(growable: false);
      storyPhotoIds.addAll(photos.map((photo) => photo.assetId));
      pages.add(_storyPageLayers(section, photos));
    }

    final extraPhotos = draft.recommendedPhotos
        .where((photo) => !storyPhotoIds.contains(photo.assetId))
        .toList(growable: false);
    var extraPhotoCursor = 0;
    while (pages.length <= draft.pageCount) {
      final index = pages.length;
      final remaining = extraPhotos
          .skip(extraPhotoCursor)
          .take(2)
          .toList(growable: false);
      extraPhotoCursor += remaining.length;
      pages.add(_photoPageLayers(index, remaining));
    }

    return pages.take(draft.pageCount + 1).toList(growable: false);
  }

  List<LayerModel> _coverLayers(AlbumRecommendationDraft draft) {
    final coverPhoto = draft.recommendedPhotos.isEmpty
        ? null
        : draft.recommendedPhotos.first;
    return [
      if (coverPhoto != null)
        LayerModel(
          id: 'ai_cover_${coverPhoto.assetId}',
          type: LayerType.image,
          position: const Offset(60, 72),
          width: 380,
          height: 280,
          asset: coverPhoto.candidate.asset,
          imageTemplate: '4:3',
          imageBackground: 'mat',
        ),
      LayerModel(
        id: 'ai_cover_title',
        type: LayerType.text,
        position: const Offset(64, 382),
        width: 372,
        height: 86,
        text: draft.title,
        textAlign: TextAlign.left,
        textStyle: const TextStyle(
          fontSize: 30,
          height: 1.18,
          fontWeight: FontWeight.w700,
          color: Color(0xFF2A2520),
        ),
        textStyleType: TextStyleType.none,
      ),
      LayerModel(
        id: 'ai_cover_tone',
        type: LayerType.text,
        position: const Offset(66, 470),
        width: 360,
        height: 46,
        text: _themeLabel(draft.theme),
        textAlign: TextAlign.left,
        textStyle: const TextStyle(
          fontSize: 14,
          height: 1.25,
          fontWeight: FontWeight.w500,
          color: Color(0xFF6B6258),
        ),
        textStyleType: TextStyleType.none,
      ),
    ];
  }

  List<LayerModel> _storyPageLayers(
    StorySection section,
    List<RecommendedPhoto> photos,
  ) {
    return [
      LayerModel(
        id: 'ai_section_title_${section.title.hashCode}',
        type: LayerType.text,
        position: const Offset(38, 34),
        width: 250,
        height: 50,
        text: section.title,
        textAlign: TextAlign.left,
        textStyle: const TextStyle(
          fontSize: 24,
          height: 1.18,
          fontWeight: FontWeight.w700,
          color: Color(0xFF2A2520),
        ),
        textStyleType: TextStyleType.none,
      ),
      LayerModel(
        id: 'ai_section_desc_${section.title.hashCode}',
        type: LayerType.text,
        position: const Offset(40, 88),
        width: 258,
        height: 54,
        text: section.description,
        textAlign: TextAlign.left,
        textStyle: const TextStyle(
          fontSize: 12,
          height: 1.32,
          fontWeight: FontWeight.w500,
          color: Color(0xFF6B6258),
        ),
        textStyleType: TextStyleType.none,
      ),
      ..._imageGridLayers(photos, top: 160),
    ];
  }

  List<LayerModel> _photoPageLayers(int index, List<RecommendedPhoto> photos) {
    if (photos.isEmpty) return const [];
    return _imageGridLayers(photos, top: 52);
  }

  List<LayerModel> _imageGridLayers(
    List<RecommendedPhoto> photos, {
    required double top,
  }) {
    final slots = <Rect>[
      Rect.fromLTWH(40, top, 220, 150),
      Rect.fromLTWH(40, top + 170, 220, 150),
      Rect.fromLTWH(276, top, 184, 150),
      Rect.fromLTWH(276, top + 170, 184, 150),
    ];
    return photos
        .asMap()
        .entries
        .map((entry) {
          final slot = slots[entry.key.clamp(0, slots.length - 1)];
          final photo = entry.value;
          return LayerModel(
            id: 'ai_photo_${photo.assetId}',
            type: LayerType.image,
            position: Offset(slot.left, slot.top),
            width: slot.width,
            height: slot.height,
            asset: photo.candidate.asset,
            imageTemplate: '4:3',
            imageBackground: 'mat',
          );
        })
        .toList(growable: false);
  }

  String _themeLabel(AlbumTheme theme) {
    return switch (theme) {
      AlbumTheme.travel => '여행 기록',
      AlbumTheme.couple => '커플 기록',
      AlbumTheme.family => '가족 기록',
      AlbumTheme.baby => '성장 기록',
      AlbumTheme.birthday => '기념일 기록',
      AlbumTheme.friends => '친구 기록',
      AlbumTheme.daily => '일상 기록',
      AlbumTheme.custom => '나만의 기록',
    };
  }
}
