# 제작 시작·디자인 목록 검증

2026-11-11. 승인 시안을 Flutter 소스에 반영한 범위 검증이다. 전체 앱 빌드·운영 배포 결과가 아니다.

## 결과

| 실행 묶음 | 통과 | 실패 | 로그 |
| --- | ---: | ---: | --- |
| 카테고리·선택·새 통합·기존 목록 | 32 | 0 | `logs/core-tests.log` |
| 시작 화면·큰 글자·화면 크기 | 8 | 0 | `logs/entry-tests.log` |
| 주제·가격·즐겨찾기 조합 | 1 | 0 | `logs/refinement-tests.log` |
| 실제 제작 헤더·저장 실패 복구 | 2 | 0 | `logs/draft-tests.log` |
| 상세 프로필 지연 읽기 | 1 | 0 | `logs/profile-tests.log` |
| 제작 여정·설정 복귀·판매 불가 | 3 | 0 | `logs/journey-tests.log` |
| 실제 컴포넌트 캡처 | 2 | 0 | `logs/capture-tests.log` |
| **합계** | **49** | **0** | `results.json` |

정적 분석 결과는 `logs/analysis.log`에 보관했다. 네이티브 테스트 엔진에서 한 번에 한 프로세스만 사용했다. CLI 소켓 제한 때문에 test_api의 동일 테스트 본문을 직접 실행했다. 별도 바인딩이 있는 제작 여정과 각 파일의 전역 상태는 분리 실행했다.

캡처 실행에서는 앱의 FontManifest·실제 에셋 글꼴을 사용했다. 가격은 출시 가격표에서 얻은 고정 데이터이고 보유권·서버 조회는 테스트 대역이다. 실제 운영 가격·계정 상태를 검증한 것으로 해석하면 안 된다.

## 화면

모든 PNG는 논리 크기와 출력 크기가 같은 390×844, devicePixelRatio 1이다.

| 상태 | 라이트 | 다크 |
| --- | --- | --- |
| 시작 | `creation_entry_light.png` | `creation_entry_dark.png` |
| 디자인 목록 | `creation_catalogue_light.png` | `creation_catalogue_dark.png` |
| 카테고리 가로 탐색 | `creation_catalogue_scrolled_light.png` | `creation_catalogue_scrolled_dark.png` |

초기 비교에서 발견한 수직 정렬·작은 표지 문제의 수정 전 증거는 `initial/`에 있다. 원본 시안과 최종 비교·남은 브라우저 검증 범위는 프로젝트 루트의 `design-qa.md`를 참고한다.

## 일반 개발 환경에서의 재실행

변경한 테스트들은 일반 Flutter 테스트 파일이다. 전체 저장소를 한 번에 실행할 필요 없이 해당 파일을 `flutter test --concurrency=1 <test-file>`로 실행할 수 있다. 실제 캡처 파일은 `CREATION_CATALOG_CAPTURE_DIR` 환경변수를 지정한 `creation_catalog_capture_test.dart` 실행에서만 생성한다. 전체 앱 빌드나 서버 실행을 요구하는 테스트가 아니다.

현재 기록은 위 범위의 통과를 뜻한다. 전체 저장소 테스트, 실기기, 브라우저 렌더, 운영 서버 상태 및 배포는 검증 범위 밖이다.
