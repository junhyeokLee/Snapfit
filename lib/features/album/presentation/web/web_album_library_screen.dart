import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/navigation/web_app_location.dart';
import '../../../../shared/snapfit_image.dart';
import '../../../../shared/web/web_design.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../auth/presentation/views/login_screen.dart';
import '../../../profile/presentation/views/my_page_screen.dart';
import '../../../social/presentation/views/social_feed_screen.dart';
import '../../../social/presentation/views/social_profile_screen.dart';
import '../../../moments/presentation/moments_navigation.dart';
import '../../../moments/presentation/providers/moment_entry_refresh_provider.dart';
import '../../../moments/presentation/providers/moments_providers.dart';
import '../../../profile/presentation/views/order_history_screen.dart';
import '../../../store/presentation/views/store_hub_screen.dart';
import '../../../store/presentation/views/material_catalog_screen.dart';
import '../../data/album_creation_draft_store.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/album_creation_draft.dart';
import '../utils/album_creation_entry.dart';
import '../viewmodels/home_view_model.dart';
import '../views/album_create_flow_screen.dart';
import '../views/print_order_preview_screen.dart';
import '../widgets/home/home_album_actions.dart';
import '../widgets/create_flow/album_creation_start_sheet.dart';
import '../widgets/home/home_album_helpers.dart';
import '../widgets/home/home_moment_summary_card.dart';
import '../../../../core/utils/context_extensions.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../home_news/presentation/widgets/home_news_gate.dart';
import '../../../../shared/widgets/snapfit_motion.dart';

/// The web landing page is a searchable document library, not the app's shelf.
class WebAlbumLibraryScreen extends ConsumerStatefulWidget {
  const WebAlbumLibraryScreen({super.key});

  @override
  ConsumerState<WebAlbumLibraryScreen> createState() =>
      _WebAlbumLibraryScreenState();
}

class _WebAlbumLibraryScreenState extends ConsumerState<WebAlbumLibraryScreen> {
  final _search = TextEditingController();
  Set<int> _favorites = {};
  String _filter = '전체';
  String _sort = '최근 수정순';
  bool _listView = false;
  bool _creatingAlbum = false;

  void _resetFilters() => setState(() {
    _filter = '전체';
    _search.clear();
  });

  void _refreshLibrary() {
    ref.invalidate(homeViewModelProvider);
    ref.invalidate(momentsMonthProvider);
    ref.invalidate(momentEntryJournalProvider);
  }

  void _signIn() {
    final navigate = WebNavigationScope.maybeOf(context)?.onPublicNavigate;
    if (navigate != null) {
      navigate(WebAppLocation.login);
      return;
    }
    Navigator.of(context).push<void>(
      snapFitRoute<void>(
        page: const LoginScreen(),
        settings: const WebAppRouteSettings(WebAppLocation.login),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList('album_favorite_ids_v1') ?? [])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    if (mounted) setState(() => _favorites = ids);
  }

  Future<void> _favorite(int id) async {
    setState(
      () =>
          _favorites.contains(id) ? _favorites.remove(id) : _favorites.add(id),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'album_favorite_ids_v1',
      _favorites.map((id) => '$id').toList(),
    );
  }

  Future<void> _create({AlbumCreationDraft? resume, bool ai = false}) async {
    if (_creatingAlbum) return;
    _creatingAlbum = true;
    try {
      // 라이브러리의 일반 새 앨범도 홈과 같은 두 선택으로 시작한다.
      final startMode = resume == null && !ai
          ? await showAlbumCreationStartSheet(context)
          : null;
      if (!mounted || (resume == null && !ai && startMode == null)) return;
      final decision = await resolveAlbumCreationEntry(
        context,
        ref,
        requestedDraftId: resume?.id,
      );
      if (!mounted || decision == null) return;
      final draft = decision.draft;
      await Navigator.of(context).push(
        snapFitRoute<void>(
          page: AlbumCreateFlowScreen(
            initialDraft: draft,
            initialAiMode: ai && draft == null,
            initialStartMode: draft == null ? startMode : null,
          ),
          settings: WebAppRouteSettings(
            ai && draft == null
                ? WebAppLocation.aiCreate
                : WebAppLocation.create,
          ),
        ),
      );
      if (mounted) {
        ref.invalidate(albumCreationDraftProvider);
        ref.invalidate(homeViewModelProvider);
      }
    } finally {
      _creatingAlbum = false;
    }
  }

  void _orders() => Navigator.of(context).push(
    snapFitRoute<void>(
      page: const OrderHistoryScreen(),
      settings: const WebAppRouteSettings(WebAppLocation.orders),
    ),
  );

  void _account() => Navigator.of(context).push(
    snapFitRoute<void>(
      page: const MyPageScreen(),
      settings: const WebAppRouteSettings(WebAppLocation.account),
    ),
  );

  void _feed() => Navigator.of(context).push(
    snapFitRoute<void>(
      page: const SocialFeedScreen(),
      settings: const WebAppRouteSettings(WebAppLocation.feed),
    ),
  );

  void _myProfile() => Navigator.of(context).push(
    snapFitRoute<void>(
      page: const SocialProfileScreen(),
      settings: const WebAppRouteSettings(WebAppLocation.myProfile),
    ),
  );

  void _designs({bool materials = false}) => Navigator.of(context).push(
    snapFitRoute<void>(
      page: StoreHubScreen(initialMaterials: materials),
      settings: WebAppRouteSettings(
        materials ? WebAppLocation.materials : WebAppLocation.designs,
      ),
    ),
  );

  void _designLibrary() => Navigator.of(context).push(
    snapFitRoute<void>(
      page: const MaterialCatalogScreen(library: true),
      settings: const WebAppRouteSettings(WebAppLocation.library),
    ),
  );

  Future<void> _open(Album album) async {
    try {
      await HomeAlbumActions.openAlbum(
        context,
        ref,
        album,
        onAlbumDeleted: (_) => ref.invalidate(homeViewModelProvider),
      );
    } catch (_) {
      if (mounted) context.showErrorSnack('앨범을 열지 못했습니다. 잠시 후 다시 시도해 주세요.');
    }
  }

  void _print(Album album) => Navigator.of(context).push(
    snapFitRoute<void>(
      page: PrintOrderPreviewScreen(albumId: album.id, albumTitle: album.title),
      settings: WebAppRouteSettings(
        WebAppLocation(WebAppPage.print, '${album.id}'),
      ),
    ),
  );

  List<Album> _visible(List<Album> source, String owner) {
    final query = _search.text.trim().toLowerCase();
    final result = source.where((album) {
      if (album.id <= 0 || isDraftAlbum(album)) return false;
      if (query.isNotEmpty && !album.title.toLowerCase().contains(query))
        return false;
      return switch (_filter) {
        '작성 중' => isLiveEditingAlbum(album),
        '작성 완료' => isCompletedAlbum(album),
        '즐겨찾기' => _favorites.contains(album.id),
        '공유 앨범' =>
          owner.isNotEmpty && album.userId.isNotEmpty && album.userId != owner,
        _ => true,
      };
    }).toList();
    result.sort((a, b) {
      if (_sort == '이름순')
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      DateTime time(Album album) =>
          DateTime.tryParse(
            _sort == '최근 생성순' || album.updatedAt.isEmpty
                ? album.createdAt
                : album.updatedAt,
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return time(b).compareTo(time(a));
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final albums = ref.watch(homeViewModelProvider);
    final user = ref.watch(authViewModelProvider).asData?.value;
    final palette = WebPalette.of(context);
    final content = SnapFitWebShell(
      section: WebSection.albums,
      onHome: _resetFilters,
      onMoments: () => openMoments(context),
      onFeed: _feed,
      onCreate: () => _create(),
      onDesigns: () => _designs(),
      onOrders: _orders,
      onAccount: _account,
      onMyProfile: _myProfile,
      child: CustomScrollView(
        key: const ValueKey('web-album-library-scroll'),
        slivers: [
          SliverToBoxAdapter(
            child: WebPageHeading(
              title: '내 앨범',
              description: '만들던 이야기를 이어가거나 새로운 앨범을 시작하세요.',
              trailing: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _create(),
                    icon: const ExperienceIcon('Plus', size: 19),
                    label: const Text('새 앨범 만들기'),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: HomeMomentSummaryCard(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  onRecord: () => openMomentCompose(context, ref),
                  onOpenMonth: () => openMoments(
                    context,
                    initialMonth: ref
                        .read(momentEntryJournalProvider)
                        .asData
                        ?.value
                        ?.month,
                  ),
                  onSignIn: _signIn,
                  onOpenDate: (date) => openMoments(
                    context,
                    initialMonth: date,
                    initialDate: date,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _libraryToolbar()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['전체', '작성 중', '작성 완료', '즐겨찾기', '공유 앨범']
                    .map(
                      (filter) => ChoiceChip(
                        label: Text(filter),
                        selected: _filter == filter,
                        showCheckmark: false,
                        selectedColor: palette.softBrand,
                        backgroundColor: palette.surface,
                        side: BorderSide(
                          color: _filter == filter
                              ? palette.brandInk
                              : palette.line,
                        ),
                        labelStyle: TextStyle(
                          color: _filter == filter
                              ? palette.brandInk
                              : palette.muted,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          ...albums.when<List<Widget>>(
            loading: () => [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(70),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
            error: (_, __) => [
              SliverToBoxAdapter(
                child: _empty(
                  '앨범을 불러오지 못했습니다',
                  '연결을 확인한 뒤 다시 시도해 주세요.',
                  OutlinedButton(
                    onPressed: _refreshLibrary,
                    child: const Text('다시 불러오기'),
                  ),
                ),
              ),
            ],
            data: (source) {
              final visible = _visible(source, user?.id ?? '');
              final total = source
                  .where((a) => a.id > 0 && !isDraftAlbum(a))
                  .length;
              final filtered =
                  _search.text.trim().isNotEmpty || _filter != '전체';
              if (visible.isEmpty)
                return [
                  SliverToBoxAdapter(
                    child: _empty(
                      filtered ? '조건에 맞는 앨범이 없습니다' : '첫 이야기를 담아보세요',
                      filtered
                          ? '검색어나 필터를 바꾸면 다른 앨범을 볼 수 있어요.'
                          : '사진을 올리고, 페이지에 글을 더해 나만의 앨범을 만드세요.',
                      filtered
                          ? OutlinedButton(
                              onPressed: _resetFilters,
                              child: const Text('검색·필터 초기화'),
                            )
                          : FilledButton(
                              onPressed: () => _create(),
                              child: const Text('앨범 만들기'),
                            ),
                    ),
                  ),
                ];
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      filtered
                          ? '전체 $total개 중 ${visible.length}개'
                          : '앨범 $total개',
                      key: const ValueKey('web-library-result-count'),
                      style: TextStyle(fontSize: 12, color: palette.muted),
                    ),
                  ),
                ),
                if (_listView)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _albumRow(visible[index]),
                      ),
                      childCount: visible.length,
                    ),
                  )
                else
                  SliverLayoutBuilder(
                    builder: (context, bounds) {
                      final columns = bounds.crossAxisExtent >= 1040
                          ? 3
                          : bounds.crossAxisExtent >= 680
                          ? 2
                          : 1;
                      final cardWidth =
                          (bounds.crossAxisExtent - 22 * (columns - 1)) /
                          columns;
                      final artworkHeight = cardWidth
                          .clamp(240.0, 420.0)
                          .toDouble();
                      final textScaler = MediaQuery.textScalerOf(context);
                      final detailsHeight =
                          42 +
                          textScaler.scale(16) * 1.4 +
                          textScaler.scale(12) * 2.8;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent: artworkHeight + detailsHeight,
                          mainAxisSpacing: 22,
                          crossAxisSpacing: 22,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _albumCard(visible[index]),
                          childCount: visible.length,
                        ),
                      );
                    },
                  ),
              ];
            },
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 32, bottom: 12),
              child: _designShortcuts(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              child: Text(
                '사진과 앨범은 로그인한 계정에 저장됩니다.',
                style: TextStyle(fontSize: 12, color: palette.muted),
              ),
            ),
          ),
        ],
      ),
    );
    return HomeNewsGate(respectFirstVisitGuide: false, child: content);
  }

  Widget _libraryToolbar() => LayoutBuilder(
    builder: (context, bounds) {
      final search = TextField(
        key: const ValueKey('web-library-search'),
        controller: _search,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: '앨범 이름으로 검색',
          prefixIcon: const ExperienceIcon('Search', size: 21),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: '검색어 지우기',
                  onPressed: () => setState(_search.clear),
                  icon: const ExperienceIcon('X', size: 18),
                ),
        ),
      );
      final sort = SizedBox(
        width: 174,
        child: DropdownButtonFormField<String>(
          initialValue: _sort,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '정렬'),
          items: const ['최근 수정순', '최근 생성순', '이름순']
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _sort = value);
          },
        ),
      );
      final view = SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: false,
            icon: ExperienceIcon('LayoutGrid', size: 18),
            tooltip: '앨범 카드 보기',
          ),
          ButtonSegment(
            value: true,
            icon: ExperienceIcon('List', size: 20),
            tooltip: '앨범 목록 보기',
          ),
        ],
        selected: {_listView},
        onSelectionChanged: (selected) =>
            setState(() => _listView = selected.single),
        style: const ButtonStyle(visualDensity: VisualDensity.standard),
      );
      final controls = Row(children: [sort, const SizedBox(width: 12), view]);
      return bounds.maxWidth < 680
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                search,
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: sort),
                    const SizedBox(width: 12),
                    view,
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: 16),
                controls,
              ],
            );
    },
  );

  Widget _designShortcuts() {
    final palette = WebPalette.of(context);
    final items =
        <({String title, String subtitle, Widget icon, VoidCallback action})>[
          (
            title: '템플릿 둘러보기',
            subtitle: '완성된 디자인으로 시작',
            icon: ExperienceIcon('BookOpen', size: 23, color: palette.brandInk),
            action: () => _designs(),
          ),
          (
            title: '꾸밈소재 둘러보기',
            subtitle: '사진 곁에 나만의 포인트',
            icon: ExperienceIcon('Shapes', size: 23, color: palette.brandInk),
            action: () => _designs(materials: true),
          ),
          (
            title: 'AI로 만들기',
            subtitle: '원하는 분위기로 디자인 생성',
            icon: ExperienceIcon('Sparkles', size: 23, color: palette.brandInk),
            action: () => _create(ai: true),
          ),
        ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              '다음 앨범을 위한 아이디어',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: palette.ink,
              ),
            ),
            TextButton.icon(
              onPressed: _designLibrary,
              icon: const ExperienceIcon('Bookmark', size: 17),
              label: const Text('내 디자인 보관함'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, bounds) {
            final width = bounds.maxWidth >= 760
                ? (bounds.maxWidth - 32) / 3
                : bounds.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                for (final item in items)
                  SizedBox(
                    width: width,
                    child: Material(
                      color: palette.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: palette.line),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: item.action,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              item.icon,
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: palette.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      item.subtitle,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: palette.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ExperienceIcon(
                                'ArrowRight',
                                size: 16,
                                color: palette.muted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _albumRow(Album album) {
    final palette = WebPalette.of(context);
    return WebSurface(
      key: ValueKey('web-album-row-${album.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: LayoutBuilder(
        builder: (context, bounds) {
          final compact = bounds.maxWidth < 640;
          final info = _albumOpenRegion(
            album,
            key: ValueKey('web-album-row-open-${album.id}'),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  SizedBox(
                    width: 94,
                    height: 94,
                    child: _coverImage(album, padding: 6),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _albumDetails(album, titleSize: 15)),
                ],
              ),
            ),
          );
          final actions = Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              _favoriteButton(album),
              if (album.allowsManagement) _publishButton(album),
              IconButton(
                tooltip: '제작 사양과 주문 준비 확인',
                onPressed: () => _print(album),
                icon: ExperienceIcon(
                  'Printer',
                  color: palette.brandInk,
                  size: 20,
                ),
              ),
            ],
          );
          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    info,
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: info),
                    const SizedBox(width: 16),
                    actions,
                  ],
                );
        },
      ),
    );
  }

  Widget _favoriteButton(Album album) => IconButton(
    tooltip: _favorites.contains(album.id) ? '즐겨찾기 해제' : '즐겨찾기 추가',
    onPressed: () => _favorite(album.id),
    style: IconButton.styleFrom(
      backgroundColor: WebPalette.of(context).surface,
    ),
    icon: ExperienceIcon(
      _favorites.contains(album.id) ? 'StarFill' : 'Star',
      size: 21,
      color: WebPalette.of(context).brandInk,
    ),
  );

  Widget _publishButton(Album album) => IconButton(
    key: ValueKey('web-album-publish-${album.id}'),
    tooltip: '프로필에 앨범 공개',
    onPressed: () => HomeAlbumActions.onPublishSelected(context, ref, album),
    icon: ExperienceIcon(
      'Globe',
      color: WebPalette.of(context).brandInk,
      size: 20,
    ),
  );

  Widget _coverImage(Album album, {double padding = 16}) {
    final url = [
      album.coverThumbnailUrl,
      album.coverPreviewUrl,
      album.coverImageUrl,
      album.coverOriginalUrl,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).firstOrNull;
    return ColoredBox(
      color: WebPalette.of(context).canvas,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Center(
          child: AspectRatio(
            key: ValueKey('web-album-artwork-ratio-${album.id}'),
            aspectRatio: album.physicalCoverSize.ratio,
            child: url == null
                ? ExperienceIcon(
                    'BookOpen',
                    color: WebPalette.of(context).muted,
                    size: 32,
                  )
                : SnapfitImage(urlOrGs: url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _albumOpenRegion(
    Album album, {
    required Key key,
    required Widget child,
  }) => Semantics(
    button: true,
    label: '${album.title.trim().isEmpty ? '제목 없는 앨범' : album.title} 앨범 보기',
    onTap: () => _open(album),
    child: ExcludeSemantics(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(8),
          onTap: () => _open(album),
          child: child,
        ),
      ),
    ),
  );

  Widget _albumDetails(Album album, {double titleSize = 16}) {
    final palette = WebPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          album.title.trim().isEmpty ? '제목 없는 앨범' : album.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: titleSize,
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: palette.ink,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '${album.physicalCoverSize.displayName} · ${album.targetPages > 0 ? album.targetPages : album.totalPages}쪽',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, height: 1.4, color: palette.muted),
        ),
        const SizedBox(height: 6),
        Text(
          '${isCompletedAlbum(album) ? '작성 완료' : '작성 중'} · ${formatAlbumDate(album.updatedAt.isNotEmpty ? album.updatedAt : album.createdAt, useLocalTime: true)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, height: 1.4, color: palette.muted),
        ),
      ],
    );
  }

  Widget _empty(String title, String description, Widget? action) => WebSurface(
    padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
    child: Center(
      child: Column(
        children: [
          ExperienceIcon(
            'Bookmark',
            size: 38,
            color: WebPalette.of(context).muted,
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(color: WebPalette.of(context).muted),
          ),
          if (action != null) ...[const SizedBox(height: 24), action],
        ],
      ),
    ),
  );

  Widget _albumCard(Album album) {
    return Container(
      key: ValueKey('web-album-card-${album.id}'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: WebPalette.of(context).surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WebPalette.of(context).line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _albumOpenRegion(
                    album,
                    key: ValueKey('web-album-artwork-open-${album.id}'),
                    child: _coverImage(album),
                  ),
                ),
                Positioned(top: 10, right: 10, child: _favoriteButton(album)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: _albumOpenRegion(
                    album,
                    key: ValueKey('web-album-details-open-${album.id}'),
                    child: _albumDetails(album),
                  ),
                ),
                const SizedBox(width: 8),
                if (album.allowsManagement) _publishButton(album),
                IconButton(
                  tooltip: '제작 사양과 주문 준비 확인',
                  onPressed: () => _print(album),
                  icon: ExperienceIcon(
                    'Printer',
                    color: WebPalette.of(context).brandInk,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
