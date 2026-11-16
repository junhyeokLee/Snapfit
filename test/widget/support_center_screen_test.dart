import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/profile/data/support_inquiry_repository.dart';
import 'package:snap_fit/features/profile/domain/support_inquiry.dart';
import 'package:snap_fit/features/profile/presentation/views/support_center_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/support_inquiry_screen.dart';

typedef SupportHistoryRead = ({String ownerId, int? beforeId, int limit});

const supportHistoryOwner = 'support-owner-a';
const _account = UserInfo(
  id: supportHistoryOwner,
  name: '문의 검토 계정',
  email: 'support-review@example.test',
  provider: 'EMAIL',
);

SupportInquiry supportHistoryInquiry(
  int id, {
  String owner = supportHistoryOwner,
  String? subject,
  String? message,
  String category = 'BUG',
  String status = 'OPEN',
}) => SupportInquiry(
  id: id,
  userId: owner,
  category: category,
  subject: subject ?? '앨범 편집 문의 $id',
  message: message ?? '사진을 프레임에 넣을 때 확인할 내용 $id',
  status: status,
  createdAt: DateTime.utc(2026, 11, 12, 2, id % 60),
);

class SupportHistoryAuth extends AuthViewModel {
  SupportHistoryAuth({this.initialOwner = supportHistoryOwner});
  final String? initialOwner;

  @override
  FutureOr<UserInfo?> build() =>
      initialOwner == null ? null : _account.copyWith(id: initialOwner!);

  void owner(String? value) =>
      state = AsyncData(value == null ? null : _account.copyWith(id: value));
}

/// 실제 고객센터 UI를 검증하되 외부 문의나 계정 요청은 보내지 않는다.
class SupportHistoryMemoryRepository extends Fake
    implements SupportInquiryRepository {
  SupportHistoryMemoryRepository({
    this.currentUserId = supportHistoryOwner,
    List<SupportInquiry> inquiries = const [],
  }) : inquiries = List.of(inquiries);

  @override
  String? currentUserId;
  final List<SupportInquiry> inquiries;
  final reads = <SupportHistoryRead>[];
  final submissions = <({String category, String subject, String message})>[];
  final _owners = StreamController<String?>.broadcast(sync: true);
  FutureOr<SupportInquiryPage> Function(SupportHistoryRead)? onRead;
  Future<void>? pendingSubmission;
  Object? submissionError;

  @override
  Stream<String?> get authChanges => _owners.stream;

  void owner(String? value) {
    currentUserId = value;
    _owners.add(value);
  }

  Future<void> close() => _owners.close();

  @override
  Future<SupportInquiryPage> fetchMyInquiries({
    required String ownerId,
    int? beforeId,
    int limit = 20,
  }) async {
    final request = (ownerId: ownerId, beforeId: beforeId, limit: limit);
    reads.add(request);
    if (onRead != null) return await onRead!(request);
    final matching =
        inquiries
            .where(
              (entry) =>
                  entry.userId == ownerId &&
                  (beforeId == null || entry.id < beforeId),
            )
            .toList()
          ..sort((a, b) => b.id.compareTo(a.id));
    return SupportInquiryPage(
      items: matching.take(limit).toList(),
      hasMore: matching.length > limit,
    );
  }

  @override
  Future<void> createInquiry({
    required String category,
    required String subject,
    required String message,
  }) async {
    submissions.add((category: category, subject: subject, message: message));
    await pendingSubmission;
    if (submissionError != null) throw submissionError!;
    final nextId =
        inquiries.fold<int>(100, (id, row) => id > row.id ? id : row.id) + 1;
    inquiries.add(
      supportHistoryInquiry(
        nextId,
        owner: currentUserId ?? supportHistoryOwner,
        category: category,
        subject: subject,
        message: message,
      ),
    );
  }
}

class SupportCenterFixture {
  SupportCenterFixture({
    SupportHistoryMemoryRepository? repository,
    String? owner = supportHistoryOwner,
  }) : repository = repository ?? SupportHistoryMemoryRepository(),
       auth = SupportHistoryAuth(initialOwner: owner);

  final SupportHistoryMemoryRepository repository;
  final SupportHistoryAuth auth;
  late ProviderContainer container;

  void changeOwner(String? value) {
    repository.owner(value);
    auth.owner(value);
  }
}

/// 캡처에서도 같은 앱 테마·계정·실제 화면을 재사용한다.
Future<void> mountSupportCenter(
  WidgetTester tester,
  SupportCenterFixture fixture, {
  Size size = const Size(390, 844),
  bool dark = false,
  double scale = 1,
  GlobalKey? capture,
  bool settle = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = size.width > size.height
      ? const FakeViewPadding(left: 24, right: 24, bottom: 20)
      : const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetPadding);
  SharedPreferences.setMockInitialValues({});
  fixture.container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      authViewModelProvider.overrideWith(() => fixture.auth),
      supportInquiryRepositoryProvider.overrideWithValue(fixture.repository),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    fixture.container.dispose();
    await fixture.repository.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: fixture.container,
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: (dark ? SnapFitTheme.dark() : SnapFitTheme.light()).copyWith(
            splashFactory: NoSplash.splashFactory,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: capture == null
                ? child!
                : RepaintBoundary(key: capture, child: child!),
          ),
          home: const SupportCenterScreen(),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _key(String value) => find.byKey(ValueKey(value));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

VoidCallback _action(WidgetTester tester, String key) {
  final widget = tester.widget(_key(key));
  if (widget is ButtonStyleButton) return widget.onPressed!;
  if (widget is IconButton) return widget.onPressed!;
  throw StateError('검증할 실제 버튼이 아닙니다: $key');
}

void main() {
  testWidgets(
    'a pending first inquiry load never looks like an empty history',
    (tester) async {
      final pending = Completer<SupportInquiryPage>();
      final repository = SupportHistoryMemoryRepository()
        ..onRead = (_) => pending.future;
      final fixture = SupportCenterFixture(repository: repository);
      await mountSupportCenter(tester, fixture, settle: false);
      expect(find.text('고객센터'), findsOneWidget);
      expect(find.text('아직 보낸 문의가 없어요'), findsNothing);
      expect(repository.reads.single.ownerId, supportHistoryOwner);
      pending.complete(const SupportInquiryPage(items: [], hasMore: false));
      await tester.pumpAndSettle();
      expect(find.text('아직 보낸 문의가 없어요'), findsOneWidget);
      expect(_key('support-history-new').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed inquiry history retries without claiming no inquiries', (
    tester,
  ) async {
    final repository = SupportHistoryMemoryRepository();
    repository.onRead = (_) {
      if (repository.reads.length == 1) throw StateError('fixture offline');
      return SupportInquiryPage(
        items: [supportHistoryInquiry(60)],
        hasMore: false,
      );
    };
    await mountSupportCenter(
      tester,
      SupportCenterFixture(repository: repository),
    );
    expect(find.text('문의 내역을 불러오지 못했어요'), findsOneWidget);
    expect(find.text('아직 보낸 문의가 없어요'), findsNothing);
    await _tap(tester, _key('support-history-retry'));
    expect(find.text('앨범 편집 문의 60'), findsOneWidget);
    expect(_key('support-history-retry'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening a history row shows the sent content and real status', (
    tester,
  ) async {
    final repository = SupportHistoryMemoryRepository(
      inquiries: [
        supportHistoryInquiry(60, status: 'IN_PROGRESS'),
        supportHistoryInquiry(59, status: 'RESOLVED'),
      ],
    );
    await mountSupportCenter(
      tester,
      SupportCenterFixture(repository: repository),
    );
    expect(find.text('확인 중'), findsOneWidget);
    expect(find.text('처리 완료'), findsOneWidget);
    expect(_key('support-inquiry-body-60').hitTestable(), findsNothing);
    await _tap(tester, _key('support-inquiry-60'));
    expect(_key('support-inquiry-body-60').hitTestable(), findsOneWidget);
    expect(find.text('사진을 프레임에 넣을 때 확인할 내용 60'), findsWidgets);
    expect(find.byType(SupportCenterScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed older inquiries retain rows and retry the same cursor', (
    tester,
  ) async {
    final repository = SupportHistoryMemoryRepository();
    repository.onRead = (read) {
      if (read.beforeId == null) {
        return SupportInquiryPage(
          items: [supportHistoryInquiry(60), supportHistoryInquiry(59)],
          hasMore: true,
        );
      }
      if (repository.reads.length == 2) throw StateError('older page offline');
      return SupportInquiryPage(
        items: [supportHistoryInquiry(58)],
        hasMore: false,
      );
    };
    await mountSupportCenter(
      tester,
      SupportCenterFixture(repository: repository),
    );
    await _tap(tester, _key('support-history-more'));
    expect(_key('support-inquiry-60'), findsOneWidget);
    expect(_key('support-inquiry-59'), findsOneWidget);
    await _tap(tester, _key('support-history-more-retry'));
    expect(repository.reads.map((read) => read.beforeId), [null, 59, 59]);
    expect(repository.reads.every((read) => read.limit == 20), isTrue);
    expect(_key('support-inquiry-58'), findsOneWidget);
    expect(_key('support-inquiry-60'), findsOneWidget);
    expect(_key('support-history-more'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'refresh keeps the last inquiry visible until the new read settles',
    (tester) async {
      final pending = Completer<SupportInquiryPage>();
      final repository = SupportHistoryMemoryRepository(
        inquiries: [supportHistoryInquiry(60)],
      );
      await mountSupportCenter(
        tester,
        SupportCenterFixture(repository: repository),
      );
      repository.onRead = (_) => pending.future;
      _action(tester, 'support-history-refresh')();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('앨범 편집 문의 60'), findsOneWidget);
      expect(find.text('아직 보낸 문의가 없어요'), findsNothing);
      pending.complete(
        SupportInquiryPage(items: [supportHistoryInquiry(61)], hasMore: false),
      );
      await tester.pumpAndSettle();
      expect(find.text('앨범 편집 문의 61'), findsOneWidget);
      expect(find.text('앨범 편집 문의 60'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a confirmed submission returns to durable history exactly once',
    (tester) async {
      final saved = Completer<void>();
      final repository = SupportHistoryMemoryRepository()
        ..pendingSubmission = saved.future;
      await mountSupportCenter(
        tester,
        SupportCenterFixture(repository: repository),
      );
      await _tap(tester, _key('support-history-new'));
      expect(find.byType(SupportInquiryScreen), findsOneWidget);
      await tester.enterText(_key('support-subject'), '새로 보낸 편집 문의');
      await tester.enterText(
        _key('support-message'),
        '프레임을 바꾼 뒤 사진이 적용되지 않아요.',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(_key('support-submit'));
      final submit = _action(tester, 'support-submit');
      submit();
      submit();
      await tester.pump(const Duration(milliseconds: 100));
      expect(repository.submissions.length, 1);
      expect(find.byType(SupportInquiryScreen), findsOneWidget);
      saved.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SupportInquiryScreen), findsNothing);
      expect(find.byType(SupportCenterScreen), findsOneWidget);
      expect(find.text('새로 보낸 편집 문의'), findsOneWidget);
      expect(repository.reads.length, 2);
      await _tap(tester, _key('support-inquiry-101'));
      expect(find.text('프레임을 바꾼 뒤 사진이 적용되지 않아요.'), findsWidgets);
      expect(repository.submissions.single, (
        category: 'GENERAL',
        subject: '새로 보낸 편집 문의',
        message: '프레임을 바꾼 뒤 사진이 적용되지 않아요.',
      ));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an old pending query cannot paint after the SDK account cycles A B A',
    (tester) async {
      final pending = Completer<SupportInquiryPage>();
      final repository = SupportHistoryMemoryRepository()
        ..onRead = (_) => pending.future;
      final fixture = SupportCenterFixture(repository: repository);
      await mountSupportCenter(tester, fixture, settle: false);
      final newInquiry = _action(tester, 'support-history-new');
      fixture.changeOwner('support-owner-b');
      fixture.changeOwner(supportHistoryOwner);
      await tester.pump(const Duration(milliseconds: 100));
      pending.complete(
        SupportInquiryPage(items: [supportHistoryInquiry(60)], hasMore: false),
      );
      await tester.pumpAndSettle();
      newInquiry();
      await tester.pumpAndSettle();
      expect(find.text('앨범 편집 문의 60'), findsNothing);
      expect(find.byType(SupportInquiryScreen), findsNothing);
      expect(repository.submissions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final replacement in <String?>[null, 'support-owner-b']) {
    testWidgets(
      'private history and stale actions disappear for owner=$replacement',
      (tester) async {
        final repository = SupportHistoryMemoryRepository(
          inquiries: [supportHistoryInquiry(60)],
        );
        final fixture = SupportCenterFixture(repository: repository);
        await mountSupportCenter(tester, fixture);
        await _tap(tester, _key('support-inquiry-60'));
        final refresh = _action(tester, 'support-history-refresh');
        final create = _action(tester, 'support-history-new');
        fixture.changeOwner(replacement);
        await tester.pumpAndSettle();
        refresh();
        create();
        await tester.pumpAndSettle();
        expect(find.text('앨범 편집 문의 60'), findsNothing);
        expect(find.text('사진을 프레임에 넣을 때 확인할 내용 60'), findsNothing);
        expect(find.byType(SupportInquiryScreen), findsNothing);
        expect(repository.reads.length, 1);
        expect(repository.submissions, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'an inquiry draft never reappears after the SDK account cycles A B A',
    (tester) async {
      final fixture = SupportCenterFixture();
      await mountSupportCenter(tester, fixture);
      await _tap(tester, _key('support-history-new'));
      await tester.enterText(_key('support-subject'), '이전 계정 비공개 제목');
      await tester.enterText(_key('support-message'), '이전 계정의 비공개 문의 내용');
      final submit = _action(tester, 'support-submit');
      fixture.changeOwner('support-owner-b');
      fixture.changeOwner(supportHistoryOwner);
      await tester.pumpAndSettle();
      submit();
      await tester.pumpAndSettle();
      expect(find.text('이전 계정 비공개 제목'), findsNothing);
      expect(find.text('이전 계정의 비공개 문의 내용'), findsNothing);
      expect(_key('support-submit').hitTestable(), findsNothing);
      expect(fixture.repository.submissions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mismatched SDK identity cannot request profile owner inquiries',
    (tester) async {
      final repository = SupportHistoryMemoryRepository(
        currentUserId: 'support-owner-b',
        inquiries: [supportHistoryInquiry(60)],
      );
      await mountSupportCenter(
        tester,
        SupportCenterFixture(repository: repository),
      );
      expect(repository.reads, isEmpty);
      expect(find.text('앨범 편집 문의 60'), findsNothing);
      expect(_key('support-history-new').hitTestable(), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 568), const Size(640, 320)]) {
    testWidgets('history and actions fit dark large text at $size', (
      tester,
    ) async {
      final repository = SupportHistoryMemoryRepository();
      repository.onRead = (_) => SupportInquiryPage(
        items: [
          supportHistoryInquiry(
            60,
            subject: '사진과 글을 함께 편집한 다음 저장한 내용에 관해 문의드려요',
            message: '남긴 사진을 다시 확인하고 싶어요.\n긴 문의도 전체 내용을 읽을 수 있어야 해요.',
          ),
        ],
        hasMore: true,
      );
      await mountSupportCenter(
        tester,
        SupportCenterFixture(repository: repository),
        size: size,
        dark: true,
        scale: 1.8,
      );
      await _tap(tester, _key('support-inquiry-60'));
      await tester.ensureVisible(_key('support-inquiry-body-60'));
      await tester.pumpAndSettle();
      expect(_key('support-inquiry-body-60').hitTestable(), findsOneWidget);
      for (final id in [
        'support-history-new',
        'support-history-refresh',
        'support-history-more',
      ]) {
        final control = _key(id);
        await tester.ensureVisible(control);
        await tester.pumpAndSettle();
        expect(control.hitTestable(), findsOneWidget, reason: id);
        final rect = tester.getRect(control);
        expect(rect.width, greaterThanOrEqualTo(44), reason: id);
        expect(rect.height, greaterThanOrEqualTo(44), reason: id);
        expect(rect.left, greaterThanOrEqualTo(0), reason: id);
        expect(rect.right, lessThanOrEqualTo(size.width), reason: id);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
