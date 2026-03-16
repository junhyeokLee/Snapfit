# SnapFit — TASK.md (자동 개발용)

> **토큰 절약 패턴**: 각 태스크는 **ID·범위·성공 기준·참조**만 기재. 상세 규칙·스키마는 `.cursor/` 및 문서 경로로 참조.

---

## 1. 사용 방법 (에이전트/Claude)

- **한 번에 하나의 TASK 블록**만 수행. 완료 후 해당 블록에 `[x]` 체크.
- **참조 열**의 파일/규칙만 열어 필요한 최소 컨텍스트만 로드.
- 규칙 전체 복붙 금지 → `.cursor/rules/snapfit-index.mdc` 등 **경로만** 명시.
- 백엔드·Flutter 동시 수정 시 → 에이전트 **full-stack-sync-master** 또는 SKILL `snapfit-specialized-skills` 참조.

---

## 2. 규칙·에이전트 인덱스 (참조용)

| 구분 | 경로 | 용도 |
|------|------|------|
| 규칙 허브 | `.cursor/rules/snapfit-index.mdc` | 규칙 목록 |
| 요구사항 | `.cursor/rules/snapfit-requirements.mdc` | 비즈니스·데이터 모델·API |
| 기술 규칙 | `.cursor/rules/snapfit-technical.mdc` | MVVM, Riverpod, Retrofit, 보안 |
| 스크린 로깅 | `.cursor/rules/snapfit-screen-logging.mdc` | ScreenLogger |
| 테스트 | `.cursor/rules/snapfit-testing.mdc` | 유닛/위젯 테스트 |
| 위젯 분리 | `.cursor/rules/widget-component-separation.mdc` | 화면 위젯 분리 |
| UI/디자인 | `.cursor/rules/flutter-ui-standards.mdc`, `snapfit-design-*.mdc` | 컬러, 타이포, 컴포넌트 |
| 에이전트 가이드 | `.cursor/docs/agents-guide.md` | 에이전트 호출 시점 |
| full-stack 동기화 | `.cursor/agents/full-stack-sync-master.md` | Spring Boot ↔ Flutter API/DTO |
| Riverpod 아키텍트 | `.cursor/agents/riverpod-architect.md` | ViewModel, ref.listen, AsyncValue |
| 보안·품질 | `.cursor/agents/security-quality-auditor.md` | 토큰, 저장소, API 키 |
| 스킬 | `.cursor/skills/snapfit-specialized-skills/SKILL.md` | build_runner, API 동기화, Riverpod |

---

## 3. 템플릿 도메인 (디자인 + 제공)

### 3.1 스키마·정의

| 항목 | 경로 | 설명 |
|------|------|------|
| 통합 스키마 | `docs/template_schema.md` | canvas + layers(image/text/sticker/decoration/shape), rect 비율, 동적 바인딩 `{{key}}` |
| 디자인 템플릿(커버) | `lib/core/constants/design_templates.dart` | `DesignTemplate`, `buildLayers(Size)` — 결혼/스크랩북 등 커버용 |
| 페이지 템플릿 | `lib/core/constants/page_templates.dart` | `PageTemplate` + `PageTemplateSlot` (비율 좌표), The Journey 등 |
| 캔버스 엔티티 | `lib/features/album/domain/entities/template_canvas.dart` | `TemplateCanvas`, `CanvasDecoration` (스키마 대응) |
| 레이어 엔티티 | `lib/features/album/domain/entities/layer.dart` | `LayerModel`, `LayerType`, export 매핑 |

### 3.2 백엔드 (템플릿 제공)

| 항목 | 경로 | 설명 |
|------|------|------|
| API | `SnapFit-BackEnd/.../controller/TemplateController.java` | GET /api/templates, GET /{id}, POST /{id}/like, POST /{id}/use |
| 엔티티 | `.../domain/template/entity/TemplateEntity.java` | id, title, subTitle, description, coverImageUrl, previewImagesJson, pageCount, likeCount, userCount, isBest, isPremium, templateJson(LONGTEXT), createdAt, updatedAt |
| 응답 DTO | `.../domain/template/dto/response/TemplateResponse.java` | TemplateResponse (templateJson 포함), from(entity, previewImages, isLiked) |
| 서비스 | `.../domain/template/service/TemplateService.java` | 목록/상세/좋아요/앨범 생성(use) |
| 시드 데이터 | `.../global/init/TemplateDataLoader.java` | 초기 템플릿 로드 |

### 3.3 Flutter (템플릿 소비)

| 항목 | 경로 | 설명 |
|------|------|------|
| API 클라이언트 | `lib/features/store/data/api/template_api.dart` | Retrofit: getTemplates(userId), getTemplate(id), likeTemplate(id), createAlbumFromTemplate(id, userId, replacements) |
| DTO | `lib/features/store/domain/entities/premium_template.dart` | TemplateResponse와 필드 매핑 (id, title, templateJson 등) |
| UI 패널 | `lib/features/album/presentation/widgets/editor/design_template_panel.dart` | 디자인(커버) 템플릿 선택 |
| 선택 패널 | `lib/features/album/presentation/widgets/editor/template_selection_panel.dart` | 페이지 템플릿 선택 |
| 레이어 빌더 | `lib/features/album/presentation/controllers/layer_builder.dart` | 템플릿 JSON → 레이어 변환 |

### 3.4 템플릿 관련 태스크

- [ ] **T-TEMPLATE-1**  
  **범위**: 서버 `templateJson`과 Flutter `docs/template_schema.md` 구조 일치 검증 및 파서 정합성.  
  **성공**: Entity의 templateJson이 schema의 canvas + layers 구조이고, Flutter에서 파싱 시 LayerModel/TemplateCanvas로 변환 오류 없음.  
  **참조**: `docs/template_schema.md`, `TemplateEntity.templateJson`, `layer_builder.dart`, `template_canvas.dart`, `layer.dart`.

- [ ] **T-TEMPLATE-2**  
  **범위**: 템플릿 목록/상세 API 인증.  
  **성공**: SecurityConfig에 `/api/templates` GET은 인증 없이 허용(또는 정책에 맞게), POST /like, /use는 인증 필수.  
  **참조**: `SecurityConfig.java`, `TemplateController.java`, `.cursor/agents/security-quality-auditor.md`.

- [ ] **T-TEMPLATE-3**  
  **범위**: Flutter에서 `createAlbumFromTemplate` 호출 후 앨범 편집 화면 진입 및 스냅샷/상태 일관성.  
  **성공**: use 호출 → 앨범 생성 → 해당 앨범 편집기로 이동, 레이어/페이지가 templateJson 기준으로 로드됨.  
  **참조**: `template_api.dart`, 앨범 편집 ViewModel/라우팅, `snapfit-requirements.mdc`.

---

## 4. 기능 (Feature) — 요구사항·플로우 기준

> 출처: `.cursor/rules/snapfit-requirements.mdc`, `.cursor/docs/snapfit-requirements.md`  
> **플로우**: Solo = 생성 → 사진 선택 → 템플릿 → 레이어 편집 → 미리보기 → 사양 → 결제 → 배송 | Collaboration = 초대 → 수락 → 편집+이력 → Freeze → 결제 → 배송

### 4.1 단독 제작 플로우

- [ ] **T-FEAT-1**  
  **범위**: 앨범 생성 — 제목·커버·사이즈·페이지 수 등 메타데이터 입력 및 생성 API 연동.  
  **성공**: 생성 플로우에서 앨범 생성 후 서버 저장, 목록/상세에 반영.  
  **참조**: `snapfit-requirements.mdc` (Album, POST /albums), 앨범 생성 화면·ViewModel, `AlbumController`, `AlbumService`.

- [ ] **T-FEAT-2**  
  **범위**: 사진 선택 — 갤러리/카메라에서 사진 선택 후 앨범에 추가, 슬롯에 매핑.  
  **성공**: 선택한 사진이 페이지/커버 슬롯에 배치 가능, asset 업로드(presign) 연동.  
  **참조**: POST /assets/presign, Layer type IMAGE, `AlbumService`, 사진 선택 UI.

- [ ] **T-FEAT-3**  
  **범위**: 템플릿 적용 — 커버/페이지에 템플릿 선택 시 자동배치·자동크롭(비율/여백).  
  **성공**: 템플릿 선택 시 슬롯 규격에 맞게 이미지 배치·크롭, templateJson 또는 로컬 템플릿 반영.  
  **참조**: §3 템플릿 도메인, `docs/template_schema.md`, `layer_builder.dart`, `template_selection_panel.dart`, `design_template_panel.dart`.

- [ ] **T-FEAT-4**  
  **범위**: 레이어 편집 — 텍스트/스티커/프레임(이미지 테두리) 추가·수정·삭제·z-order.  
  **성공**: 레이어 스택 조작, 텍스트 내용/스타일, 스티커/프레임 선택 및 배치, 저장 시 PUT /layers 반영.  
  **참조**: `layer.dart`, `LayerType`, `layer_builder.dart`, `text_editor_manager.dart`, `layer_interaction_manager.dart`, `decorate_panel.dart`, `layer_manager_panel.dart`.

- [ ] **T-FEAT-5**  
  **범위**: 미리보기·검증 — 인쇄 규격 기반 미리보기, PDF 또는 고해상도 이미지 패키징(선택).  
  **성공**: 편집 결과를 인쇄 규격으로 확인 가능, 필요 시 export/캡처.  
  **참조**: `page_editor_canvas.dart`, 앨범 리더/미리보기 화면, Snapshot/export.

- [ ] **T-FEAT-6**  
  **범위**: 제작 사양 선택 — 사이즈·페이지 수·용지 등 옵션 선택 후 주문 데이터로 연결.  
  **성공**: 사양 선택 UI → 주문 생성 시 spec 반영.  
  **참조**: Album spec(size, pages), Order 도메인, 제작 사양 화면.

- [ ] **T-FEAT-7**  
  **범위**: 결제 — PG 연동(실물 주문), 인앱결제(디자인 상품) 선택 구현.  
  **성공**: 주문 확정 후 결제 플로우 진행, 결제 완료 시 주문 상태 갱신.  
  **참조**: POST /orders, 결제 화면·PG 연동.

- [ ] **T-FEAT-8**  
  **범위**: 주문·배송 조회 — 주문 상태(제작중/출고/배송중/완료), 송장 번호, 택배사.  
  **성공**: GET /orders/{id}/tracking 또는 동등 API로 상태·배송 정보 표시.  
  **참조**: Order 도메인, 주문/배송 조회 화면.

### 4.2 협업(공동 제작) 플로우

- [ ] **T-FEAT-9**  
  **범위**: 초대 — Owner가 앨범 멤버 초대(링크/코드/딥링크 또는 이메일·전화).  
  **성공**: POST /albums/{id}/invite 호출, 초대 링크/코드 발급·공유.  
  **참조**: `AlbumController` invite, `InviteLinkResponse`, 초대 UI.

- [ ] **T-FEAT-10**  
  **범위**: 수락 — 참여자가 초대 수락(딥링크 또는 코드 입력), 역할(Editor/Viewer) 반영.  
  **성공**: POST /albums/{id}/invite/accept 또는 /invites/{token}/accept, AlbumMember 생성·상태 ACCEPTED.  
  **참조**: `AlbumService.acceptInvite`, `album_member_api.dart`, 수락 화면.

- [ ] **T-FEAT-11**  
  **범위**: 편집 이력(감사 로그) — 저장 단위로 "누가/언제/무엇" 기록 및 조회.  
  **성공**: GET /albums/{id}/logs, 커밋 시 EditLog 생성, UI에서 이력 목록 표시.  
  **참조**: EditLog 도메인, `snapfit-requirements.mdc` (Collaboration), 로그 API·화면.

- [ ] **T-FEAT-12**  
  **범위**: Freeze(제작 확정) — Owner가 앨범 고정, 스냅샷 생성 후 주문만 가능.  
  **성공**: POST /albums/{id}/freeze → Album FROZEN, Snapshot 생성, 이후 주문 시 snapshotId 필수.  
  **참조**: Snapshot 도메인, Order MUST reference snapshotId, Freeze API·UI.

### 4.3 공통·부가 기능

- [ ] **T-FEAT-13**  
  **범위**: 페이지 락(동시 편집 방지) — 편집 중인 페이지 TTL·하트비트, 락 획득/반환.  
  **성공**: 동시 편집 시 페이지 단위 락, 이미 잠긴 페이지 안내, 저장/이탈 시 락 해제.  
  **참조**: T-ARCH-1, `AlbumLockService`, Flutter 편집기·락 UI.

- [ ] **T-FEAT-14**  
  **범위**: 권한(Role) — Owner/Editor/Viewer에 따른 편집·삭제·초대·Freeze 권한 제어.  
  **성공**: Viewer는 읽기만, Editor는 편집·Owner만 삭제·초대·Freeze 가능.  
  **참조**: AlbumMember.role, 백엔드 서비스 검증, Flutter 권한별 UI/버튼 비노출.

- [ ] **T-FEAT-15**  
  **범위**: 동적 텍스트 바인딩 — 템플릿 텍스트 레이어에 `{{workout_time}}`, `{{date}}`, `{{family_name}}` 등 치환.  
  **성공**: 렌더/저장 시 사용자 입력 또는 시스템 값으로 치환.  
  **참조**: `docs/template_schema.md` §6, `layer_builder`/텍스트 렌더링.

---

## 5. 리팩토링 (대규모)

- [ ] **T-REF-1**  
  **범위**: View–ViewModel 분리 점검. setState로 비즈니스 로직 처리하는 화면 제거.  
  **성공**: 모든 스크린이 ConsumerWidget/ConsumerStatefulWidget + ref.watch/ref.listen, 비즈니스 로직은 Notifier/AsyncNotifier.  
  **참조**: `.cursor/rules/snapfit-technical.mdc`, `.cursor/agents/riverpod-architect.md`, `lib/features/**/presentation/views/*.dart`.

- [ ] **T-REF-2**  
  **범위**: 50줄 이상/private 위젯을 `widgets/{screen_name}/`으로 분리.  
  **성공**: `*_screen.dart`는 구조만, 복잡 위젯은 widgets 하위로 이전.  
  **참조**: `.cursor/rules/widget-component-separation.mdc`, `lib/features/**/presentation/views/*_screen.dart`.

- [ ] **T-REF-3**  
  **범위**: 디자인 템플릿(design_templates.dart)과 페이지 템플릿(page_templates.dart)을 통합 스키마(template_schema.md) 기반 JSON 또는 공통 레이어 빌더로 점진 이전.  
  **성공**: 새 템플릿 추가 시 스키마 기반 단일 경로 사용, 기존 코드는 호환 유지 또는 단계적 제거.  
  **참조**: `docs/template_schema.md`, `design_templates.dart`, `page_templates.dart`, `layer_builder.dart`.

- [ ] **T-REF-4**  
  **범위**: API·저장소 계층 정리. Retrofit 인터페이스와 Repository 분리, 에러/재시도 정책 일원화.  
  **성공**: 모든 원격 호출이 Retrofit 경유, Repository가 AsyncValue/예외 변환 담당.  
  **참조**: `lib/features/*/data/api/*.dart`, `lib/features/*/data/repository`, `snapfit-technical.mdc`.

---

## 6. 보안

- [ ] **T-SEC-1**  
  **범위**: JWT·리프레시·사용자 자격증명이 오직 flutter_secure_storage에만 저장되는지 검사.  
  **성공**: SharedPreferences/파일에 토큰·비밀번호 없음.  
  **참조**: `.cursor/agents/security-quality-auditor.md`, `lib/**/*storage*`, `lib/**/*auth*`, `lib/core/interceptors/token_storage.dart`.

- [ ] **T-SEC-2**  
  **범위**: 하드코딩된 API 키·시크릿·Bearer 토큰 검색 및 제거.  
  **성공**: base URL·키는 .env 또는 빌드 시 주입, 코드 내 문자열 없음.  
  **참조**: `security-quality-auditor.md`, `lib/`, `SnapFit-BackEnd/`.  
  **참고**: `lib/config/env.dart`에 Kakao/Google 기본값 있음 — 프로덕션은 dart-define 필수. `lib/firebase_options.dart`는 FlutterFire 생성 파일(클라이언트 키).

- [ ] **T-SEC-3**  
  **범위**: 로그에 토큰·비밀번호·PII 출력 여부 점검.  
  **성공**: 로그 메시지에 민감 정보 없음. `print()`/`debugPrint()`에 예외 객체만 넣지 않기(스택/메시지에 토큰 포함 가능).  
  **참조**: `snapfit-technical.mdc` (No tokens in logs), `lib/core/utils/screen_logger.dart`, `layer_interaction_manager.dart`, `album_editor_view_model.dart`, `dio_client.dart`.

- [ ] **T-SEC-4**  
  **범위**: 백엔드 — 변경·삭제·생성 API에서 JWT 검증 후 userId는 토큰에서 추출. Query/Body의 userId만 신뢰하지 않기.  
  **성공**: SecurityConfig에서 POST/PUT/DELETE 등 쓰기 API는 authenticated, Controller에서 SecurityContext 또는 JwtProvider로 userId 획득.  
  **참조**: `SecurityConfig.java` (현재 `/api/albums/**`, `/api/templates/**` 전부 permitAll), `TemplateController`, `AlbumController`, `JwtAuthenticationFilter`/`JwtProvider`.

- [ ] **T-SEC-5**  
  **범위**: AuthResponse 등 토큰 포함 DTO의 toString/로그 노출 방지. Freezed 생성 toString이 accessToken/refreshToken을 그대로 포함함.  
  **성공**: AuthResponse(및 유사 DTO)에 custom toString으로 토큰 필드 마스킹 또는 로깅 시 해당 객체 직접 출력 금지 규칙.  
  **참조**: `lib/features/auth/data/dto/auth_response.dart`, `auth_response.freezed.dart` (생성 toString).

- [ ] **T-SEC-6**  
  **범위**: env.dart 기본값 — 프로덕션 빌드에서는 BASE_URL·Kakao·Google 등 dart-define으로 덮어쓰기. 기본값은 개발용만 사용하도록 문서화 또는 기본값 제거.  
  **성공**: README 또는 배포 가이드에 프로덕션 dart-define 목록 명시, 공개 저장소 시 기본값에 실서비스 키 없음.  
  **참조**: `lib/config/env.dart`.

---

## 7. 아키텍처

- [ ] **T-ARCH-1**  
  **범위**: 협업 MVP — 페이지 락(TTL 2–5분, heartbeat) + 저장 시 EditLog.  
  **성공**: 동시 편집 시 페이지 락 획득/반환, 커밋 시 EditLog 생성.  
  **참조**: `.cursor/rules/snapfit-requirements.mdc` (Collaboration Rules), BackEnd AlbumLockService, Flutter 편집기.

- [ ] **T-ARCH-2**  
  **범위**: 주문이 반드시 snapshotId 참조하도록 검증. Freeze 시 스냅샷 생성, 주문 생성 시 snapshotId 필수.  
  **성공**: Order 도메인에서 snapshotId 없이 주문 생성 불가.  
  **참조**: `snapfit-requirements.mdc` (Data Model: Snapshot, Order), BackEnd Order 서비스/엔티티.

- [ ] **T-ARCH-3**  
  **범위**: Flutter–BackEnd API/DTO 동기화 정리. Controller ↔ Retrofit, DTO 필드·타입(Long→int, LocalDateTime→String) 일치.  
  **성공**: 모든 엔드포인트가 full-stack-sync-master 체크리스트 통과.  
  **참조**: `.cursor/agents/full-stack-sync-master.md`, `.cursor/skills/snapfit-specialized-skills/SKILL.md`, TemplateController ↔ template_api + PremiumTemplate.

- [ ] **T-ARCH-4**  
  **범위**: 에러 처리 일원화. AsyncValue + 사용자 친화 한글 메시지, ref.listen으로 Snackbar/네비게이션.  
  **성공**: API/저장소 실패 시 AsyncError, View에서 ref.listen으로 메시지 표시, mounted 체크.  
  **참조**: `snapfit-technical.mdc`, `riverpod-architect.md`, `lib/features/**/presentation/**/*.dart`.

- [ ] **T-ARCH-5**  
  **범위**: 백엔드 입력 검증. DTO에 @Valid, @Size, @NotBlank 등으로 요청 바디/파라미터 검증, SQL/NoSQL 인젝션·과대 페이로드 방지.  
  **성공**: 쓰기 API 요청에 검증 적용, 실패 시 400 + 명확한 메시지.  
  **참조**: SnapFit-BackEnd Controller/DTO, Spring Validation.

---

## 8. 기타 (테스트·로깅·빌드)

- [ ] **T-MISC-1**  
  **범위**: 새 스크린/주요 위젯에 ScreenLogger.enter / ScreenLogger.widget 1회 호출 추가.  
  **성공**: presentation 하위 새 스크린·분리 위젯에 로그 추가, 규칙 준수.  
  **참조**: `.cursor/rules/snapfit-screen-logging.mdc`, `lib/core/utils/screen_logger.dart`.

- [ ] **T-MISC-2**  
  **범위**: 수정된 @freezed/@RestApi/@JsonSerializable 적용 후 build_runner 실행.  
  **성공**: `dart run build_runner build --delete-conflicting-outputs` 후 .g.dart/.freezed.dart 정상 생성.  
  **참조**: `.cursor/skills/snapfit-specialized-skills/SKILL.md`.

- [ ] **T-MISC-3**  
  **범위**: 핵심 플로우 유닛/위젯 테스트 추가.  
  **성공**: pumpSnapFitApp + override 사용, 실제 API 호출 없음.  
  **참조**: `.cursor/rules/snapfit-testing.mdc`, `test/helpers/`, `TESTING.md`.

- [ ] **T-MISC-4**  
  **범위**: 디버그용 `print()` → `debugPrint()` 또는 ScreenLogger로 통일. 로그에 예외/객체 직접 넣지 않기(토큰·초대 링크 등 유출 가능).  
  **성공**: `lib/` 내 `print(` 제거 또는 debugPrint/kDebugMode 조건, 민감 필드 미포함.  
  **참조**: `layer_interaction_manager.dart`, `album_editor_view_model.dart`, `dio_client.dart`, `snapfit-screen-logging.mdc`.

- [ ] **T-MISC-5**  
  **범위**: 의존성 보안 점검. `flutter pub audit`, `dart pub outdated` 및 BackEnd dependency-check/CVE 스캔.  
  **성공**: 알려진 취약점 제거 또는 문서화된 예외.  
  **참조**: 프로젝트 루트, `pubspec.yaml`, BackEnd `pom.xml`.

---

## 9. 추가로 보안·품질 시 유의할 점 (체크리스트)

| 항목 | 설명 | 참고 |
|------|------|------|
| 초대 링크 토큰 | `InviteLinkResponse.token` 등 초대용 토큰을 로그/에러 메시지에 포함하지 않기 | `invite_link_response.dart`, API 호출부 |
| Freezed toString | 토큰·비밀번호 필드가 있는 모델은 toString 오버라이드로 마스킹 | T-SEC-5 |
| 백엔드 permitAll | GET은 공개 가능, POST/PUT/DELETE는 JWT 필수 + userId는 토큰에서 추출 | T-SEC-4, `SecurityConfig.java` |
| env 기본값 | 프로덕션에서는 dart-define으로 BASE_URL·OAuth 클라이언트 ID 등 덮어쓰기 | `lib/config/env.dart`, T-SEC-6 |
| Firebase 옵션 | `firebase_options.dart`는 FlutterFire CLI 생성; 클라이언트 키는 공개 용도. 추가 시크릿은 .env | `lib/firebase_options.dart` |

---

## 10. 태스크 진행 순서 제안

1. **보안** (T-SEC-1~6) — 저장소·하드코딩·로그·백엔드 인증·toString·env 기본값.  
2. **템플릿 정합성** (T-TEMPLATE-1~3) — 스키마·API·플로우 안정화.  
3. **기능** (T-FEAT-1~15) — 단독 제작(앨범·사진·템플릿·레이어·미리보기·사양·결제·배송) + 협업(초대·수락·이력·Freeze) + 페이지 락·권한·바인딩.  
4. **아키텍처** (T-ARCH-1~5) — 협업·스냅샷·API 동기화·에러 처리·백엔드 입력 검증.  
5. **리팩토링** (T-REF-1~4) — MVVM·위젯 분리·템플릿 통합·API 계층.  
6. **기타** (T-MISC-1~5) — 로깅·빌드·테스트·print 정리·의존성 감사.

---

*마지막 업데이트: 기능(Feature) 섹션 추가 (T-FEAT-1~15, 플로우·요구사항 기준).*
