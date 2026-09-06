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
    if (draft.recommendedPhotos.isEmpty && draft.templateSlots.isEmpty) {
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
    if (draft.templateSlots.isEmpty &&
        !imageLayers.any((layer) => layer.asset != null)) {
      return const AiAlbumDraftEditorReadiness(
        AiAlbumDraftEditorReadinessReason.missingLocalImageAsset,
      );
    }
    return const AiAlbumDraftEditorReadiness(
      AiAlbumDraftEditorReadinessReason.ready,
    );
  }

  List<List<LayerModel>> build(AlbumRecommendationDraft draft) {
    if (draft.templateSlots.isNotEmpty) return _templateSlotPages(draft);

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
      pages.add(_storyPageLayers(draft.theme, section, photos));
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
      pages.add(_photoPageLayers(draft.theme, index, remaining));
    }

    return pages.take(draft.pageCount + 1).toList(growable: false);
  }

  List<List<LayerModel>> _templateSlotPages(AlbumRecommendationDraft draft) {
    final pages = List<List<LayerModel>>.generate(
      draft.pageCount + 1,
      (index) => <LayerModel>[],
      growable: false,
    );
    final photoById = {
      for (final photo in draft.recommendedPhotos) photo.assetId: photo,
    };
    for (var index = 0; index < pages.length; index += 1) {
      pages[index].addAll(_templateTextLayers(draft, index));
    }
    for (final slot in draft.templateSlots) {
      if (slot.pageIndex < 0 || slot.pageIndex >= pages.length) continue;
      final pageSlots = draft.templateSlots
          .where((item) => item.pageIndex == slot.pageIndex)
          .toList(growable: false);
      final slotIndex = pageSlots.indexWhere(
        (item) => item.slotId == slot.slotId,
      );
      final rect = _slotRectFor(draft.theme, slot, slotIndex.clamp(0, 3));
      final assignedPhoto = slot.assetId == null
          ? null
          : photoById[slot.assetId];
      pages[slot.pageIndex].add(
        LayerModel(
          id: 'ai_slot_${slot.slotId}',
          type: LayerType.image,
          position: Offset(rect.left, rect.top),
          width: rect.width,
          height: rect.height,
          asset: assignedPhoto?.candidate.asset,
          imageTemplate: _slotImageTemplateFor(slot),
          imageBackground: _imageBackgroundFor(draft.theme),
        ),
      );
      pages[slot.pageIndex].add(
        LayerModel(
          id: 'ai_slot_hint_${slot.slotId}',
          type: LayerType.text,
          position: Offset(rect.left, rect.bottom + 10),
          width: rect.width,
          height: 42,
          text: slot.hint,
          textAlign: TextAlign.left,
          textStyle: const TextStyle(
            fontSize: 11,
            height: 1.25,
            fontWeight: FontWeight.w500,
            color: Color(0xFF7A7066),
          ),
          textStyleType: TextStyleType.none,
        ),
      );
    }
    return pages;
  }

  List<LayerModel> _templateTextLayers(
    AlbumRecommendationDraft draft,
    int pageIndex,
  ) {
    if (pageIndex == 0) {
      return [
        LayerModel(
          id: 'ai_template_cover_title',
          type: LayerType.text,
          position: const Offset(46, 390),
          width: 408,
          height: 84,
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
          id: 'ai_template_cover_tone',
          type: LayerType.text,
          position: const Offset(48, 482),
          width: 392,
          height: 42,
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
    final section = draft.storySections.length >= pageIndex
        ? draft.storySections[pageIndex - 1]
        : null;
    return [
      LayerModel(
        id: 'ai_template_section_title_$pageIndex',
        type: LayerType.text,
        position: const Offset(38, 34),
        width: 250,
        height: 48,
        text: section?.title ?? '사진을 채워주세요',
        textAlign: TextAlign.left,
        textStyle: const TextStyle(
          fontSize: 23,
          height: 1.18,
          fontWeight: FontWeight.w700,
          color: Color(0xFF2A2520),
        ),
        textStyleType: TextStyleType.none,
      ),
      LayerModel(
        id: 'ai_template_section_desc_$pageIndex',
        type: LayerType.text,
        position: const Offset(40, 86),
        width: 260,
        height: 52,
        text: section?.description ?? 'AI가 잡아둔 사진칸에 직접 사진을 넣어요.',
        textAlign: TextAlign.left,
        textStyle: const TextStyle(
          fontSize: 12,
          height: 1.32,
          fontWeight: FontWeight.w500,
          color: Color(0xFF6B6258),
        ),
        textStyleType: TextStyleType.none,
      ),
    ];
  }

  Rect _slotRectFor(AlbumTheme theme, AiTemplateSlot slot, int index) {
    if (slot.pageIndex == 0) {
      final layout = _coverLayoutFor(theme);
      return layout.photoPosition & layout.photoSize;
    }
    final slots = _storySlotsFor(theme, 160);
    return slots[index.clamp(0, slots.length - 1)];
  }

  String _slotImageTemplateFor(AiTemplateSlot slot) {
    return switch (slot.role) {
      'portrait' => '3:4',
      'square' => '1:1',
      'cover' => '4:3',
      _ => '4:3',
    };
  }

  List<LayerModel> _coverLayers(AlbumRecommendationDraft draft) {
    final coverPhoto = draft.recommendedPhotos.isEmpty
        ? null
        : draft.recommendedPhotos.first;
    final layout = _coverLayoutFor(draft.theme);
    return [
      if (coverPhoto != null)
        LayerModel(
          id: 'ai_cover_${coverPhoto.assetId}',
          type: LayerType.image,
          position: layout.photoPosition,
          width: layout.photoSize.width,
          height: layout.photoSize.height,
          asset: coverPhoto.candidate.asset,
          imageTemplate: layout.imageTemplate,
          imageBackground: layout.imageBackground,
        ),
      LayerModel(
        id: 'ai_cover_title',
        type: LayerType.text,
        position: layout.titlePosition,
        width: layout.titleSize.width,
        height: layout.titleSize.height,
        text: draft.title,
        textAlign: layout.textAlign,
        textStyle: TextStyle(
          fontSize: layout.titleFontSize,
          height: 1.18,
          fontWeight: FontWeight.w700,
          color: layout.textColor,
        ),
        textStyleType: TextStyleType.none,
      ),
      LayerModel(
        id: 'ai_cover_tone',
        type: LayerType.text,
        position: layout.tonePosition,
        width: layout.toneSize.width,
        height: layout.toneSize.height,
        text: _themeLabel(draft.theme),
        textAlign: layout.textAlign,
        textStyle: TextStyle(
          fontSize: 14,
          height: 1.25,
          fontWeight: FontWeight.w500,
          color: layout.mutedTextColor,
        ),
        textStyleType: TextStyleType.none,
      ),
    ];
  }

  List<LayerModel> _storyPageLayers(
    AlbumTheme theme,
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
      ..._imageGridLayers(theme, photos, top: 160),
    ];
  }

  List<LayerModel> _photoPageLayers(
    AlbumTheme theme,
    int index,
    List<RecommendedPhoto> photos,
  ) {
    if (photos.isEmpty) return const [];
    return _imageGridLayers(theme, photos, top: 52);
  }

  List<LayerModel> _imageGridLayers(
    AlbumTheme theme,
    List<RecommendedPhoto> photos, {
    required double top,
  }) {
    final slots = _storySlotsFor(theme, top);
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
            imageTemplate: _imageTemplateFor(
              theme,
              photo.candidate.orientation,
            ),
            imageBackground: _imageBackgroundFor(theme),
          );
        })
        .toList(growable: false);
  }

  _CoverLayout _coverLayoutFor(AlbumTheme theme) {
    return switch (theme) {
      AlbumTheme.travel => const _CoverLayout(
        photoPosition: Offset(42, 62),
        photoSize: Size(416, 292),
        titlePosition: Offset(48, 392),
        titleSize: Size(404, 88),
        tonePosition: Offset(50, 490),
        toneSize: Size(390, 44),
        imageTemplate: '4:3',
        imageBackground: 'mat',
        textAlign: TextAlign.left,
        titleFontSize: 30,
      ),
      AlbumTheme.family => const _CoverLayout(
        photoPosition: Offset(58, 54),
        photoSize: Size(384, 330),
        titlePosition: Offset(58, 410),
        titleSize: Size(384, 82),
        tonePosition: Offset(60, 500),
        toneSize: Size(370, 44),
        imageTemplate: '1:1',
        imageBackground: 'soft-shadow',
        textAlign: TextAlign.center,
        titleFontSize: 28,
      ),
      AlbumTheme.baby => const _CoverLayout(
        photoPosition: Offset(86, 58),
        photoSize: Size(328, 328),
        titlePosition: Offset(52, 414),
        titleSize: Size(396, 92),
        tonePosition: Offset(70, 510),
        toneSize: Size(360, 44),
        imageTemplate: 'circle-soft',
        imageBackground: 'pastel',
        textAlign: TextAlign.center,
        titleFontSize: 27,
        textColor: Color(0xFF3E302C),
        mutedTextColor: Color(0xFF7B6661),
      ),
      AlbumTheme.couple => const _CoverLayout(
        photoPosition: Offset(66, 70),
        photoSize: Size(368, 300),
        titlePosition: Offset(56, 402),
        titleSize: Size(388, 86),
        tonePosition: Offset(58, 492),
        toneSize: Size(380, 44),
        imageTemplate: 'polaroid',
        imageBackground: 'warm-paper',
        textAlign: TextAlign.center,
        titleFontSize: 29,
      ),
      _ => const _CoverLayout(
        photoPosition: Offset(60, 72),
        photoSize: Size(380, 280),
        titlePosition: Offset(64, 382),
        titleSize: Size(372, 86),
        tonePosition: Offset(66, 470),
        toneSize: Size(360, 46),
        imageTemplate: '4:3',
        imageBackground: 'mat',
        textAlign: TextAlign.left,
        titleFontSize: 30,
      ),
    };
  }

  List<Rect> _storySlotsFor(AlbumTheme theme, double top) {
    return switch (theme) {
      AlbumTheme.travel => [
        Rect.fromLTWH(30, top, 260, 164),
        Rect.fromLTWH(306, top + 18, 156, 132),
        Rect.fromLTWH(54, top + 190, 172, 150),
        Rect.fromLTWH(242, top + 188, 220, 152),
      ],
      AlbumTheme.family => [
        Rect.fromLTWH(48, top, 180, 180),
        Rect.fromLTWH(248, top, 180, 180),
        Rect.fromLTWH(48, top + 198, 180, 150),
        Rect.fromLTWH(248, top + 198, 180, 150),
      ],
      AlbumTheme.baby => [
        Rect.fromLTWH(78, top, 150, 150),
        Rect.fromLTWH(250, top + 24, 150, 150),
        Rect.fromLTWH(62, top + 198, 172, 132),
        Rect.fromLTWH(252, top + 196, 172, 132),
      ],
      _ => [
        Rect.fromLTWH(40, top, 220, 150),
        Rect.fromLTWH(40, top + 170, 220, 150),
        Rect.fromLTWH(276, top, 184, 150),
        Rect.fromLTWH(276, top + 170, 184, 150),
      ],
    };
  }

  String _imageTemplateFor(AlbumTheme theme, PhotoOrientation orientation) {
    return switch (theme) {
      AlbumTheme.family => '1:1',
      AlbumTheme.baby =>
        orientation == PhotoOrientation.portrait ? '3:4' : 'soft-rounded',
      AlbumTheme.couple => 'polaroid',
      _ => '4:3',
    };
  }

  String _imageBackgroundFor(AlbumTheme theme) {
    return switch (theme) {
      AlbumTheme.family => 'soft-shadow',
      AlbumTheme.baby => 'pastel',
      AlbumTheme.couple => 'warm-paper',
      _ => 'mat',
    };
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

class _CoverLayout {
  const _CoverLayout({
    required this.photoPosition,
    required this.photoSize,
    required this.titlePosition,
    required this.titleSize,
    required this.tonePosition,
    required this.toneSize,
    required this.imageTemplate,
    required this.imageBackground,
    required this.textAlign,
    required this.titleFontSize,
    this.textColor = const Color(0xFF2A2520),
    this.mutedTextColor = const Color(0xFF6B6258),
  });

  final Offset photoPosition;
  final Size photoSize;
  final Offset titlePosition;
  final Size titleSize;
  final Offset tonePosition;
  final Size toneSize;
  final String imageTemplate;
  final String imageBackground;
  final TextAlign textAlign;
  final double titleFontSize;
  final Color textColor;
  final Color mutedTextColor;
}
