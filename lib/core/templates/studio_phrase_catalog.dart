import 'package:flutter/material.dart';

enum StudioLettering {
  literary('여백의 명조', 'Eulyoo', 26, FontWeight.w400, 1.55),
  editorial('선명한 제목', 'NotoSans', 25, FontWeight.w700, 1.35),
  note('작은 기록', 'NotoSans', 17, FontWeight.w400, 1.65),
  dedication('다정한 헌사', 'Eulyoo', 21, FontWeight.w400, 1.6);

  const StudioLettering(
    this.label,
    this.font,
    this.size,
    this.weight,
    this.leading,
  );
  final String label, font;
  final double size, leading;
  final FontWeight weight;
  TextStyle get style => TextStyle(
    fontFamily: font,
    fontSize: size,
    fontWeight: weight,
    height: leading,
    letterSpacing: 0,
    color: const Color(0xFF283D36),
  );
}

class StudioPhrase {
  const StudioPhrase(this.id, this.category, this.text, this.lettering);
  final String id, category, text;
  final StudioLettering lettering;
  TextAlign get alignment =>
      lettering == StudioLettering.note ? TextAlign.left : TextAlign.center;
}

// Authored Korean copy, stored as editable text rather than flattened artwork.
const studioPhrases = [
  StudioPhrase('vow-day', '웨딩', '우리가 서로의\n집이 된 날', StudioLettering.literary),
  StudioPhrase(
    'vow-always',
    '웨딩',
    '오늘의 약속,\n오래도록 우리',
    StudioLettering.editorial,
  ),
  StudioPhrase(
    'vow-scene',
    '웨딩',
    '나란히 선 두 사람과\n우리를 축복한 얼굴들.',
    StudioLettering.note,
  ),
  StudioPhrase(
    'vow-letter',
    '웨딩',
    '모든 계절을\n당신과 함께',
    StudioLettering.dedication,
  ),
  StudioPhrase(
    'travel-place',
    '여행',
    '낯선 곳에서\n발견한 우리',
    StudioLettering.literary,
  ),
  StudioPhrase('travel-map', '여행', '지도 밖의 하루', StudioLettering.editorial),
  StudioPhrase(
    'travel-note',
    '여행',
    '길을 조금 잃고,\n좋아하는 풍경을 하나 더 만났다.',
    StudioLettering.note,
  ),
  StudioPhrase(
    'travel-return',
    '여행',
    '다시 돌아가고 싶은\n그날의 빛',
    StudioLettering.dedication,
  ),
  StudioPhrase('daily-light', '일상', '별일 없는 날의\n반짝임', StudioLettering.literary),
  StudioPhrase('daily-piece', '일상', '오늘의 작은 수집', StudioLettering.editorial),
  StudioPhrase(
    'daily-note',
    '일상',
    '커피가 식는 동안에도\n좋아하는 순간은 남아 있었다.',
    StudioLettering.note,
  ),
  StudioPhrase(
    'daily-kept',
    '일상',
    '잊고 싶지 않은\n보통의 하루',
    StudioLettering.dedication,
  ),
  StudioPhrase(
    'baby-world',
    '성장·육아',
    '너를 만나\n넓어진 세상',
    StudioLettering.literary,
  ),
  StudioPhrase('baby-first', '성장·육아', '처음이 쌓이는 날들', StudioLettering.editorial),
  StudioPhrase(
    'baby-note',
    '성장·육아',
    '어제보다 조금 더 멀리.\n오늘의 작은 걸음을 기억해.',
    StudioLettering.note,
  ),
  StudioPhrase(
    'baby-letter',
    '성장·육아',
    '천천히 자라도 좋아\n우리는 늘 여기 있을게',
    StudioLettering.dedication,
  ),
  StudioPhrase(
    'family-table',
    '가족·친구',
    '같은 식탁에\n모인 마음',
    StudioLettering.literary,
  ),
  StudioPhrase('family-us', '가족·친구', '우리라서 좋은 날', StudioLettering.editorial),
  StudioPhrase(
    'family-note',
    '가족·친구',
    '웃음소리까지 담을 수 있다면\n이 사진을 고를 거야.',
    StudioLettering.note,
  ),
  StudioPhrase(
    'family-home',
    '가족·친구',
    '언제든 돌아갈 수 있는\n다정한 얼굴들',
    StudioLettering.dedication,
  ),
  StudioPhrase(
    'couple-season',
    '커플·기념일',
    '너와 보내는\n계절의 이름',
    StudioLettering.literary,
  ),
  StudioPhrase('couple-date', '커플·기념일', '우리의 다음 장면', StudioLettering.editorial),
  StudioPhrase(
    'couple-note',
    '커플·기념일',
    '같은 길도 너와 걸으면\n새로운 기억이 된다.',
    StudioLettering.note,
  ),
  StudioPhrase(
    'couple-letter',
    '커플·기념일',
    '오래 보아도\n또 보고 싶은 사람',
    StudioLettering.dedication,
  ),
  StudioPhrase(
    'pet-home',
    '반려동물',
    '작은 발로 들어와\n가득 채운 마음',
    StudioLettering.literary,
  ),
  StudioPhrase('pet-walk', '반려동물', '오늘도 함께, 산책', StudioLettering.editorial),
  StudioPhrase(
    'pet-note',
    '반려동물',
    '네가 좋아하는 길을 따라\n우리의 하루가 천천히 흐른다.',
    StudioLettering.note,
  ),
  StudioPhrase(
    'pet-letter',
    '반려동물',
    '말없이 건네는\n가장 다정한 사랑',
    StudioLettering.dedication,
  ),
];
