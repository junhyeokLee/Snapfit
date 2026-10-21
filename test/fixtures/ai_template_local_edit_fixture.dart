import 'package:flutter/material.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_template_art_direction.dart';

AiTemplateDesign localEditDesign({Color background = Colors.white}) =>
    AiTemplateDesign(
      concept: '함께한 오후',
      rationale: '부분 수정 검사 전용 원본',
      aspect: AiTemplateAspect.square,
      version: 2,
      artDirection: const AiTemplateArtDirection(
        concept: '함께한 오후',
        rationale: '부분 수정 검사 전용 원본',
        requirements: ['배치 유지'],
        palette: ['#FFFFFF', '#203D35', '#D4DEDC'],
        typography: {
          'body': AiTemplateTypeStyle(
            fontFamily: 'NotoSans',
            weight: 400,
            fontSize: 16,
            lineHeight: 1.3,
          ),
        },
        pages: [
          AiTemplatePlannedPage('cover', '표지', 1),
          AiTemplatePlannedPage('story', '내지', 1),
        ],
      ),
      pages: [
        for (var page = 0; page < 2; page++)
          AiTemplateDesignPage(
            background: background,
            purpose: page == 0 ? '표지' : '내지',
            elements: [
              AiTemplateDesignElement(
                id: 'photo-$page',
                kind: 'photo',
                rect: const Rect.fromLTWH(.08, .08, .84, .5),
                color: const Color(0xFFD4DEDC),
              ),
              AiTemplateDesignElement(
                id: 'text-$page',
                kind: 'text',
                rect: const Rect.fromLTWH(.08, .72, .84, .13),
                color: const Color(0xFF203D35),
                text: page == 0 ? '함께한 오후' : '다시 만날 장면',
                fontFamily: 'NotoSans',
                fontSize: 16,
                weight: 400,
                lineHeight: 1.3,
                typographyRole: 'body',
              ),
            ],
          ),
      ],
    );

AlbumRecommendationDraft localEditDraft(AiTemplateDesign design) =>
    AlbumRecommendationDraft(
      draftId: 'existing-active-draft',
      design: design,
      theme: AlbumTheme.custom,
      title: design.concept,
      pageCount: design.pages.length - 1,
      templateTone: '원래 톤',
      recommendedPhotos: const [],
      excludedPhotos: const [],
      storySections: const [],
      summary: design.rationale,
      templateSlots: const [
        AiTemplateSlot(
          slotId: 'photo-0',
          pageIndex: 0,
          role: 'cover',
          hint: '대표 사진',
        ),
      ],
      curationNotes: const ['원본 유지'],
    );
