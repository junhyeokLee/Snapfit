import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' as painting;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moments_widgets.dart';
import 'package:snap_fit/features/moments/presentation/widgets/web_moments_journal_layout.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_feed_screen.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_profile_widgets.dart';
import 'package:snap_fit/shared/web/web_design.dart';
import 'package:snap_fit/shared/web/web_photo_layout.dart';

class _CaptureBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _Client extends Mock implements HttpClient {}

class _Request extends Mock implements HttpClientRequest {}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.bytes);
  final Uint8List bytes;
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

const _assets = [
  'assets/templates/jeju_travel/images/figma_small/jeju_ocean.jpg',
  'assets/templates/jeju_travel/images/figma_small/jeju_sunset.jpg',
  'assets/templates/jeju_travel/images/figma_small/jeju_rocky_coast.jpg',
];
const _profile = SocialProfile(
  userId: 'design-fixture',
  displayName: '서연의 사진 기록',
  handle: 'seoyeon.archive',
  bio: '여행의 풍경과 평범한 날의 작은 순간을 모아요.',
  followersCount: 128,
  followingCount: 46,
  worksCount: 12,
);
final _works = [
  for (var i = 0; i < 4; i++)
    SocialWork(
      id: 'local-$i',
      author: _profile,
      title: ['바람이 머문 제주', '천천히 걷던 저녁', '다시 만나고 싶은 풍경', '우리의 작은 여행'][i],
      caption: '사진 한 장에 담아 둔, 오래 기억하고 싶은 순간.',
      topic: '여행',
      imageUrls: ['https://fixture.invalid/$i.jpg'],
      aspectRatio: i % 3 == 1 ? 700 / 428 : 700 / 395,
      likeCount: 24 + i * 7,
      commentCount: i + 2,
      createdAt: DateTime.utc(2026, 10, 26 - i),
    ),
];

Widget _screen(BuildContext context, String screen) {
  Widget heading(String title, String description, {Widget? trailing}) =>
      WebPageHeading(
        title: title,
        description: description,
        trailing: trailing,
      );
  final actions = Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.search, size: 18),
        label: const Text('검색'),
      ),
      IconButton(
        onPressed: () {},
        tooltip: '저장한 작품',
        icon: const Icon(Icons.bookmark_border),
      ),
      FilledButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add, size: 18),
        label: const Text('작품 공개'),
      ),
    ],
  );
  final children = <Widget>[];
  if (screen == 'profile') {
    children.addAll([
      heading(
        '내 프로필',
        '나의 사진과 공개한 작품을 한곳에서 관리하세요.',
        trailing: IconButton(
          onPressed: () {},
          tooltip: '설정',
          icon: const Icon(Icons.settings_outlined),
        ),
      ),
      const SizedBox(height: 32),
      SocialProfileIdentity(
        webLayout: true,
        name: _profile.displayName,
        handle: _profile.handle,
        bio: _profile.bio,
        worksCount: 12,
        followersCount: 128,
        followingCount: 46,
        onFollowers: () {},
        onFollowing: () {},
      ),
      const SizedBox(height: 20),
      Wrap(
        spacing: 10,
        children: [
          OutlinedButton(onPressed: () {}, child: const Text('프로필 수정')),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 18),
            label: const Text('작품 공개'),
          ),
        ],
      ),
      const SizedBox(height: 28),
      Divider(color: WebPalette.of(context).line),
      const SizedBox(height: 28),
      SocialProfileGallery(webLayout: true, works: _works, onOpenWork: (_) {}),
    ]);
  } else if (screen == 'feed') {
    children.addAll([
      heading('피드', '다른 사람의 시선에서, 내 앨범의 영감을 만나보세요.', trailing: actions),
      const SizedBox(height: 24),
      Wrap(
        spacing: 24,
        children: [
          TextButton(
            onPressed: () {},
            child: const Text(
              '추천',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text('팔로잉', style: TextStyle(fontSize: 21)),
          ),
        ],
      ),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final label in [
              '전체',
              '여행',
              '일상',
              '가족',
              '커플',
              '친구',
              '반려동물',
              '성장',
              '기념일',
              '취미',
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(label),
                  selected: label == '전체',
                  onSelected: (_) {},
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 28),
      WebPhotoColumns(
        children: [
          for (final work in _works)
            SocialFeedCard(webLayout: true, work: work),
        ],
      ),
    ]);
  } else {
    final records = [
      for (var i = 0; i < 3; i++)
        MomentRecord(
          id: 'capture-$i',
          recordDate: DateTime.utc(2026, 10, 26 - i),
          caption: '바람이 좋았던 오후, 서두르지 않고 천천히 걸었어요.',
          photos: [
            MomentPhoto(
              id: 'photo-$i',
              path: 'fixture/$i.jpg',
              url: 'asset:${_assets[i]}',
              width: 1600,
              height: 900,
            ),
          ],
          revision: 1,
        ),
    ];
    children.addAll([
      heading(
        '나의 기록',
        '한 장씩 남겨둔 순간이, 나의 한 달을 만듭니다.',
        trailing: TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_rounded, size: 18),
          label: const Text('기록 알림'),
        ),
      ),
      const SizedBox(height: 28),
      WebMomentsJournalLayout(
        monthNavigation: Row(
          children: [
            const Expanded(
              child: Text(
                '2026년 10월',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(onPressed: () {}, icon: const Icon(Icons.chevron_left)),
            const IconButton(onPressed: null, icon: Icon(Icons.chevron_right)),
          ],
        ),
        records: [
          for (final record in records)
            MomentRecordCard(
              record: record,
              onEdit: () {},
              maxPhotoHeight: 560,
            ),
        ],
        weekly: MomentWeekCard(photoCount: 3, onRecord: () {}),
        recap: WebSurface(
          padding: const EdgeInsets.all(18),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.play_circle_outline,
              color: WebPalette.of(context).brandInk,
            ),
            title: const Text('이번 주 돌아보기'),
            subtitle: const Text('남겨둔 3장의 순간을 천천히'),
            onTap: () {},
          ),
        ),
        album: WebSurface(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1.3,
                child: Image.asset(_assets[0], fit: BoxFit.cover),
              ),
              const SizedBox(height: 16),
              const Text(
                '나의 10월, 한 권으로',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text('모아둔 사진 3장으로 표지를 만나보세요.'),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: () {}, child: const Text('월간 앨범 미리보기')),
            ],
          ),
        ),
      ),
    ]);
  }
  return SnapFitWebShell(
    workspace: true,
    title: screen == 'feed'
        ? '피드'
        : screen == 'profile'
        ? '내 프로필'
        : '나의 기록',
    section: screen == 'feed'
        ? WebSection.feed
        : screen == 'moments'
        ? WebSection.moments
        : WebSection.myProfile,
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: WebPageLayout.maxWidth),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            WebPageLayout.horizontalInset(MediaQuery.sizeOf(context).width),
            32,
            WebPageLayout.horizontalInset(MediaQuery.sizeOf(context).width),
            48,
          ),
          children: children,
        ),
      ),
    ),
  );
}

void main() {
  _CaptureBinding();
  setUpAll(() => registerFallbackValue(Uri.parse('https://fixture.invalid')));
  testWidgets('capture photo-first content with bundled sample photographs', (
    tester,
  ) async {
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
    final bytes = [
      for (final asset in _assets)
        (await rootBundle.load(asset)).buffer.asUint8List(),
    ];
    final client = _Client();
    when(() => client.getUrl(any())).thenAnswer((invocation) async {
      final uri = invocation.positionalArguments.single as Uri;
      final index = int.tryParse(uri.pathSegments.last.split('.').first) ?? 0;
      final request = _Request();
      when(
        () => request.close(),
      ).thenAnswer((_) async => _Response(bytes[index % bytes.length]));
      return request;
    });
    final old = painting.debugNetworkImageHttpClientProvider;
    painting.debugNetworkImageHttpClientProvider = () => client;
    addTearDown(() => painting.debugNetworkImageHttpClientProvider = old);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    try {
      for (final dark in [false, true]) {
        for (final width in [1440.0, 1024.0, 390.0]) {
          for (final screen in ['feed', 'profile', 'moments']) {
            final boundary = GlobalKey();
            await tester.pumpWidget(const SizedBox());
            tester.view.physicalSize = Size(width, width == 390 ? 844 : 1000);
            tester.view.devicePixelRatio = 1;
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  socialCurrentUserIdProvider.overrideWithValue(
                    'design-fixture',
                  ),
                ],
                child: MaterialApp(
                  theme: SnapFitWebTheme.from(
                    dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
                  ),
                  home: RepaintBoundary(
                    key: boundary,
                    child: WebNavigationScope(
                      onNavigate: (_) {},
                      onNotifications: () {},
                      child: Builder(
                        builder: (context) => _screen(context, screen),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 100));
            await tester.runAsync(() async {
              final context = tester.element(find.byType(MaterialApp));
              for (final asset in _assets) {
                await precacheImage(
                  ResizeImage.resizeIfNeeded(1200, null, AssetImage(asset)),
                  context,
                );
              }
              for (final work in _works) {
                await precacheImage(
                  ResizeImage.resizeIfNeeded(
                    1440,
                    null,
                    NetworkImage(work.imageUrls.first),
                  ),
                  context,
                );
              }
              for (final element in find.byType(Image).evaluate()) {
                await precacheImage(
                  (element.widget as Image).image,
                  element,
                  onError: (_, __) {},
                );
              }
            });
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$screen $width dark=$dark',
            );
            final render =
                boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await render.toImage(pixelRatio: 1);
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                'output/web-unified-20261026/$screen-${width.toInt()}-${dark ? 'dark' : 'light'}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
      }
      await tester.pumpWidget(const SizedBox());
    } finally {
      painting.debugNetworkImageHttpClientProvider = old;
    }
  }, skip: !const bool.fromEnvironment('WEB_PHOTO_CAPTURE'));
}
