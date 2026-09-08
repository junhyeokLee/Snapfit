part of 'authored_collections.dart';

/// Independently authored free collections; identifiers remain stable.
enum EditorialVolume {
  journey('journey', '여행의 결', '여행'),
  smallDays('small-days', '작은 날의 기록', '일상');

  const EditorialVolume(this.route, this.title, this.category);
  final String route, title, category;
  String get id => '${route.replaceAll('-', '_')}_editorial_draft';
  int get innerPageCount => 24;
  List<String> get chapters => switch (this) {
    journey => const [
      '출발의 문장',
      '창밖의 시간',
      '낯선 골목',
      '바다의 여백',
      '오래 앉은 자리',
      '시장에서 고른 것',
      '주머니 속 조각',
      '길 위의 색',
      '다시 걷고 싶은 길',
      '보내지 않은 엽서',
      '돌아오는 창가',
      '여행 다음의 날',
    ],
    smallDays => const [
      '오늘의 기분',
      '아침을 차리는 일',
      '책상 위의 취향',
      '잠깐의 쉼',
      '꽃을 사는 산책',
      '함께 먹는 오후',
      '우리의 얼굴',
      '계절의 맛',
      '다정한 습관',
      '한 달의 작은 기록',
      '좋아하는 것들',
      '내일도 이만큼',
    ],
  };
  EditorialCopy get defaultCopy => switch (this) {
    journey => const EditorialCopy(
      place: '지중해의 작은 마을',
      period: '2026. 06. 12 ~ 18',
      byline: '수연과 지후',
      note:
          '돌아와서도 한동안 바다 냄새가 나는 것 같았다.\n\n'
          '계획에 없던 골목, 오래 앉아 있던 카페, 이름을 묻지 못한 꽃. '
          '사진 밖의 작은 순간까지 오래 기억하고 싶다.\n\n'
          '다음 여행에서도 조금 느리게 걸어야지.',
    ),
    smallDays => const EditorialCopy(
      place: '봄에서 여름으로',
      period: '2026. 04 ~ 06',
      byline: '수연',
      note:
          '별일 없었다고 생각한 날에도 남겨 두고 싶은 장면은 있었다.\n\n'
          '아침에 고른 접시, 돌아오는 길의 꽃, 친구와 나눠 먹은 과일. '
          '작은 것들을 적다 보니 하루가 조금 더 선명해졌다.\n\n'
          '내일도 한 가지쯤은 마음에 담아 두기로.',
    ),
  };
  Map<String, dynamic> document(
    CollectionAspect aspect, {
    EditorialCopy? copy,
  }) => switch (this) {
    journey => _journeyDraft(aspect, copy ?? defaultCopy),
    smallDays => _smallDaysDraft(aspect, copy ?? defaultCopy),
  };
}

class EditorialCopy {
  const EditorialCopy({
    required this.place,
    required this.period,
    required this.byline,
    required this.note,
  });
  final String place, period, byline, note;
}

// Only assembly and folios are shared; each volume authors its own compositions.
class _EditorialBook {
  _EditorialBook(this.volume, this.aspect, this.paper, this.ink);
  final EditorialVolume volume;
  final CollectionAspect aspect;
  final String paper, ink;
  final pages = <Map<String, dynamic>>[];
  _Sheet sheet([String? background, String? textInk]) => _Sheet(
    volume.id,
    aspect,
    pages.length,
    background ?? paper,
    ink: textInk ?? ink,
    display: 'NotoSans',
    displayWeight: 600,
  );
  void add(_Sheet p, String name, String role) {
    if (p.index > 0) {
      p.text(
        'folio',
        p.index.toString().padLeft(2, '0'),
        p.index.isOdd ? .07 : .83,
        .942,
        .10,
        .028,
        size: .018,
        color: p.ink,
        align: p.index.isOdd ? 'left' : 'right',
      );
    }
    pages.add({
      ...p.json,
      'name': name,
      'role': role,
      'spreadIndex': p.index == 0 ? 0 : (p.index + 1) ~/ 2,
      'side': p.index == 0 ? 'cover' : (p.index.isOdd ? 'left' : 'right'),
    });
  }

  Map<String, dynamic> get document => {
    'id': '${volume.id}_${aspect.name}',
    'title': volume.title,
    'category': volume.category,
    'source': 'snapfit-authored-free',
    'aiGenerated': false,
    'publicationStatus': 'bundled',
    'accessTier': 'free',
    'catalogPublishable': false,
    'version': 1,
    'innerPageCount': pages.length - 1,
    'targetInnerPageCount': 24,
    'aspect': aspect.name,
    'designWidth': aspect.canvas.width,
    'designHeight': aspect.canvas.height,
    'layoutSafety': {'insetFraction': .06, 'printVerified': false},
    'chapters': [
      for (var i = 0; i < volume.chapters.length; i++)
        {'title': volume.chapters[i], 'from': i * 2 + 1, 'to': i * 2 + 2},
    ],
    'cover': pages.first,
    'pages': pages.skip(1).toList(),
  };
}
