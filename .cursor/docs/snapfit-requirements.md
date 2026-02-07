# SnapFit (스냅핏) — 비즈니스/요구사항 문서

> Cursor AI 규칙: `.cursor/rules/snapfit-requirements.mdc`  
> 이 파일은 팀원용 상세 문서입니다.

> 목적: SnapFit 개발을 위한 비즈니스 요구사항(문제/해결/수익/협업)과 아키텍처·데이터 흐름.  
> 스택: **Flutter(Riverpod+Dio/Retrofit+MVVM)**, **Spring Boot+JWT**, **MariaDB**, **S3**, (선택) **Redis**, **Queue/Worker**.

---

## 1) 서비스가 해결하는 문제(Problem)
1. 모바일에서 포토북/앨범 편집은 **시간이 오래 걸리고** 크롭/정렬/여백 등 반복 작업이 많아 이탈이 발생한다.
2. 결과물 퀄리티가 사용자 역량에 의존해 **완성도 하한이 낮고**, 제작 전환이 떨어진다.
3. 편집→제작→결제→배송조회 흐름이 분리/복잡하면 **결제 직전 이탈**이 커진다.
4. 가족/연인/친구 단위로 함께 사진을 모아 앨범을 만들고 싶지만, 대부분 서비스는 **공동 편집 + 이력 추적**이 약하다.

---

## 2) 해결(핵심 가치 제안)
- 템플릿 기반 자동완성(자동배치/자동크롭) + 레이어 편집(텍스트/스티커/프레임/배경/스파인/그림자)으로 **고품질 결과물**을 빠르게 만든다.
- 편집→주문→결제→배송조회까지 **원스톱 제작 플로우**를 제공한다.
- 앨범 단위로 사용자를 초대하여 **공동 편집**을 지원하고, "누가/언제/무엇을" 편집했는지 **감사 로그(편집 이력)**를 제공한다.
- 주문 직전에는 최종본을 **Freeze(제작 확정 스냅샷)**로 고정하여 분쟁/오류를 줄인다.

---

## 3) 비즈니스 모델(BM)
- 실물 제작 주문 마진(포토북/앨범): 주문당 마진 확보
- 인앱결제(디자인 상품): 프리미엄 템플릿/폰트/스티커/컬러 팔레트
- 확장: B2B 단체 주문(유치원/스튜디오/행사) + 정산/견적

---

## 4) 핵심 사용자 시나리오(Flow)
### A. 단독 제작
1) 앨범 생성 → 2) 사진 선택 → 3) 템플릿 적용(자동배치/크롭) → 4) 레이어 편집 →  
5) 미리보기/검증 → 6) 제작 사양 선택 → 7) 결제 → 8) 주문 상태/배송조회

### B. 공동 제작(협업)
1) 앨범 생성(Owner) → 2) 초대 링크/코드 발송 → 3) 참여자 수락(Editor/Viewer) →  
4) 참여자가 사진 추가/페이지 편집 → 5) 편집 이력 기록(누가/언제/무엇) →  
6) Owner가 Freeze(제작 확정) → 7) 결제/주문 → 8) 배송조회

---

## 5) 기능 요구사항(Functional Requirements)
### 5.1 앨범/페이지/레이어 편집
- 앨범: 제목/커버/사이즈/페이지 수(예: 24p) 등 메타데이터 관리
- 페이지: 레이아웃 템플릿, 사진 슬롯, 레이어 스택(텍스트/스티커/프레임)
- 자동배치/자동크롭: 템플릿 규격 기반으로 이미지 맞춤(비율/여백)
- 미리보기: 인쇄 규격 기반 렌더링(PDF 또는 고해상도 이미지 패키징)

### 5.2 공유/협업(핵심 차별성)
- 초대/수락: 초대 링크/코드(딥링크), 또는 이메일/전화번호 기반 초대
- 권한(Role): Owner / Editor / Viewer
- 공동 편집:
  - 최소 MVP: **페이지 단위 잠금(Page Lock)** 또는 **작업 중 표시 + 충돌 방지**
  - 저장 단위(커밋)로 변경 이력 생성
- 편집 이력(감사 로그): "누가/언제/무엇을 변경했는지" 이벤트 기록/조회

### 5.3 주문/결제/배송
- 주문 생성: Freeze 스냅샷 기반으로 주문 데이터 생성(변경 불가)
- 결제: PG(실물 주문), 인앱결제(디자인 상품)
- 배송조회: 주문 상태(제작중/출고/배송중/완료), 송장 번호, 택배사 연동(초기 수동 가능)

---

## 6) 비기능 요구사항(Non-Functional Requirements)
- 성능: 편집 화면에서 이미지/레이어 조작이 끊기지 않게(캐싱/압축/프리뷰)
- 안정성: 주문 데이터는 Freeze 스냅샷으로 일관성 보장(재현 가능)
- 보안: JWT 인증, 권한(Role) 체크, 파일 접근은 Signed URL 또는 프록시 다운로드
- 확장성: 이미지 원본 S3, 렌더링/패키징은 백그라운드 작업(Worker) 고려
- 감사성: 편집 이력은 삭제 불가(관리자만 정책적으로 마스킹/비활성)

---

## 7) 간단 아키텍처(High-Level)
### 7.1 컴포넌트
- Flutter App: UI, ViewModel(MVVM)+Riverpod, Dio/Retrofit API
- Spring Boot API: Auth(JWT), Album, Collaboration, Order, Payment
- MariaDB, Object Storage(S3), (선택) Worker/Queue, Redis

### 7.2 데이터 흐름(Data Flow)
1) 사진 업로드: App → API(서명 URL) → S3 → API 메타 저장  
2) 편집 저장: App → API(JSON) → DB  
3) 협업: DB + Audit Log  
4) Freeze: 스냅샷 → S3 → DB  
5) 주문: snapshot_id → 결제 → 배송

---

## 8) 최소 데이터 모델
- User, Album, AlbumMember, Page, Layer, Asset, EditLog, Snapshot, Order  
(상세 필드는 snapfit-requirements.mdc 참고)

---

## 9) API(예시, 최소)
- POST /auth/login, /auth/refresh
- POST /albums, GET /albums/{id}
- POST /albums/{id}/invite, /albums/{id}/invite/accept
- GET /albums/{id}/members
- PUT /pages/{id}, PUT /layers/{id}, POST /assets/presign
- GET /albums/{id}/logs, POST /albums/{id}/freeze
- POST /orders, GET /orders/{id}/tracking

---

## 10) 협업 충돌/잠금
- MVP: 페이지 단위 잠금 (TTL 2~5분, 하트비트). 커밋 → EditLog.

## 11) Freeze 룰
- FROZEN 상태, 스냅샷 생성. Order는 snapshotId 필수.

## 12~14) 운영/KPI/작업 룰
- 리드타임, 불량 기준, SLA, KPI 등 (상세는 원문 참고)
- **항상 요구사항·플로우·데이터 모델을 먼저 확인** 후 코드 변경 제안.
