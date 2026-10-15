# Album Creation Flow

## 2026-10-15 실제 책 중심 제작 워크스페이스

- 직접 만들기·AI 템플릿·등록 템플릿 선택은 기존 생성 경로를 유지하며, 이후
  실제 책을 보고 규격·사진·표지를 작업하는 공통 제작 공간으로 연결한다.
- `CreationWorkspace`는 안전 너비/높이에 따라 책과 입력을 가로로 나누거나
  세로로 이어 둔다. 페이지/입력 위젯을 유지해 회전 후 선택·초안·포커스가
  보존되며 키보드 위 작업 버튼과 활성 입력을 확보한다.
- 설정 미리보기는 표지와 전체 내지를 사용한다. 가로는 좁은 제작 패널 안에서도
  좌우 펼침면을 보존하고 세로는 한 쪽과 확대를 제공한다. 책 크기 선택은 기존
  실제 인쇄 규격과 문서 변형 정책을 유지하며 화면에 맞추려고 캔버스를 바꾸지 않는다.
- AI 요청·포인트 확인·생성 대기는 요청 규격의 빈 책이다. 실제 응답 후에만
  결과 문서를 표시하며 생성/과금/승인 규칙을 바꾸지 않는다.
- 사진 채우기는 같은 종이 무대에서 사진 자리·실제 파일·프레임/구도·히스토리를
  보존한다. 작은 가로는 안전 너비 기준으로 펼침면과 쪽 목록을 나누며 낮은
  목록 항목도 선택 테두리·쪽 번호가 넘치지 않는 높이를 사용한다.
- 전체 확인의 가로 표지와 페이지 목록을 분리하고 빈 사진 필터는 목록 쪽에 둔다.
  수정 쪽/편집 시작 반환과 임시 저장→표지 생성→내지 에디터 저장 계약은 그대로다.
  홈·리더·승인된 에디터와 완성 화면은 이번 개편의 변경 대상이 아니다.
- 같은 `output/all-screens-qa/index.html`에 제작 여정 15개 상태를 추가했다.
  실제 등록 템플릿·응답 fixture와 가짜 서비스로 검증한다. 샘플 사진을 사용자
  앨범에 넣거나 운영 AI·구매·저장을 실행하지 않았으며 실기기 설치는 별도다.

## 2026-10-14 제작 미리보기와 빈 사진 보완

- 생성용 템플릿 선택과 분량 선택의 미리보기에 `showBookMaterial`을 켠다.
  표지는 승인한 홈/스토어의 `HomeCoverFrame`, 곡면 사진과 제본 재질을 쓰고,
  가로 내지는 실제 좌우 페이지를 한 펼침면으로 연결한다. 확대 화면은 기존
  평면 원본/확대 조작을 유지하며 앨범과 사진 데이터를 수정하지 않는다.
- 이 모드의 썸네일 목록은 지연 생성하고 화면 주변만 캐싱한다. 직접 이동이나
  회전 후 현재 쪽이 자동으로 목록 안에 나타난다. 기존 AI 문서 미리보기의
  기본 모드와 페이지 선택·확대·스와이프·키보드 계약은 유지한다.
- 설정과 사진 채우기에도 같은 책 표면을 연결한다. 사진 추가 전 상태는
  별도로 표시하되 샘플 사진을 사용자 앨범으로 가져오지 않는다. 책등의 복제
  이미지에는 사진 선택 테두리와 입력 콜백을 넣지 않는다. 사용자 사진의
  위치·프레임·구도와 기존 실행 취소·사진 보관함은 유지한다.
  사진 채우기는 원본 논리 캔버스 전체를 축소해 제본 표면 안에 표시하므로,
  책이 화면에 맞춰지는 과정에서 하단 사진·문구가 잘리지 않는다.
- 전체 확인에 빈 사진이 있는 쪽만 보는 필터와 첫 빈 사진으로 돌아가는
  작업을 추가한다. 필터 목록의 순번이 아닌 실제 앨범 쪽 번호를 반환한다.
  사진이 채워진 문서로 바뀌면 필터를 복구하고, 가로 썸네일은 상태 설명이
  하단 버튼에 가려지지 않도록 남은 높이에 맞춘다. 사진 파일이 늦게 도착해도
  새로 교체한 사진을 덮어쓰지 않도록 요청 세대를 확인한다.
- 확인 자료는 같은 `output/editor-flow-qa/index.html`에 추가한다. 실제 Flutter
  위젯과 테스트 사진으로 만든 캡처이며 운영 API·사진 권한·기기 설치 검증은 아니다.
  기존 사진 채우기 기준 이미지 3개는 같은 폴더의 `before-creation-photos-*`
  파일로 보존하고, 의도적으로 개편한 이 화면의 기준만 갱신한다.
  홈·리더·편집 화면과 가격·구매 권리·서버 저장·인쇄 규격은 변경하지 않는다.
- 최종 검증: 관련 13개 테스트 파일의 243개 테스트 통과, 변경 대상 10개 Dart
  파일 정적 분석 문제 없음. 가로/세로, 라이트/다크, 1.5배 글자, 실제 화면
  좌표로 사진 선택, 80쪽 지연 생성/회전 유지와 늦은 파일 조회를 확인했다.
  7개 화면의 새 캡처 42개는 테스트 렌더링이며 실기기 설치는 하지 않았다.

## 2026-10-08 템플릿 분량 · 제작 시작 연결

- 기본판/확장판이 있는 유료 컬렉션의 단순 목록 대화를 실제 페이지를 확인하는
  분량 선택 시트로 교체했다. 스토어 상세와 생성 중 템플릿 선택에 같은 시트를 사용한다.
- 기본 24쪽과 컬렉션별 32/36쪽은 각각 저작된 원본 문서로 표시한다.
  표지와 내지 분량을 분리하며, 사진 자리 수는 선택한 규격/분량의 실제 이미지 레이어에서 센다.
  선택 중에는 구매하지 않는다. 계속하기 이후 기존 서버 가격/보유 확인으로 연결하고,
  어느 분량을 고르든 같은 상품 키를 사용한다. 가격이나 소재 사용 권한 정책은 변경하지 않았다.
- 현재 상세에서 본 규격을 미리보기에 사용한다. 필요할 때 해당 규격만 준비하고
  같은 분량을 다시 고르면 준비된 레이어를 재사용한다. 회전 시 분량/확인 중인 페이지를
  유지하고, 짧은 판으로 바꾸면 범위를 벗어난 페이지만 마지막 페이지로 조정한다.
- 닫기/취소는 상세 문서를 바꾸지 않는다. 확정한 디자인은 비동기 구매 확인 전에
  복사해 보관하고, 완료 후 전달할 때 샘플 사진만 비워 실제 템플릿의 프레임/문구를 유지한다.
  중복 입력을 잠그고, 오류·거절·화면 종료 뒤에는 잘못된 화면 이동이나 남은 버튼 잠금을 막는다.
- 분량을 줄인 후 구매를 취소해 상세로 돌아오면 펼침면 위치도 유효한 마지막 면으로 맞춘다.
  생성 미리보기의 하단 동작을 별도 고정 영역으로 옮겨 실패 안내가 재시도 버튼을 가리지 않게 했다.
- 가로에서는 페이지와 선택을 양쪽으로 배치한다. 작은 화면/큰 글자는 내용만 스크롤하며
  계속하기와 닫기는 시스템 여백 안에 유지한다. 공통 문서 미리보기의 기존 확대/쪽 이동은 유지했다.
- [기존 선택·구매 검증 화면](../output/store-selection-qa/index.html)에 라이트/다크,
  작은 세로/세로/가로의 기본판·확장판·내지 캡처를 추가했다.
  `--dart-define=TEMPLATE_EDITION_QA=true`로 재생성하며 운영 구매/실기기 검증과는 구분한다.
- 기존 무료 컬렉션 사진 채우기 테스트의 모의 사진에 빠져 있던 식별자를 추가했다.
  현재 사진 파일 캐시/대상 비교에 필요한 테스트 데이터 보완이며 사진 배치 동작은 변경하지 않았다.
- 최종 검증: 관련 14개 테스트 파일의 237개 테스트가 통과했고 변경 대상 7개 Dart 파일의
  정적 분석에서 문제가 없었다. 분량 선택/표지/내지의 새 캡처 18개를 확인했다.
  실제 운영 계정 구매와 실기기 터치/프레임 성능은 별도 확인이 필요하다.

## 2026-10-08 초대받기 · 로그인 후 참여

- `snapfit://invite?token=...` 수신을 연결했다. 스플래시가 끝난 뒤 초대 확인 화면을
  열고, 이미 편집 중인 화면은 제거하지 않는다. 같은 링크 중복 수신은 화면을 쌓지 않는다.
  새 링크가 오면 기존 요청의 늦은 완료가 새 초대를 지우지 않는다.
- 초대 토큰은 별도의 기기 보안 저장소에 최대 14일 보관한다. 서버 만료 판정이 우선이다.
  로그인/앱 재시작 이후에도 이어지고, 명시적으로 닫거나 수락하면 해당 초대를 지운다.
  기기 저장소 실패 시 현재 실행 중인 초대와 로그인은 유지하지만 재시작 복원은 보장하지 않는다.
- 실제 서버의 앨범 이름, 초대한 사람과 편집/보기 권한을 표시하고 명시적 수락을 요구한다.
  아직 참여 권한이 없는 앨범의 사진은 임의로 조회하거나 가짜 표지로 표시하지 않는다.
  로그인만으로 자동 참여하지 않는다. 다른 계정으로 변경된 요청 결과도 자동으로 열지 않는다.
- 만료·삭제·사용된 초대는 새 링크를 요청하도록 안내하고, 네트워크 실패는 수동 재시도로
  처리한다. 참여가 완료된 뒤 앨범 조회가 실패해도 다시 수락하지 않고 다시 열기를 제공한다.
- 홈 목록은 소유 앨범과 `ACCEPTED` 공유 앨범을 함께 조회한다. 회원 권한은 앨범 콘텐츠에
  저장하지 않고 현재 계정 기준으로 조회한다. 보기 전용은 리더/상세/홈 편집 진입을 막고
  불필요한 편집 잠금을 요청하지 않는다. 공동 편집 저장은 서버 RLS의 편집 권한을 사용한다.
- `accept_album_invite`는 초대 행 잠금 안에서 멤버 추가와 초대 사용 처리를 함께 수행한다.
  다른 사람의 중복 수락을 거부하고, 같은 사람의 재시도는 기존 참여 상태를 반환한다.
  기존 멤버/소유자의 권한을 낮추지 않으며, 제거된 멤버가 사용한 링크로 재참여하지 못한다.
  실제 DB 오류는 성공으로 응답하지 않는다. 클라이언트 전달 userId 대신 검증된 Auth ID만 사용한다.
- RLS에서 `VIEWER`와 `PENDING` 멤버의 내용 수정을 거부한다. 공동 편집자의 소유자 변경도
  차단하며, 초대 수락 RPC는 서버의 `service_role`에서만 실행할 수 있다.
- 운영 반영 전 `20261008080526_album_invite_accept_atomic.sql` 적용 후 `album-invites` 배포가
  필요하다. 이 작업에서는 원격 DB를 변경하거나 함수를 배포하지 않았다.
  서버 테스트는 모의 Edge 요청과 격리된 PGlite PostgreSQL을 사용했다. 실제 연결,
  다중 연결 경합, OS에서 링크를 눌러 실행하기와 카카오톡 메시지 연동은 별도 확인이 필요하다.
- 재현: Flutter 초대/저장소/공유 목록/리더 테스트와
  `SNAPFIT_PGLITE_ENTRY=/path/to/pglite/dist/index.js node --test test/server/album_invites.test.mjs test/server/album_invite_database.test.mjs`.
  PGlite 경로가 없으면 DB 테스트는 건너뛴다. UI 캡처는
  `--dart-define=INVITE_ACCEPT_QA=true`로 기존 편집 검증 화면에 갱신한다.
- 최종 검증: 관련 Flutter 테스트 132개, 서버 테스트 5개가 통과했다. 작은 세로/세로/가로,
  라이트/다크와 160% 글자를 확인하고 수락 전/확인 중/만료/참여 완료 캡처 24개를 추가했다.
  변경 대상 17개 파일의 정적 분석에서도 문제가 없었다.

## 2026-10-08 저장 후 초대 · 공유 정리

- 리더와 상세 보기에서 사용하는 멤버 초대 화면을 정리했다. 실제 앨범 표지와 제목,
  편집/감상 권한, 링크 상태를 분리하며 복사·카카오톡 버튼은 시스템 여백 안에 고정한다.
  가로 화면은 앨범과 설정을 양쪽에 배치하고, 큰 글자는 스크롤 가능한 한 열로 전환한다.
- 표시·복사·공유는 동일한 발급 링크를 사용한다. 공유할 때 링크를 중복 발급하지 않는다.
  권한 변경은 새 링크를 발급하며 기존 링크를 취소하거나 기존 멤버의 권한을 바꾸지 않는다.
- 발급·공유·복사 동안 다른 작업을 잠그고, 권한이 바뀌면 이전 링크와 복사 완료 표시를 지운다.
  잘못된 링크/다른 앨범의 응답은 사용할 수 없고 다시 시도할 수 있다.
- 링크 발급 오류는 해당 영역에 표시한다. 연결/로그인/소유자 권한 오류를 구분하고
  서버 오류·토큰 내용을 노출하지 않는다. 복사 실패는 링크를 유지해 재시도할 수 있다.
- 카카오톡 공유를 열었다는 결과를 메시지 전송 완료로 표현하지 않는다.
  실패 사유를 앱 미설치로 단정하지 않고 같은 링크 복사로 대체한다.
  화면이 닫힌 뒤 완료된 요청은 공유 시작·복사·안내를 새로 실행하지 않는다.
- 검증은 모의 저장소·공유 결과와 실제 Flutter 위젯을 사용한다. 실제 API로 초대를 발급하거나
  카카오톡 메시지를 보내지 않는다. [기존 편집 검증 화면](../output/editor-flow-qa/index.html)에
  준비 중/발급 완료/실패 상태의 라이트·다크, 작은 세로·세로·가로 캡처 18개를 추가했다.
  초대·생성 초대·보조 화면·공통 내비게이션의 관련 테스트 64개가 통과했다.
  160% 글자, 시스템 여백, 알림이 하단 버튼을 가리지 않는 연속 동작도 확인했다.
- 후속 필수 연결: 현재 서버는 `snapfit://invite?token=...`를 반환한다.
  카카오 공유 서비스는 HTTP(S) 링크만 받으므로 앱 전용 링크는 복사 대체로 처리된다.
  초대 수신·로그인 후 유지·확인/수락은 위 후속 작업에서 연결했다.
  설치 유도와 카카오 공유 가능한 공개 HTTP(S) 링크는 별도 연결이 필요하다.
  실제 운영 초대 완료는 서버 배포와 기기 연동 확인 전에는 보장하지 않는다.

## 2026-10-08 생성 후 편집 · 이어 만들기

- 새 앨범 생성 단계에서 보관한 임시 저장을 자유 편집 화면에도 연결한다.
  도구 배치·앨범 연출은 유지하고, 상단에 기기 임시 저장 아이콘을 추가한다.
- 수동 임시 저장, 임시 저장 후 나가기, 앱 비활성화 시 현재 표지·내지·쪽수·배경색·
  사진 구도·선택한 쪽·표지 테마와 표지/내지 좌표계를 보관한다.
  사진 원본이나 실행 취소 이력 전체를 복사하지 않으며, 기기 간 동기화는 아니다.
- 홈에서 복원할 때 서버 앨범을 새로 만들거나 템플릿을 재배치하지 않는다.
  정확한 편집 좌표와 페이지를 복원하고 새 실행 취소 이력을 시작한다.
- 서버 저장 실패에도 최신 로컬 체크포인트를 유지한다. 로컬 실패는 편집 내용을
  지우거나 서버 저장 성공을 실패로 바꾸지 않는다. 전체 앨범 저장 성공 후에만 정리한다.
- `저장 안함`은 편집 진입 당시의 상태로 로컬 체크포인트까지 되돌려,
  앱을 다시 열었을 때 버린 수정이 나타나지 않게 한다. 로컬 정리 실패 시 화면을 유지한다.
- 계정·초안 ID·생성된 앨범 ID가 모두 맞을 때만 갱신한다. 읽기와 쓰기는 같은
  저장 큐 안에서 처리하며, 다른 초안으로 교체되거나 삭제된 저장은 되살리지 않는다.
- 범위는 새 앨범의 생성/편집 이어 만들기다. 기존 저장 앨범의 리더→편집 경로는
  기존 저장/변경 취소를 유지한다. 갑작스러운 강제 종료 전 저장 완료를 보장하지 않는다.
- [같은 편집 검증 화면](../output/editor-flow-qa/index.html)에 작은 세로·세로·가로,
  라이트/다크의 새 작업 공간과 나가기 대화를 추가했다. 실기기 검증은 별도로 필요하다.
- 검증 잔여: `page_editor_screen_golden_test.dart`의 기존 작업 공간 이미지와
  `editorAtelierPanel` 식별자 기대값은 현재 편집 화면과 일치하지 않는다.
  실제 이미지 차이는 상단의 이전 실행 취소 배치, 1쪽 구성과 현재 20쪽 최소 구성 등을
  포함한다. 이번 작업을 통과시키려고 기존 비교 이미지를 덮어쓰지는 않았다.

## 2026-10-08 사진 구성 · 편집 연결

- 생성의 사진 채우기뿐 아니라 표지·내지 편집에도 같은 사진 구도 창을 연결했다.
  사진 이동·확대·초기화는 초안에만 반영하며, 적용할 때 한 번의 변경으로 기록한다.
  취소/닫기는 수정하지 않는다. 프레임, 위치, 회전, 규격과 장식 속성은 유지한다.
- 기기 사진, 번들 사진, 저장된 HTTP/스토리지 사진을 지원한다. 사진을 읽기 전에는
  적용할 수 없으며 실패 시 다시 시도할 수 있다. 미리보기는 1600px 안에 원본 비율을
  유지해 디코딩하고 회전/드래그 때마다 새 크기로 사진을 다시 읽지 않는다.
- 구도 창이 열린 동안 대상 페이지/사진이 바뀌면 이전 초안으로 덮어쓰지 않는다.
  변경 없는 적용은 실행 취소 이력을 늘리지 않는다.
- 표지/내지의 사진 교체는 공통 슬롯 교체 경로를 사용한다. 새 사진의 예전 URL과
  구도만 초기화하고 프레임/장식 메타데이터를 보존한다. 갤러리를 연 뒤 페이지가
  바뀌면 다른 페이지에 선택 결과를 넣지 않는다.
- 작은 세로 화면의 레이어 도구에는 최소 높이를 확보했다. 독립 표지 편집 도구의
  아이콘/글자/터치 영역은 가로 화면에서 너비에 따라 확대하지 않는다.
- [같은 편집 검증 화면](../output/editor-flow-qa/index.html)에 실제 Flutter 위젯의
  사진 도구와 구도 창을 추가했다. 테스트 자료 기반이며 실기기 업로드/권한 검증은 아니다.

## 2026-10-07 화면 검토

- 유지: 기존 앨범 홈 캐러셀·리더·페이지 편집의 그래픽과 인터랙션, 인쇄 규격 5종,
  표지 종류, 쪽수 제한, AI 요청·비용 확인·결과 검토, 생성 후 편집 진입.
- 개편: 첫 앨범 홈의 실제 템플릿 표지와 생성 버튼, 홈 연결 오류의 재시도,
  생성 목록의 7개 주제 필터, 세로 설정의 확대된 앨범 미리보기,
  사진 채우기의 현재 쪽·남은 사진·전체 진행률, AI 대기·실패 상태.
- 표지 생성 도구에만 가벼운 단색 스타일을 적용한다. 기존 페이지 편집 도구는 변경하지 않는다.
  가로에서는 도구·실행 취소·다시 실행·편집 진입을 한 줄로 배치한다.
  레이어 액션은 실제 도구 영역 높이 위에 배치한다.
- 홈 앨범의 평소 크기·움직임은 유지하되, 좁은 화면·회전 중 크기 계산의
  최소·최대 범위 오류를 보완한다. 밝은 종이 배경의 빈 홈·오류 문구는
  다크 모드에서도 어두운 글자로 유지한다.
- 실제 저장 성공 콜백은 바로 페이지 편집으로 연결된다. 현재 초대 구성 요소는
  이 경로의 필수 단계가 아니므로 생성 단계에 추가하지 않는다.
- 검토 화면: [생성 과정](../output/creation-journey-qa/index.html).
  320×568, 390×844, 844×390, 시스템 여백, 다크 모드·150% 글자를 검증한다.
  로컬 데이터 기반 화면 검증이며 실제 저장·결제·AI API 호출 확인과 구분한다.

## 기획 요약

생성 방식은 네 가지로 열어두되, 결과는 같은 편집 가능한 앨범으로 연결한다.
직접 만들기는 빈 앨범부터 시작하고, AI는 사용자가 요청한 새로운 디자인을 만든다.
무료·프리미엄 템플릿은 실제 디자인을 미리 본 뒤 선택한다.

공통 과정은 **디자인 선택 → 앨범 설정 → 사진 채우기 → 표지 확인 → 자유 편집**이다.
직접 만들기는 사진 채우기 단계를 생략한다. 사진을 덜 채워도 계속 편집할 수 있고,
템플릿으로 시작했더라도 사진·글·배치·장식을 자유롭게 수정할 수 있다.

프리미엄은 포인트 상품의 실제 가격·활성 상태·구매 권한을 확인한다.
AI 생성 실패를 기존 템플릿으로 대체하거나, 샘플 사진을 사용자 사진처럼 저장하지 않는다.

현재 공개 카탈로그는 무료 37종·유료 14종이며, 은퇴한 기존 템플릿은 생성 목록에 노출하지 않는다.
규격별 전체 문서, 사진틀, 장식 레이어를 함께 전달하며 번들 디자인을 AI 생성 결과로 취급하지 않는다.
[구성 및 검증](authored_template_collections.md)

## Product Direction

One entrance, four starting points, one editable album. The choice is the amount
of design help the user wants, not a permanent editing mode.

- **직접 만들기**: empty album, physical size and page count, cover editor, page editor.
- **AI 템플릿**: describe an original design, review generation cost, inspect the generated
  pages, use the design, name the album, fill photo slots, review the cover, edit pages.
- **무료 템플릿**: browse the actual catalog, inspect cover and inner pages, choose a
  supported format, fill photo slots, review the cover, edit pages.
- **프리미엄 템플릿**: the same preview and creation path, behind the existing point-shop
  product and ownership check. Display the real quote, not an invented price.

The AI path remains independent of the template catalog. Existing free/premium
designs are never used as a substitute when original AI generation fails.

## Screens

1. **Creation hub**: manual and AI actions, searchable catalog, All / Free / Premium
   segments, topic filters and favorites. Covers use verified native thumbnails where
   available, with editable layers as fallback. Offscreen grid items are built lazily.
2. **Design preview**: cover alone; portrait inspects one page at a time, landscape
   inspects inner spreads. Arrows and swipes browse the full document. Existing store
   detail is still available from the store; creation has a focused selection view.
3. **Album setup**: title, original physical dimensions in cm, page count, current design
   provenance, change-design action. Only authored aspect variants are selectable.
   AI designs keep the aspect requested during generation. Added pages are explicitly blank.
4. **Photo fill**: tap a photo slot or add the next missing photo, using the existing
   gallery and permission handling. Replace images without changing layout, typography,
   frame geometry or decoration. Progress counts actual user photos. Skip unfilled slots
   and continue editing when desired. Photo selection is per slot, not bulk autofill.
5. **Cover and editor**: use the existing cover creation, backend save and page editor.
   The handoff retains the edited cover, chosen inner photos and additional blank pages.

## State And Safety

- Selecting from the creation catalog returns a typed selection to the same flow;
  it does not push another nested creation flow.
- Catalog sample photographs are removed from editable image slots. Stickers and
  decorative image assets are not removed.
- A separately stored cover is prepended exactly once, before inner pages.
- Template coordinates carry an explicit canvas and map proportionally to the physical
  album canvas. Missing aspect variants are not faked by stretching the design.
- Back from photo filling returns to setup with selected photos intact. Design changes
  after photo insertion require confirmation. Canceling the design picker returns to setup.
- Photo permission is requested only when the user adds a photo, never while browsing
  templates or submitting an AI design brief. Picker cancellation changes nothing.
- Premium access is not bypassed. Product activation, point price and ownership are
  checked by the existing point-shop access gate before design use.
- AI generation and point accounting retain their separate success/failure handling.

## Responsive Layout

- Fixed text sizes with scrollable forms, safe-area-aware footers and 48px action targets.
- Portrait: two-column template catalog, stacked form, single-page photo canvas,
  horizontal page thumbnails.
- Landscape: four-column catalog, side-by-side setup summary and fields, spread preview,
  vertical photo-page thumbnails.
- Verification viewports: 320x568, 390x844, 844x390. Golden captures use bundled fonts,
  icons and real template assets. AI preview fixtures test layout only, not generated quality.

## Document Preview Update: 2026-09-07

AI design review and catalog selection now share `CreationDocumentPreview`.
Portrait shows a single page and a horizontal thumbnail rail; landscape shows
facing inner pages and a separate right-hand rail. The cover remains a single
page. All thumbnails render the actual layers, not page-number chips.

Arrows, swipes and keyboard arrows navigate the document. Selecting the right
page of a spread keeps that exact page when returning to portrait. Selected
thumbnails scroll into view, and the page survives rotation and inspection.
Changing to a different document resets to its cover. Page transitions are
short slides, not the reader's BookFlip animation.

Tapping a page or the expand control opens a separate single-page inspection
route. Pinch/pan, double-tap, zoom controls and fit-to-screen are available there;
page navigation resets zoom. Closing, including system back, preserves the last
inspected page. No preview operation modifies layers, selects photos or calls AI.

AI review moves the acceptance action to the header in landscape. Full rationale,
physical size, palette, fonts and requirements are available in a scrollable
information sheet. On short portrait screens the physical-size subtitle lives
in that sheet to reserve more room for the page. Existing accept/refine callbacks,
generation and point accounting are unchanged.

The local interactive workbench is documented in `template_quality_studio.md`.
It contains authored specimens and contract fixtures, not generated results.

## Remaining Release Checks

- Production AI generation still requires the Edge Function deployment and a working
  model-provider quota. This UI work does not deploy backend functions or restore credits.
- New subscription purchases are currently disabled elsewhere in the product. Reopening
  billing requires a separate payment and server-entitlement release.
- Gallery permissions, cloud-only photographs and final upload/save need live-device
  verification. Widget tests cover photo insertion, picker cancellation, rotation, slot preservation and navigation;
  they do not substitute for OS permission or upload testing.

## Template Product Direction: 2026-09-07

아래는 미리캔버스를 비교 대상으로 추가한 이후의 **목표 기획**이다.
앞의 Screens에 적힌 구현 상태와 구분하며, 시안 비교·부분 재생성·생성 소재 등은
아직 구현된 기능으로 표시하지 않는다. 생성 화면의 완성과 템플릿 품질의 완성은 다르다.

### 두 가지 독립적인 제품

1. **템플릿 라이브러리**: 고르고 싶을 만큼 완성된 앨범 디자인을 충분히 제공한다.
   무료·프리미엄 모두 같은 기본 품질 기준을 통과해야 한다.
2. **AI 맞춤 디자인**: 사용자의 요청을 해석해 새로운 표지와 내지 구성을 만든다.
   라이브러리 검색, 기존 구성의 색상 변경, 사진 자동 배치를 새 디자인 생성으로
   표현하지 않는다. 생성 실패 시 라이브러리 결과로 몰래 대체하지 않는다.

두 경로의 결과는 같은 편집 가능한 문서와 에디터로 연결한다.
직접 만들기는 계속 독립적으로 제공하며, AI를 사용해야만 편집할 수 있게 하지 않는다.

### 라이브러리의 제작 단위

- 한 템플릿은 예쁜 표지 한 장이 아닌 **표지와 모든 내지가 완성된 앨범 컬렉션**이다.
- 여행·웨딩·성장 기록·커플·가족·포트폴리오 등 목적별로 시작하되, 각 목적 안에서도
  에디토리얼·필름·콜라주·타이포그래피 등 실제로 다른 표현을 제공한다.
- 크게 보는 사진, 작은 연속 사진, 기록을 읽는 페이지, 쉬어가는 페이지를
  앨범의 이야기에 맞게 배치한다. 모든 페이지에 사진을 강제로 넣을 필요는 없다.
- 세로·정사각형·가로는 각각 조판하고 검수한다. 한 디자인을 늘리거나 압축해서
  다른 규격을 지원한다고 표시하지 않는다.
- 표지·대표 스프레드·전체 내지 미리보기는 실제 편집 문서에서 렌더링한다.
  샘플 사진과 빈 사진틀 상태를 모두 검수하고, 사진 교체 후에도 구성이 유지되어야 한다.
- 색상만 다른 파생본이나 비율 변환본은 별도 독창적 디자인 수로 세지 않는다.
- 무료의 완성도를 의도적으로 낮추지 않는다. 프리미엄은 독자적인 아트워크,
  풍부한 내지 구성과 컬렉션 범위 등 실제 차이로 설명한다. 가격은 별도 결정한다.

운영 과정은 제작 → 실제 렌더링 → 편집/인쇄 검수 → 승인 → 공개로 둔다.
상태, 작성자, 버전, 지원 규격, 소재 출처와 사용 범위를 기록하고, 승인된 컬렉션만
노출한다. 초기에는 서로 다른 소수 컬렉션으로 기준을 검증한 뒤 제작량을 늘린다.
단순한 대량 생성이나 등록 개수는 품질의 대체 지표로 쓰지 않는다.

### AI의 목표 사용자 흐름

1. **요청**: 원하는 분위기·앨범 목적·사진/글의 비중을 자유롭게 적는다.
   규격과 페이지 수를 함께 받는다. 예시 문장은 입력 보조이며 고정 레이아웃이 아니다.
   참고 이미지 입력은 추후 지원하며, 사용자가 선택한 자료만 전달한다.
2. **디자인 방향 비교**: 우선 서로 다른 2~3개 방향의 표지와 대표 스프레드를 보여준다.
   단순 색상 차이가 아닌 사진 크기, 글꼴 조합, 여백, 구성과 장식의 차이가 있어야 한다.
   이 단계는 샘플 시안임을 표시하고 완성된 전체 앨범인 것처럼 보여주지 않는다.
3. **방향 확정**: 사용자가 고른 시안과 수정 요청을 바탕으로 전체 앨범을 구성한다.
   선택한 시안이 전체 생성에서 임의로 바뀌지 않도록 디자인 기준을 유지한다.
4. **부분 수정**: "표지는 그대로, 3~4페이지만 사진을 크게"처럼 요청한다.
   선택 범위 밖의 페이지·사진·텍스트는 보존하고, 변경 미리보기와 되돌리기를 제공한다.
5. **사진 채우기**: 디자인 확정 후 사진을 넣는다. 사진 교체는 배치나 글꼴을 바꾸지 않는다.
   사진 선택·자르기를 사용자가 통제하며, 자동 채우기는 향후 별도 선택 기능으로 둔다.
6. **자유 편집**: AI 결과를 일반 레이어로 편집한다. 표지와 글을 한 장의 이미지로
   합쳐서 편집할 수 없는 가짜 템플릿을 만들지 않는다.

방향 비교와 전체 생성의 비용·진행 상태는 구분해서 보여줘야 한다.
취소·재시도·이전 시안으로 돌아가기가 기존 결과를 지우거나 중복 과금하지 않아야 한다.
가격과 차감 시점은 서버 계약을 정한 뒤 연결하며, 현재 과금 동작을 임의로 확장하지 않는다.

### 생성 엔진의 개선 순서

현재는 전체 문서를 한 번에 생성하며 사진틀·글·사각형만 표현한다. 다음은 목표 구조다.

1. **디자인 계획**: 사용자 요청을 색상·글꼴 계층·여백·사진 비중·장식 방향·
   스프레드별 역할로 명시한다. 금지 사항과 반드시 지킬 요구도 별도로 보존한다.
2. **표현 능력**: 실제 편집기에서 지원하는 글꼴·프레임·도형부터 검증해 확장한다.
   소재 생성은 별도 기능으로 추가하고, 생성 장식과 사용자의 실제 사진을 구분한다.
   폰트와 소재의 사용 범위·출처를 관리한다.
3. **문서 생성**: 계획을 기반으로 새로운 레이어 배치를 만든다. 공통 렌더러와
   타이포그래피 규칙은 재사용할 수 있지만 기존 카탈로그의 완성 배치를 가져오지 않는다.
4. **렌더링 검수와 보정**: JSON 구조뿐 아니라 실제 글꼴로 렌더링한 페이지와
   스프레드를 검사한다. 문제가 생긴 부분만 수정하고 검사 결과를 다시 확인한다.
5. **의도 보존 편집**: 안정적인 페이지/요소 ID, 잠금 범위, 변경 이력과 원자적 적용으로
   마음에 드는 디자인을 보존하면서 고친다.

새로운 기반 AI 모델을 보유했다는 의미가 아니다. 앨범 설계, 실제 편집 문서 변환,
검수·보정, 규격 대응과 수정 의도 보존을 결합하는 것이 SnapFit의 기술 개발 범위다.

### 품질 승인 기준

**필수 통과 조건**: 저장/재편집 가능, 실제 폰트의 글자 잘림 없음, 사진 교체 후
레이아웃 유지, 요청 규격/페이지 수 일치, 권한과 소재 출처 확인, 미리보기/에디터 일치.
인쇄 준비 완료 표시는 인쇄 업체의 재단·안전 여백·제본 규격 검수까지 통과한 경우만 쓴다.

**시각 평가 초안**: 요청 반영, 타이포그래피, 사진 배치, 스프레드의 흐름,
전체 통일감, 다른 결과와의 다양성을 각각 1~5점으로 평가한다.
1점은 재설계 필요, 3점은 주요 수정 필요, 5점은 공개 가능 수준으로 정의한다.
초기 운영 기준은 모든 항목 4점 이상으로 두고 실제 평가자 간 일치도를 확인해 보정한다.
자동 검사와 AI 평가만으로 공개하지 않고 실제 렌더링을 사람이 검토한다.

첫 평가 묶음은 목적 6개 × 물리 규격 3개 × 서로 다른 요청 2개 = 36개 요청으로 둔다.
텍스트 중심, 사진 중심, 장식이 많은 구성과 절제된 구성을 함께 포함한다.
실제 생성 결과, 사용한 요청/모델/문서 버전, 시도 횟수, 지연시간, 비용,
실패 사유와 위 평가 결과를 보관한다. 실패를 제외하고 성공률을 계산하지 않는다.
실제 생성 평가와 수작업 시안·테스트 fixture는 별도로 표시한다.

### 바로 다음 작업의 완료 조건

첫 디자인 기준 시안과 검증 범위는 [Template Quality Studio](template_quality_studio.md)에
기록한다. 이는 제작 시안이며 실제 AI 생성 성능과 구분한다.

- 서로 다른 디자인 방향으로 표지와 대표 스프레드를 먼저 제작해 눈으로 품질 기준을 정한다.
- 이를 앱의 실제 레이어와 폰트로 표현할 수 있는지 확인하고 부족한 표현 기능부터 추가한다.
- 실제 AI 생성 결과가 그 기준을 충족하는지 평가한다. 현재 테스트 통과를 미적 품질의
  증거로 사용하지 않는다. 로컬 AI 호출은 앞서 잔액 부족으로 실패해 실제 품질은 미검증이다.
- 품질 기준을 검증한 뒤 시안 비교/부분 수정 UI와 라이브러리 확대를 진행한다.
  현재 카탈로그가 이미 높은 품질로 교체되었다고 설명하지 않는다.

## Reference

The decision to converge on an editable document is informed by the template-to-editor
workflow in [Canva's mobile photo-book guide](https://www.canva.com/learn/make-free-photo-books-mobile-tablet/).
The UI and the original AI-template behavior above are SnapFit product decisions, not
a claim that a particular visual style is universally the latest trend.

MiriCanvas's official [AI presentation workflow](https://www.miricanvas.com/ko/features/ai-presentation-maker)
combines topic/outline development, theme selection and editable slide generation.
Its [AI image tool](https://www.miricanvas.com/ko/features/image-generator) provides
prompt-driven visual assets. These inform the distinction between editable document
design and asset generation; they are not evidence that SnapFit currently matches
or exceeds its quality. The comparison does not authorize copying its templates or assets.
