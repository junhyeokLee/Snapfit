# 웹 기능 대조 · 2026-10-15

현재 모바일 앱에서 일반 사용자가 진입하는 기능을 기준으로 실제 웹 화면·동작 연결을 읽어 대조했습니다. 시안의 11개 대표 화면만을 기능 목록으로 보지 않습니다. 이전에 남아 있는 미사용 위젯이나 별도 SnapFitAdmin은 고객 웹 기능과 구분합니다.

아래의 ‘연결 확인’은 소스상 화면, 콜백, 기존 데이터 공급·저장 동작을 확인했다는 뜻입니다. 최초 대조에서는 실행·분석·테스트·빌드를 수행하지 않았습니다. 이후 포인트 충전·푸시·다크 테마 준비 단계에서 전체 `lib` Dart 정적 분석과 서버·알림 파일 문법 검사를 통과했습니다. 후속 설정 단계에서는 Firebase 공개키·DB·서버 함수·PortOne TEST 웹훅·복구 인증을 반영하고, 비활성 복구 예약과 원격 권한·실결제 차단을 조회로 확인했습니다. 앱·웹 실행, AI 생성·구매·결제·웹훅 호출·발주 테스트와 Flutter 웹 빌드는 하지 않았으며, 실제 브라우저 동작을 보증하는 문서가 아닙니다.

## 일반 사용자 기능

| 기능 | 웹 진입과 연결 확인 | 주요 소스 |
| --- | --- | --- |
| 로그인·가입 | 이메일, Google·카카오, 필수 동의, 인증 메일 재발송, 비밀번호 복구 | `features/auth/presentation/views/login_screen.dart` |
| 앨범 모음 | 검색·정렬·작성 중/완료·즐겨찾기·공유 필터, 기존 계정의 실제 앨범 열기 | `features/album/presentation/web/web_album_library_screen.dart` |
| 직접 만들기 | 5개 규격, 소프트/하드커버, 20~80쪽 제한, 제목·설정·표지 편집·생성 전 검토 | `features/album/presentation/views/album_create_flow_screen.dart` |
| 템플릿 만들기 | 공개 템플릿 선택·분량 선택·사양 설정·사진 채우기·앨범 생성 | 같은 생성 흐름과 `features/store/presentation/views/template_detail_screen.dart` |
| AI 만들기 | 디자인 요청 작성, 비용·동의 확인, 기존 생성 API, 실패·재시도, 추천 편집·확정, 사진 채우기 | `features/album/presentation/views/album_create_flow_screen.dart` 및 `widgets/create_flow/ai_*` |
| 사진 가져오기 | 파일 선택·드롭, 다중 선택, 원본·미리보기 분리, 사용자별 사진 목록, 파일 오류 안내 | `shared/widgets/browser_photo_selection_sheet.dart`, `features/album/data/gallery/` |
| 사진 배치 | 템플릿의 슬롯 선택·배치·교체·구도 조정, 사진 비율 선택 | `widgets/create_flow/template_photo_fill_step.dart`, `shared/widgets/image_template_picker.dart` |
| 임시 저장·이어 만들기 | 계정별 문서와 참조 사진 원본을 함께 IndexedDB 저장, 같은 브라우저에서 복원, 연결된 편집 초안 갱신·정리 | `features/album/data/album_creation_draft_store_web.dart`, `browser_draft_database.dart` |
| 문서 편집 | 저장, 실행 취소/다시 실행, 쪽 추가/삭제·선택·이동, 표지·내지 전환, 레이어·배치 | `features/album/presentation/views/page_editor_screen.dart` |
| 사진 편집 | 이동·크기·회전·사진 교체·크롭·프레임·투명도 | 같은 편집기와 `features/album/presentation/controllers/` |
| 글·배경·꾸미기 | 글 입력·서체·색·문구·워드아트·장식·배경·표지 테마, 페이지 레이아웃·디자인 템플릿 | 같은 편집기와 `widgets/editor/`, `shared/widgets/` |
| 읽기·상세 | 페이지 목록·앞뒤 이동·페이지 상세·확대·편집 복귀, 제작 검토·책 주문 | `features/album/presentation/views/album_reader_screen.dart`, `album_reader_inner_detail_screen.dart` |
| 공유·초대 | 보기/편집 권한, 링크 생성·복사, 초대 수락·로그인 복귀, 기존 소유자별 관리 제한 | `features/album/presentation/views/album_invite*_screen.dart` |
| 앨범 관리 | 소유자 삭제 확인·실제 삭제·목록 갱신, 공유된 앨범 보기와 허용된 편집 | `widgets/home/home_album_actions.dart`, `views/album_category_screen.dart` |
| 템플릿 목록 | 주제·검색·무료/유료·즐겨찾기·정렬·더 보기, 앱과 동일한 공개 카탈로그 | `features/store/presentation/views/store_screen.dart` |
| 템플릿 상세 | 표지·내지 미리보기·전체 보기·분량 선택·포함 소재 안내·공유, 불러오기 실패 재시도 | `features/store/presentation/views/template_detail_screen.dart` |
| 꾸밈소재 목록 | 스티커·종이·프레임·문구·워드아트의 앱과 같은 카탈로그, 종류·검색·가격·즐겨찾기 | `features/store/presentation/views/material_catalog_screen.dart` |
| 소재 상세·적용 | 원본·적용 예시·예시 사진 전환, 확대·이동, 앨범/페이지 선택, 권한 재확인·잠금 후 편집기에 삽입 | `features/store/presentation/views/material_detail_screen.dart`, `widgets/material_album_picker.dart` |
| 디자인 보관함 | 구매한 템플릿·소재와 즐겨찾기, 종류·검색·정렬, 상세·앨범 적용 | `features/store/presentation/views/material_catalog_screen.dart` |
| 포인트 이용 | 서버 가격·보유권한 재조회, 무료/보유 즉시 이용 또는 잔액에서 기존 포인트 구매, 이용 확인·영수증·잔액/권한 갱신 | `features/point_shop/presentation/point_shop_access.dart`, `point_shop_purchase_sheet.dart` |
| 포인트 잔액·내역·충전 | 실제 계정의 잔액·이용 내역, 웹 충전 상품·전용 PortOne V2 경로·복구 내역 준비. 실제 결제 차단과 TEST 원장 분리 | `features/profile/presentation/views/billing_management_screen.dart`, `features/billing/` |
| 책 주문 준비 | 실제 앨범 검수·인쇄 파일 준비·배송지/주소 검색·서버 견적, 기존 판매 가능 여부·TEST 전용 보호 | `features/album/presentation/views/print_order*_screen.dart` |
| 주문내역·상세 | 상태 필터·상세·배송 정보·주문번호 복사·결제결과 복구·문의·취소/환불 요청 | `features/profile/presentation/views/order_history_screen.dart`, `print_order_request_screen.dart` |
| 계정·설정 | 프로필·사진 확대·저장량·앨범/주문 요약, 보관함·공유 앨범·알림함 진입, 계정 설정·로그아웃/탈퇴 | `features/profile/presentation/views/my_page_screen.dart`, `account_settings_screen.dart` |
| 알림·웹 푸시 | 실제 알림 목록·읽음 상태·기존 내용 열기, 계정별 원격 수신 설정, 이 브라우저 권한·연결·백그라운드 수신 준비 | `features/notification/presentation/views/notification_screen.dart`, `core/notifications/`, `web/firebase-messaging-sw.js` |
| 웹 테마 | 밝게·어둡게·시스템 선택과 브라우저 저장, 웹 화면과 브라우저 바탕/테마 색 동기화 | `shared/web/web_design.dart`, `web_theme_controller.dart`, `web_document_theme*.dart` |
| 고객센터·정책 | 문의 작성·접수, 주문 관련 요청, 약관 목록·개별 정책 문서 | `features/profile/presentation/views/support_inquiry_screen.dart`, `terms_policy_screen.dart` |
| 브라우저 이동 | 계정 확인 후 직접 경로 열기·복귀·뒤로가기, 편집 중 저장 확인, 계정 전환 시 이전 앨범 목록 갱신 | `core/navigation/web_app_*.dart`, `main.dart` |

위의 경로는 `lib/` 기준입니다. 실제 상품 노출·가격·보유권한은 기존 서버와 공개 카탈로그 정책을 따르며, 비공개/판매 준비 중 상품을 임의로 판매 상태로 바꾸지 않습니다.

## 이번 대조에서 보완한 누락

- 웹 메인에 템플릿·꾸밈소재·AI 만들기·내 디자인 보관함 바로가기를 추가하고 상단 메뉴를 ‘템플릿·소재’로 명시했습니다. `/#/create/ai`, `/#/designs/materials`로 직접 시작할 수 있습니다. AI 바로가기는 입력 단계만 열고 생성이나 포인트 차감을 자동 실행하지 않습니다.
- 메인과 전역 만들기 메뉴에서 기존 임시 저장을 확인한 뒤 이어 만들기 또는 새로 만들기를 선택하도록 연결했습니다.
- 모바일 파일 경로를 사용하던 웹 임시 저장을 브라우저 저장으로 분리했습니다. 대기 사진·표지·내지·규격별 변형·표지 편집·편집 체크포인트에 있는 사진을 원본 바이트와 안정된 사진 ID로 함께 복원합니다. 원본을 축소하거나 미리보기로 대체하지 않습니다.
- 웹 생성 화면이 시작할 때 기존 초안의 변경 시점을 기록하고, 저장·편집 갱신·삭제 때 같은 트랜잭션에서 비교합니다. 오래된 탭이 다른 탭의 최신 초안을 덮거나 삭제한 초안을 되살리면 오류로 처리하고 작업을 남깁니다. 저장 용량 부족 등으로 커밋이 실패하면 변경 기준도 갱신하지 않습니다.
- 사진 비율 선택과 표지 테마를 웹 대화상자/도구로 연결하고, 소재 확대·이동과 템플릿 재시도·웹 공유 실패 시 링크 복사를 보완했습니다.
- 계정 화면에 보관함·공유 앨범·알림함·프로필 사진 확대를 연결했습니다. 계정이 변경된 뒤 이전 계정의 문의·포인트·설정·알림 응답이 표시/전송되지 않도록 웹 경계를 보완했습니다.
- 전역 초기화에서 웹이 네이티브 인앱 결제 서비스를 만들거나 복구하지 않도록 분리했습니다. 앨범 주문의 기존 PortOne 결제결과 복구는 유지합니다.
- 웹 알림 설정은 회원별 기존 원격 설정을 읽고 저장하되, 네이티브 기기 등록·권한 요청은 실행하지 않습니다. 알림의 웹 경로형 주문/앨범 링크도 해당 실제 내용으로 연결합니다.

## 구분해야 하는 현재 범위

- 실제 카드 결제·운영 발주는 계속 닫혀 있습니다. 이 변경은 실판매 게이트·가격·결제/발주 서버 설정을 바꾸지 않습니다.
- 최초 대조에서 미지원으로 기록했던 **웹 포인트 충전·브라우저 푸시·다크 테마는 후속 소스 준비에 포함**했습니다. 공개키·DB·서버 함수도 반영했으며 [설정과 준비 상태](web-capabilities-preparation.md)를 확인합니다.
- 웹 충전은 모바일 IAP와 분리한 PortOne V2 경로이며 실제 결제는 차단합니다. TEST도 서버에서 명시적으로 비활성이고 실제 지갑과 분리한 원장을 사용합니다. 신규 서버 함수·DB·PortOne TEST 웹훅·재조회 인증·Vault 설정을 완료했습니다. 복구 예약은 처음부터 비활성으로 등록했고 실행 기록은 없으며, 결제·웹훅·복구 동작 검증은 별도 단계입니다.
- 웹 푸시는 공개 VAPID 키·서버 반영을 완료했습니다. 서비스 워커가 포함된 웹 빌드·HTTPS 호스팅과 각 사용자의 권한 선택·수신 검증은 남아 있습니다. 기존 모바일 푸시와 발송 스케줄은 유지했고 알림을 전송하거나 예약 작업을 직접 실행하지 않았습니다. OS가 브라우저를 완전히 종료하거나 수신을 제한하는 경우까지 즉시 도착을 보장하지는 않습니다.
- 웹의 밝게·어둡게·시스템 선택은 모바일의 테마 선택과 별개입니다. 사진·앨범·소재 작품 색은 바꾸지 않습니다.
- 현재 앱·웹의 공통 AI 시작은 ‘글로 디자인 생성 → 사진 채우기’입니다. 이전 사진 메타데이터 분석 분기는 현재 시작 화면에서 쓰지 않는 공통 구조이며, 이를 새 웹 기능으로 표시하지 않았습니다.
- 문의 답변 목록처럼 현재 모바일 원본에도 없는 기능을 구현 완료로 표기하지 않습니다. 별도 관리자 프로젝트와 고객이 접근하지 않는 앱 관리자 화면도 이 목록에서 제외합니다.

브라우저 임시 저장은 같은 사이트·브라우저의 저장 공간을 사용합니다. 다른 PC로 동기화하는 기능이 아니며, 브라우저 데이터 삭제나 저장 용량 부족 시 유지가 보장되지 않습니다. 저장 오류는 성공으로 표시하지 않고 기존 초안과 작업을 유지합니다. 사진 선택 목록의 기존 한 번 100장·원본 합계 250MB 제한을 여러 번 작업한 앨범 전체의 새 제한으로 적용하지 않습니다.

## 이후 실행 검증

별도 실행 단계에서 브라우저 새로고침 후 원본 사진·구도 복원, 저장 용량 부족/차단·여러 탭 충돌, 계정 전환, 실제 공개 상품/가격/잔액, AI 성공·실패·재시도, 소재 삽입과 저장, 주문 검수·내역·취소/환불 동선을 확인해야 합니다. 실제 결제를 여는 작업은 포함하지 않습니다.
