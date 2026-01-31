# SnapFit 테스트 가이드

## 테스트 실행

```bash
# 전체 테스트
flutter test

# 특정 디렉터리만
flutter test test/unit/
flutter test test/widget/

# 특정 파일
flutter test test/unit/cover_size_test.dart
```

## 디렉터리 구조

```
test/
├── helpers/           # 공통 유틸
│   ├── pump_app.dart      # 테스트용 앱 pump (ProviderScope, ScreenUtil, MaterialApp)
│   ├── fake_album.dart    # 테스트용 Album fixture
│   └── mock_repositories.dart  # MockAlbumRepository, stub 헬퍼
├── unit/              # 순수 로직 유닛 테스트
│   ├── cover_size_test.dart
│   └── layer_export_mapper_test.dart
├── widget/            # 위젯/화면 테스트
│   └── home_screen_test.dart
└── widget_test.dart   # 앱 부팅 스모크
```

## 새 테스트 추가하기

### 1. 유닛 테스트 (domain/data 로직)

- `test/unit/` 아래에 `*_test.dart` 추가.
- 외부 의존(API, DB) 없이 순수 함수/매퍼/유틸만 테스트.

예: `LayerExportMapper`, `CoverSize` 상수, validator 등.

### 2. 위젯 테스트 (화면/컴포넌트)

- `test/widget/` 아래에 `*_test.dart` 추가.
- `pumpSnapFitApp(tester, overrides: [...])` 로 앱을 띄운 뒤 `find`, `tap` 등으로 검증.

**Provider override 예시**

```dart
final mockRepo = MockAlbumRepository();
stubFetchMyAlbums(mockRepo, [fakeAlbum(id: 1)]);

await pumpSnapFitApp(tester, overrides: [
  albumRepositoryProvider.overrideWithValue(mockRepo),
]);

expect(find.text('앨범 #1'), findsOneWidget);
```

- API/저장소를 쓰는 화면은 반드시 해당 provider를 override 해서 네트워크 호출을 막고, 예측 가능한 데이터로 검증.

### 3. Fixture / Mock 추가

- **Fixture**: `test/helpers/fake_*.dart` 에서 도메인 객체 생성 헬퍼 추가.
- **Mock**: `mocktail` 사용. `MockX extends Mock implements X` 후 `when(() => mock.method(any())).thenAnswer(...)` 로 stub.

```dart
when(mock.fetchMyAlbums).thenAnswer((_) async => [fakeAlbum()]);
when(() => mock.deleteAlbum(any())).thenAnswer((_) async {});
```

## 유지보수 팁

1. **의존성 주입**: `AlbumRepository` 등은 인터페이스로 두고, 구현체는 Provider에서 주입. 테스트 시 `overrideWithValue` 로 mock 주입.
2. **비즈니스 로직 분리**: 복잡한 로직은 ViewModel/Service/매퍼로 빼고, 유닛 테스트로 검증. UI는 위젯 테스트로 동작만 확인.
3. **생성 코드 제외**: `analysis_options.yaml` 에서 `*.g.dart`, `*.freezed.dart` exclude. 린트 에러는 보통 소스 쪽 수정으로 해결.

## 코드 유지보수

- **폴더 구조**: `lib/features/<feature>/data|domain|presentation` 유지. 비슷한 역할끼리 묶어두면 테스트·리팩터 시 찾기 쉽습니다.
- **추상화**: Repository, API 클라이언트 등은 인터페이스(abstract class)로 두고 구현체를 Provider로 주입. 테스트·교체가 수월해집니다.
- **상수/설정**: `lib/core/constants/` 에 `CoverSize`, 테마 등 공통 상수 두기. 유닛 테스트에서 그대로 사용할 수 있습니다.
- **린트**: `flutter analyze` 로 경고를 0에 가깝게 유지. `analysis_options.yaml` 에서 `*.g.dart`, `*.freezed.dart` 는 제외해 두었습니다.

## 참고

- [Flutter testing](https://docs.flutter.dev/testing)
- [Riverpod testing](https://riverpod.dev/docs/essentials/testing)
- [mocktail](https://pub.dev/packages/mocktail)
