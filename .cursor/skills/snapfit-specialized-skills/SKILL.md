---
name: snapfit-specialized-skills
description: Manages build_runner workflows for @freezed/@JsonSerializable/@RestApi, synchronizes Spring Boot and Flutter APIs (Retrofit + Freezed DTOs), and designs Riverpod state with AsyncValue and ref.listen for side effects. Use when modifying generated Dart code, adding API endpoints, or implementing ViewModel state flows in SnapFit.
---

# SnapFit Agent Specialized Skills

## 1. BuildRunner Workflow

### When to Run

Run build_runner when any of these are modified:
- Files with `@freezed`, `@Freezed()` (domain entities, DTOs, states)
- Files with `@JsonSerializable`, `@JsonKey` (JSON serialization)
- Files with `@RestApi()` (Retrofit API interfaces)
- Files with `@Riverpod()` (riverpod_annotation)

### Command

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Triggers

After modifying a file that contains:
- `part '*.freezed.dart'` or `part '*.g.dart'`
- `@RestApi()`, `@GET`, `@POST`, `@PUT`, `@DELETE`
- `@freezed` or `@Freezed()`
- `@JsonSerializable` or `@JsonKey`

Proactively suggest: "이 파일을 수정했으니 `dart run build_runner build --delete-conflicting-outputs`를 실행할까요?"

---

## 2. Cross-Stack API Synchronization (Spring Boot ↔ Flutter)

### Purpose

Spring Boot 백엔드(SnapFit-BackEnd)와 Flutter 프론트엔드 간 API/타입 정합성 유지.

### Workflow

1. **Spring Boot Controller 분석**
   - `@RestController`, `@RequestMapping`, `@GetMapping` 등
   - `@PathVariable`, `@RequestParam`, `@RequestBody` 파라미터
   - 반환 타입(ResponseEntity<T>, List<T> 등)

2. **타입 매핑 규칙**

   | Java (Spring Boot) | Dart (Flutter) |
   |-------------------|----------------|
   | `Long` | `int` |
   | `Integer` | `int` |
   | `String` | `String` |
   | `LocalDateTime` | `String` (ISO 8601, `yyyy-MM-dd'T'HH:mm:ss`) |
   | `List<T>` | `List<T>` |
   | `@JsonProperty("x")` | `@JsonKey(name: 'x')` |
   | `albumId` (Long) | `@JsonKey(name: 'albumId') int id` |

3. **Retrofit API 생성**
   - 경로: `lib/features/{feature}/data/api/`
   - `@RestApi()` 추상 클래스
   - `@GET`, `@POST`, `@PUT`, `@DELETE` + `@Path`, `@Query`, `@Body`
   - 반환: `Future<T>` 또는 `Future<List<T>>`

4. **Freezed DTO 생성**
   - Request: `lib/features/{feature}/data/dto/request/`
   - Response/Entity: `lib/features/{feature}/domain/entities/` 또는 `data/dto/response/`
   - `@freezed` + `@JsonSerializable` (JsonKey로 필드명 매핑)
   - `factory X.fromJson(Map<String, dynamic> json)` 포함

### 참고: SnapFit 프로젝트 구조

- 백엔드: `SnapFit-BackEnd/src/main/java/com/snapfit/snapfitbackend/`
- Flutter: `lib/features/album/data/api/`, `domain/entities/`, `data/dto/`

---

## 3. Riverpod State Architect

### AsyncValue 패턴

모든 비동기 상태는 `AsyncValue<T>`로 표현:
- `AsyncLoading` — 로딩 중
- `AsyncData<T>` — 성공
- `AsyncError(e, st)` — 실패

```dart
@override
FutureOr<T> build() async {
  // 초기 로드 또는 빌드
  return await repository.fetch();
}

// 메서드에서 상태 업데이트
state = const AsyncLoading();
try {
  final result = await repository.save(...);
  state = AsyncData(result);
} catch (e, st) {
  state = AsyncError(e, st);
}
```

### ref.listen으로 사이드 이펙트 처리

**필수**: `ref.listen`으로 상태 변화에 따른 사이드 이펙트(Snackbar, Navigator) 처리. build() 내부에서 직접 처리하지 말 것.

**Context 필요 시** (Snackbar, Navigator): ConsumerStatefulWidget의 build()에서 `ref.listen` 사용.

```dart
@override
Widget build(BuildContext context) {
  ref.listen<AsyncValue<Album?>>(albumViewModelProvider, (previous, next) {
    next.when(
      data: (album) {
        if (album != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('저장되었습니다.')),
          );
          Navigator.pop(context);
        }
      },
      error: (err, st) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('오류: $err')),
          );
        }
      },
      loading: () {},
    );
  });
  // ...
}
```

**Context 불필요 시** (로깅, 분석): 별도 Provider에서 `ref.listen` 또는 ViewModel 내부 처리.

### 체크리스트

- [ ] View는 `ref.watch`로 UI 렌더링, `ref.listen`으로 사이드 이펙트
- [ ] 비즈니스 로직은 ViewModel, UI 로직은 View에 유지
- [ ] `mounted` 체크 후 Navigator/ScaffoldMessenger 사용
- [ ] 에러 메시지는 사용자 친화적으로 변환 (Exception → 한글 메시지)
