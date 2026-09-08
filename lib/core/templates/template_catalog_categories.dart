/// Stable topic order shared by store and editor; styles remain search tags.
const templateTopicOrder = [
  '웨딩',
  '여행',
  '일상',
  '성장·육아',
  '가족·친구',
  '커플·기념일',
  '반려동물',
];

List<String> orderedTemplateTopics(Iterable<String> topics) {
  final available = topics.where((t) => t.isNotEmpty).toSet();
  final extra = available.difference(templateTopicOrder.toSet()).toList()
    ..sort();
  return [...templateTopicOrder.where(available.contains), ...extra];
}

const collectionStyleTags = <String, List<String>>{
  'lightbound': ['에디토리얼', '미니멀'],
  'journey': ['에디토리얼', '필름'],
  'wind-atlas': ['에디토리얼', '수채화', '보태니컬', '여행기록'],
  'our-prose': ['타이포그래피', '로맨틱', '매트프레임', '커플', '기념일선물'],
  'small-days': ['내추럴', '미니멀'],
  'our-vows': ['미니멀', '로맨틱'],
  'garden-promise': ['내추럴', '로맨틱'],
  'one-fine-film': ['필름', '에디토리얼'],
  'love-letters': ['스크랩북', '로맨틱'],
  'across-the-sea': ['컬러풀', '내추럴'],
  'city-collector': ['에디토리얼', '미니멀'],
  'slow-paths': ['내추럴', '미니멀'],
  'travel-postbox': ['스크랩북', '필름'],
  'seasonal-table': ['내추럴', '컬러풀'],
  'taste-archive': ['에디토리얼', '미니멀'],
  'better-together': ['스크랩북', '컬러풀'],
  'weekend-temperature': ['미니멀', '내추럴'],
  'your-first-year': ['미니멀', '성장앨범', '아기', '첫돌'],
  'little-footsteps': ['에디토리얼', '성장앨범', '아기'],
  'you-are-spring': ['로맨틱', '내추럴', '아기'],
  'growing-in-color': ['컬러풀', '스크랩북', '육아'],
  'first-birthday': ['로맨틱', '돌잔치', '첫돌', '생일'],
  'our-family-year': ['내추럴', '가족사진', '연감'],
  'around-our-table': ['내추럴', '가족사진', '요리'],
  'our-good-company': ['스크랩북', '컬러풀', '우정'],
  'across-generations': ['미니멀', '에디토리얼', '가족사진'],
  'a-picnic-together': ['컬러풀', '스크랩북', '소풍'],
  'dates-of-us': ['미니멀', '데이트', '커플'],
  'scenes-for-two': ['필름', '에디토리얼', '데이트'],
  'seasons-of-love': ['내추럴', '로맨틱', '커플'],
  'still-us': ['로맨틱', '미니멀', '기념일선물'],
  'collected-by-two': ['스크랩북', '데이트', '티켓'],
  'a-day-with-you': ['내추럴', '강아지', '반려견'],
  'shapes-of-naps': ['미니멀', '고양이', '반려묘'],
  'our-walking-promise': ['에디토리얼', '강아지', '산책'],
  'our-little-companion': ['스크랩북', '컬러풀', '고양이', '반려묘'],
  'the-kindest-face': ['미니멀', '에디토리얼', '강아지', '반려견'],
};
