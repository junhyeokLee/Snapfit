import 'package:flutter/material.dart';

/// 페이지 템플릿 내 하나의 슬롯(이미지/텍스트) 정의
/// 좌표는 캔버스 대비 비율(0.0~1.0)로 정의
class PageTemplateSlot {
  final String type; // 'image' | 'text'
  /// 캔버스 대비 비율: left, top, width, height (0.0~1.0)
  final double left;
  final double top;
  final double width;
  final double height;
  final double rotation; // 도(degree)
  /// 이미지 슬롯: 프레임 스타일 (polaroid, polaroidClassic, tape, sticker, round 등)
  final String? imageBackground;
  /// 이미지 슬롯: 비율 키 ('1:1', '4:3', '3:4' 등)
  final String? imageTemplate;
  /// 텍스트 슬롯: 기본 문구
  final String? defaultText;
  /// 텍스트 슬롯: 배경 스타일 (tag, bubble, note, tape 등)
  final String? textBackground;

  const PageTemplateSlot({
    required this.type,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.imageBackground,
    this.imageTemplate,
    this.defaultText,
    this.textBackground,
  });
}

/// 스크랩북 스타일 페이지 템플릿
class PageTemplate {
  final String id;
  final String name;
  final String? thumbnailAsset;
  final List<PageTemplateSlot> slots;

  const PageTemplate({
    required this.id,
    required this.name,
    this.thumbnailAsset,
    required this.slots,
  });
}

/// 캔버스 비율 기준 템플릿 슬롯 목록 (세로형 3:4 비율 가정)
List<PageTemplate> get pageTemplates => [
      // 1. 여행/지도 – 큰 사진 1 + 텍스트 1
      const PageTemplate(
        id: 'travel_map',
        name: '여행 & 지도',
        slots: [
          PageTemplateSlot(
            type: 'image',
            left: 0.08,
            top: 0.12,
            width: 0.5,
            height: 0.45,
            imageBackground: 'polaroid',
            imageTemplate: '3:4',
            rotation: -4,
          ),
          PageTemplateSlot(
            type: 'text',
            left: 0.45,
            top: 0.35,
            width: 0.45,
            height: 0.2,
            defaultText: 'THE HIGHLIGHTS\nOF THE YEAR',
            textBackground: 'note',
            rotation: 2,
          ),
        ],
      ),
      // 2. 일몰/도시 – 넓은 이미지 + 폴라로이드 + 제목
      const PageTemplate(
        id: 'sunset_city',
        name: '일몰 & 도시',
        slots: [
          PageTemplateSlot(
            type: 'image',
            left: 0.05,
            top: 0.4,
            width: 0.9,
            height: 0.5,
            imageBackground: 'round',
            imageTemplate: '16:9',
            rotation: 0,
          ),
          PageTemplateSlot(
            type: 'text',
            left: 0.1,
            top: 0.08,
            width: 0.5,
            height: 0.12,
            defaultText: 'SUNSET',
            textBackground: 'tag',
          ),
          PageTemplateSlot(
            type: 'image',
            left: 0.55,
            top: 0.12,
            width: 0.35,
            height: 0.28,
            imageBackground: 'polaroidClassic',
            imageTemplate: '1:1',
            rotation: 6,
          ),
        ],
      ),
      // 3. 해변/바다 – 2개 이미지 + 문구
      const PageTemplate(
        id: 'beach',
        name: '해변 & 바다',
        slots: [
          PageTemplateSlot(
            type: 'image',
            left: 0.08,
            top: 0.1,
            width: 0.5,
            height: 0.5,
            imageBackground: 'polaroid',
            imageTemplate: '4:3',
            rotation: -3,
          ),
          PageTemplateSlot(
            type: 'image',
            left: 0.4,
            top: 0.35,
            width: 0.5,
            height: 0.45,
            imageBackground: 'tape',
            imageTemplate: '3:4',
            rotation: 4,
          ),
          PageTemplateSlot(
            type: 'text',
            left: 0.1,
            top: 0.78,
            width: 0.8,
            height: 0.12,
            defaultText: 'WE PROVE TO EACH OTHER',
            textBackground: 'bubble',
          ),
        ],
      ),
      // 4. 로드트립 – 단체 사진 + 텍스트 + 작은 사진 2
      const PageTemplate(
        id: 'road_trip',
        name: '로드트립',
        slots: [
          PageTemplateSlot(
            type: 'image',
            left: 0.08,
            top: 0.08,
            width: 0.55,
            height: 0.4,
            imageBackground: 'polaroid',
            imageTemplate: '4:3',
            rotation: -2,
          ),
          PageTemplateSlot(
            type: 'text',
            left: 0.5,
            top: 0.12,
            width: 0.42,
            height: 0.2,
            defaultText: 'THE FIRST TRIP\nTHE BEST DRIVER',
            textBackground: 'note',
            rotation: 2,
          ),
          PageTemplateSlot(
            type: 'image',
            left: 0.15,
            top: 0.52,
            width: 0.28,
            height: 0.28,
            imageBackground: 'polaroidWide',
            imageTemplate: '1:1',
            rotation: -5,
          ),
          PageTemplateSlot(
            type: 'image',
            left: 0.5,
            top: 0.55,
            width: 0.35,
            height: 0.32,
            imageBackground: 'polaroidClassic',
            imageTemplate: '1:1',
            rotation: 5,
          ),
        ],
      ),
      // 5. 역동/모험 – 사진 2 + 텍스트
      const PageTemplate(
        id: 'adventure',
        name: '모험 & 역동',
        slots: [
          PageTemplateSlot(
            type: 'image',
            left: 0.08,
            top: 0.1,
            width: 0.38,
            height: 0.4,
            imageBackground: 'polaroid',
            imageTemplate: '3:4',
            rotation: -6,
          ),
          PageTemplateSlot(
            type: 'image',
            left: 0.42,
            top: 0.15,
            width: 0.45,
            height: 0.42,
            imageBackground: 'polaroidClassic',
            imageTemplate: '4:3',
            rotation: 4,
          ),
          PageTemplateSlot(
            type: 'text',
            left: 0.1,
            top: 0.58,
            width: 0.8,
            height: 0.18,
            defaultText: 'CRAZY MOMENT',
            textBackground: 'tag',
          ),
        ],
      ),
      // 6. 팀/스포츠 – 큰 사진 + 긴 텍스트 + 그리드 슬롯
      const PageTemplate(
        id: 'team_sports',
        name: '팀 & 스포츠',
        slots: [
          PageTemplateSlot(
            type: 'image',
            left: 0.08,
            top: 0.06,
            width: 0.55,
            height: 0.38,
            imageBackground: 'polaroid',
            imageTemplate: '4:3',
            rotation: -2,
          ),
          PageTemplateSlot(
            type: 'text',
            left: 0.08,
            top: 0.46,
            width: 0.84,
            height: 0.22,
            defaultText: 'TEAM STORY\nTHAT MOMENT WE SHARED',
            textBackground: 'note',
          ),
          PageTemplateSlot(
            type: 'image',
            left: 0.15,
            top: 0.72,
            width: 0.2,
            height: 0.2,
            imageBackground: 'round',
            imageTemplate: '1:1',
          ),
          PageTemplateSlot(
            type: 'image',
            left: 0.42,
            top: 0.72,
            width: 0.2,
            height: 0.2,
            imageBackground: 'round',
            imageTemplate: '1:1',
          ),
          PageTemplateSlot(
            type: 'image',
            left: 0.69,
            top: 0.72,
            width: 0.2,
            height: 0.2,
            imageBackground: 'round',
            imageTemplate: '1:1',
          ),
        ],
      ),
      // 7. 결혼/공식 – 여러 인물 슬롯 + 레이블
      const PageTemplate(
        id: 'wedding',
        name: '결혼 & 공식',
        slots: [
          PageTemplateSlot(
            type: 'text',
            left: 0.1,
            top: 0.05,
            width: 0.6,
            height: 0.1,
            defaultText: 'MY COUSIN WEDDING',
            textBackground: 'tag',
          ),
          PageTemplateSlot(
            type: 'image',
            left: 0.08,
            top: 0.2,
            width: 0.38,
            height: 0.35,
            imageBackground: 'polaroidClassic',
            imageTemplate: '3:4',
            rotation: -3,
          ),
          PageTemplateSlot(
            type: 'image',
            left: 0.5,
            top: 0.18,
            width: 0.4,
            height: 0.36,
            imageBackground: 'polaroid',
            imageTemplate: '3:4',
            rotation: 3,
          ),
          PageTemplateSlot(
            type: 'image',
            left: 0.2,
            top: 0.58,
            width: 0.55,
            height: 0.32,
            imageBackground: 'polaroidWide',
            imageTemplate: '16:9',
            rotation: -1,
          ),
        ],
      ),
      // 8. 친구 모임 – 그룹 사진 + 텍스트
      const PageTemplate(
        id: 'friends',
        name: '친구 모임',
        slots: [
          PageTemplateSlot(
            type: 'image',
            left: 0.1,
            top: 0.08,
            width: 0.8,
            height: 0.5,
            imageBackground: 'polaroid',
            imageTemplate: '4:3',
            rotation: 0,
          ),
          PageTemplateSlot(
            type: 'text',
            left: 0.15,
            top: 0.62,
            width: 0.7,
            height: 0.2,
            defaultText: 'FRIENDS FOREVER',
            textBackground: 'bubble',
          ),
        ],
      ),
      // 9. 가족 – 2장 사진 + 세로 텍스트
      const PageTemplate(
        id: 'family',
        name: '가족',
        slots: [
          PageTemplateSlot(
            type: 'image',
            left: 0.08,
            top: 0.1,
            width: 0.4,
            height: 0.55,
            imageBackground: 'polaroidClassic',
            imageTemplate: '3:4',
            rotation: -4,
          ),
          PageTemplateSlot(
            type: 'image',
            left: 0.48,
            top: 0.15,
            width: 0.42,
            height: 0.5,
            imageBackground: 'polaroid',
            imageTemplate: '3:4',
            rotation: 4,
          ),
          PageTemplateSlot(
            type: 'text',
            left: 0.15,
            top: 0.68,
            width: 0.7,
            height: 0.15,
            defaultText: 'THE MOMENT WE HUNG OUT THE FAMILY IS ON',
            textBackground: 'note',
          ),
        ],
      ),
      // 10. 빈 캔버스 (슬롯 없음 – 자유 배치)
      const PageTemplate(
        id: 'blank',
        name: '빈 페이지',
        slots: [],
      ),
    ];

PageTemplate? pageTemplateById(String id) {
  try {
    return pageTemplates.firstWhere((t) => t.id == id);
  } catch (_) {
    return null;
  }
}
