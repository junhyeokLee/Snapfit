/// Explicit editorial selections, independent of price, popularity and badges.
/// These books have native cover/interior proofs in all three sale ratios:
/// premium-four-per-topic-20261103, sensory-editions-2026-11-03, store-quality-2026-11-02,
/// curation-reading-2026-11-03,
/// diversity-expansion-2026-11-03,
/// template-lettering-refresh-2026-10-25, activity-story-editions-2026-10-25
/// and story-editions-2026-10-24.
/// Keep this metadata-only: browsing must not generate a book to rank it.
const storeTemplateEditorialProductKeys = <String>[
  // Six new books sit beside six established, reviewed editions. Keeping
  // earlier identities avoids making the entire live selection depend on
  // one catalog release. Missing identities still resolve only when available.
  'template:story-coffee-notebook',
  'template:story-premium-desert-night',
  'template:story-sport-pace-study',
  'template:story-premium-rabbit-little-traces',
  'template:dates-of-us',
  'template:story-club-run-together',
  'template:story-premium-hanbok-vows',
  'template:story-premium-thesis-new-sentence',
  'template:story-premium-first-words',
  'template:our-good-company',
  'template:story-premium-watercolor-drying-time',
  'template:taste-archive',
];

/// Review membership is not a quality score or a BEST/NEW claim. Add a book
/// only after its current cover, interiors and detail assets pass review.
const reviewedStoreTemplateIds = <int>{
  -9801, // 한복의 약속
  -9802, // 같은 주소가 된 날
  -9803, // 우리가 차린 예식
  -9804, // 다시 쓰는 서약
  -9805, // 설국의 느린 지도
  -9806, // 온천마을의 여백
  -9807, // 사막에서 보낸 밤
  -9808, // 골목책방을 따라
  -9809, // 매일의 도시락
  -9810, // 비 오는 출근길
  -9811, // 우리 집 작은 수선실
  -9812, // 토요일의 장보기
  -9813, // 너의 첫 소풍
  -9814, // 처음 만난 겨울
  -9815, // 작은 말이 자라는 집
  -9816, // 혼자서 해낸 아침
  -9817, // 오래된 집의 주말
  -9818, // 우리 집 작은 영화제
  -9819, // 친구의 생일을 엮다
  -9820, // 함께 적는 동네 지도
  -9821, // 두 사람의 긴 편지
  -9822, // 스무 번의 계절
  -9823, // 함께 고친 작은 방
  -9824, // 다정한 식탁 실험실
  -9825, // 너의 첫 집
  -9826, // 느린 발걸음을 맞추며
  -9827, // 토끼가 지나간 자리
  -9828, // 함께 떠난 첫 바다
  -9829, // 결승선 너머의 나
  -9830, // 호흡을 펴는 아침
  -9831, // 나의 힘을 쌓는 기록
  -9832, // 파도에 서는 순간
  -9833, // 논문 끝의 첫 문장
  -9834, // 낯선 도시의 새 주소
  -9835, // 새로운 교복의 아침
  -9836, // 한 장의 자격 긴 시간
  -9837, // 서로의 화음으로
  -9838, // 한 수씩 가까워지는 밤
  -9839, // 같이 차리는 저녁
  -9840, // 작은 고장을 함께 고치다
  -9841, // 물감이 마르는 동안
  -9842, // 나무의 결을 따라
  -9843, // 바늘 끝에 핀 무늬
  -9844, // 한 면씩 듣는 오후
  -9772, // 흙이 기억하는 손 — pottery process and four distinct record cards.
  -9773, // 잎새를 돌보는 날들 — botanical observations and care records.
  -9774, // 빛을 현상하는 주말 — film contact rails and roll records.
  -9775, // 오븐 앞의 작은 기쁨 — recipes, process and tasting notes.
  -9776, // 한 코씩 쌓이는 계절 — stitches, progress and yarn records.
  -9777, // 다시 듣고 싶은 연습 — practice, listening and rehearsal pages.
  -9778, // 종이 위의 수집 — independent collage and collecting stock.
  -9779, // 전시를 걷는 시선 — gallery observations and registration stock.
  -9780, // 천천히 피우는 주말 — campsite, weather and packing records.
  -9781, // 작은 졸업, 큰 박수 — celebration, artwork and intact group scenes.
  -9782, // 처음 여는 우리 집 — moving, rooms and first-day records.
  -9783, // 나의 두 번째 출발 — experience, learning and future plans.
  -9784, // 퇴근 다음의 계절 — gratitude, recollection and the next season.
  -9785, // 처음 내 이름을 걸다 — exhibition process, labels and visitors.
  -9771, // 책장 사이의 오후 — full native book and reading cards at three ratios.
  -9761, // 커피가 식기 전에 — free sensory edition.
  -9762, // 밤의 도시 수집 — night photography and collecting pages.
  -9751, // 나의 페이스 노트 — personal training and recovery records.
  -9463, // 너랑 걷는 오후 — photo-aware expressive lettering.
  -9451, // 너와 나의 날짜들 — revised cover and editable opening spread.
  -9741, // 같은 속도의 우리 — whole-group photos and member records.
  -9601, // 오전의 서약 — ceremony, portraits and correspondence.
  -9711, // 우리의 마지막 교실 — graduation portraits and an annual.
  -9632, // 숲으로 간 꼬마 — discoveries and child-led observation.
  -9443, // 우리의 좋은 사이 — revised cover and friendship spread.
  -9422, // 취향 보관함 — revised cover and collected-object spread.
  -9614, // 바다 곁의 주소 — scenery, stay records and collected materials.
  -9302, // 여행의 결 — reviewed lettering refresh.
  -9303, // 작은 날의 기록 — reviewed lettering refresh.
  -9412, // 도시의 수집가 — reviewed lettering refresh.
  -9452, // 둘만의 장면 — reviewed lettering refresh.
};
