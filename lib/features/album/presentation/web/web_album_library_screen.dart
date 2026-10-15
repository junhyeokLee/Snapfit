import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/navigation/web_app_location.dart';
import '../../../../shared/snapfit_image.dart';
import '../../../../shared/web/web_design.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../profile/presentation/views/my_page_screen.dart';
import '../../../profile/presentation/views/order_history_screen.dart';
import '../../../store/presentation/views/store_hub_screen.dart';
import '../../../store/presentation/views/material_catalog_screen.dart';
import '../../data/album_creation_draft_store.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/album_creation_draft.dart';
import '../viewmodels/home_view_model.dart';
import '../views/album_create_flow_screen.dart';
import '../views/print_order_preview_screen.dart';
import '../widgets/home/home_album_actions.dart';
import '../widgets/home/home_album_helpers.dart';

/// The web landing page is a searchable document library, not the app's shelf.
class WebAlbumLibraryScreen extends ConsumerStatefulWidget {
  const WebAlbumLibraryScreen({super.key});

  @override
  ConsumerState<WebAlbumLibraryScreen> createState() => _WebAlbumLibraryScreenState();
}

class _WebAlbumLibraryScreenState extends ConsumerState<WebAlbumLibraryScreen> {
  final _search = TextEditingController();
  Set<int> _favorites = {};
  String _filter = '전체';
  String _sort = '최근 수정순';

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
    final ids = (prefs.getStringList('album_favorite_ids_v1') ?? []).map(int.tryParse).whereType<int>().toSet();
    if (mounted) setState(() => _favorites = ids);
  }

  Future<void> _favorite(int id) async {
    setState(() => _favorites.contains(id) ? _favorites.remove(id) : _favorites.add(id));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('album_favorite_ids_v1', _favorites.map((id) => '$id').toList());
  }

  Future<void> _create({AlbumCreationDraft? resume, bool ai = false}) async {
    var draft = resume;
    AlbumCreationDraft? saved;
    try {
      saved = await ref.read(albumCreationDraftProvider.future);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('임시 저장한 앨범을 확인하지 못했습니다. 다시 불러온 뒤 시작해주세요.')),
      );
      return;
    }
    if (!mounted) return;
    final existing = saved;
    if (draft == null && existing != null) {
      final choice = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('만들던 앨범이 있습니다'),
        content: Text('${existing.title.trim().isEmpty ? '제목 없는 앨범' : existing.title}\n이어서 만들거나 새 앨범을 시작하세요. 새 앨범을 임시 저장하면 기존 임시 저장을 대체합니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('새 앨범 만들기')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('이어서 만들기')),
        ],
      ));
      if (!mounted || choice == null) return;
      if (choice) draft = existing;
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      settings: WebAppRouteSettings(ai && draft == null
          ? WebAppLocation.aiCreate : WebAppLocation.create),
      builder: (_) => AlbumCreateFlowScreen(
        initialDraft: draft, initialAiMode: ai && draft == null,
      ),
    ));
    if (mounted) {
      ref.invalidate(albumCreationDraftProvider);
      ref.invalidate(homeViewModelProvider);
    }
  }

  void _orders() => Navigator.of(context).push(MaterialPageRoute<void>(
    settings: const WebAppRouteSettings(WebAppLocation.orders),
    builder: (_) => const OrderHistoryScreen(),
  ));

  void _account() => Navigator.of(context).push(MaterialPageRoute<void>(
    settings: const WebAppRouteSettings(WebAppLocation.account),
    builder: (_) => const MyPageScreen(),
  ));

  void _designs({bool materials = false}) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: WebAppRouteSettings(materials
          ? WebAppLocation.materials : WebAppLocation.designs),
      builder: (_) => StoreHubScreen(initialMaterials: materials),
    ),
  );

  void _designLibrary() => Navigator.of(context).push(MaterialPageRoute<void>(
    settings: const WebAppRouteSettings(WebAppLocation.library),
    builder: (_) => const MaterialCatalogScreen(library: true),
  ));

  Future<void> _open(Album album) async {
    try {
      await HomeAlbumActions.openAlbum(context, ref, album,
        onAlbumDeleted: (_) => ref.invalidate(homeViewModelProvider),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('앨범을 열지 못했습니다. 잠시 후 다시 시도해 주세요.')));
    }
  }

  void _print(Album album) => Navigator.of(context).push(MaterialPageRoute<void>(
    settings: WebAppRouteSettings(WebAppLocation(WebAppPage.print, '${album.id}')),
    builder: (_) => PrintOrderPreviewScreen(albumId: album.id, albumTitle: album.title),
  ));

  List<Album> _visible(List<Album> source, String owner) {
    final query = _search.text.trim().toLowerCase();
    final result = source.where((album) {
      if (album.id <= 0 || isDraftAlbum(album)) return false;
      if (query.isNotEmpty && !album.title.toLowerCase().contains(query)) return false;
      return switch (_filter) {
        '작성 중' => isLiveEditingAlbum(album),
        '작성 완료' => isCompletedAlbum(album),
        '즐겨찾기' => _favorites.contains(album.id),
        '공유 앨범' => owner.isNotEmpty && album.userId.isNotEmpty && album.userId != owner,
        _ => true,
      };
    }).toList();
    result.sort((a, b) {
      if (_sort == '이름순') return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      DateTime time(Album album) => DateTime.tryParse(
        _sort == '최근 생성순' || album.updatedAt.isEmpty ? album.createdAt : album.updatedAt,
      ) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return time(b).compareTo(time(a));
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final albums = ref.watch(homeViewModelProvider);
    final user = ref.watch(authViewModelProvider).asData?.value;
    final draftState = ref.watch(albumCreationDraftProvider);
    final draft = draftState.asData?.value;
    return SnapFitWebShell(
      section: WebSection.albums,
      onHome: () => setState(() { _filter = '전체'; _search.clear(); }),
      onCreate: () => _create(),
      onOrders: _orders,
      onAccount: _account,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: WebPageHeading(
          eyebrow: 'YOUR ALBUMS',
          title: '소중한 순간을 한 권으로',
          description: '사진을 모으고, 페이지를 편집하고, 나만의 앨범으로 완성하세요.',
          trailing: FilledButton.icon(onPressed: () => _create(), icon: const Icon(Icons.add, size: 19), label: const Text('새 앨범 만들기')),
        )),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: WebSurface(child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: () => _designs(),
                icon: const Icon(Icons.auto_stories_outlined, size: 19),
                label: const Text('템플릿 둘러보기'),
              ),
              OutlinedButton.icon(
                onPressed: () => _designs(materials: true),
                icon: const Icon(Icons.interests_outlined, size: 19),
                label: const Text('꾸밈소재 둘러보기'),
              ),
              FilledButton.icon(
                onPressed: () => _create(ai: true),
                icon: const Icon(Icons.auto_awesome_outlined, size: 19),
                label: const Text('AI로 만들기'),
              ),
              TextButton.icon(
                onPressed: _designLibrary,
                icon: const Icon(Icons.bookmark_border, size: 19),
                label: const Text('내 디자인 보관함'),
              ),
            ],
          )),
        )),
        if (draftState.hasError) SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: WebSurface(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('임시 저장한 앨범을 불러오지 못했습니다.',
                style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('이 브라우저의 저장 공간과 설정을 확인한 뒤 다시 불러와 주세요.',
                style: TextStyle(color: WebPalette.of(context).muted)),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(albumCreationDraftProvider),
                child: const Text('다시 불러오기'),
              ),
            ],
          )),
        )),
        if (draft != null) SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: WebSurface(child: LayoutBuilder(builder: (context, bounds) {
            final details = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('이어서 만들기', style: TextStyle(color: WebPalette.of(context).brandInk, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(draft.title.trim().isEmpty ? '제목 없는 앨범' : draft.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ]);
            final button = OutlinedButton(onPressed: () => _create(resume: draft), child: const Text('임시 저장 열기'));
            return bounds.maxWidth < 500
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [details, const SizedBox(height: 16), button])
                : Row(children: [Expanded(child: details), button]);
          })),
        )),
        SliverToBoxAdapter(child: LayoutBuilder(builder: (context, bounds) {
          final search = TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: '앨범 이름으로 검색', prefixIcon: Icon(Icons.search, size: 21)),
          );
          final sort = DropdownButtonFormField<String>(
            initialValue: _sort,
            decoration: const InputDecoration(labelText: '정렬'),
            items: const ['최근 수정순', '최근 생성순', '이름순'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
            onChanged: (value) { if (value != null) setState(() => _sort = value); },
          );
          return bounds.maxWidth < 600
              ? Column(children: [search, const SizedBox(height: 14), sort])
              : Row(children: [Expanded(child: search), const SizedBox(width: 16), SizedBox(width: 190, child: sort)]);
        })),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22),
          child: Wrap(spacing: 8, runSpacing: 8, children: ['전체', '작성 중', '작성 완료', '즐겨찾기', '공유 앨범'].map((filter) => ChoiceChip(
            label: Text(filter),
            selected: _filter == filter,
            showCheckmark: false,
            selectedColor: WebPalette.of(context).softBrand,
            backgroundColor: WebPalette.of(context).surface,
            side: BorderSide(color: _filter == filter ? WebPalette.of(context).brandInk : WebPalette.of(context).line),
            labelStyle: TextStyle(color: _filter == filter ? WebPalette.of(context).brandInk : WebPalette.of(context).muted, fontWeight: FontWeight.w600),
            onSelected: (_) => setState(() => _filter = filter),
          )).toList()),
        )),
        ...albums.when<List<Widget>>(
          loading: () => [const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(70), child: Center(child: CircularProgressIndicator())))],
          error: (_, __) => [SliverToBoxAdapter(child: _empty(
            '앨범을 불러오지 못했습니다', '연결을 확인한 뒤 다시 시도해 주세요.',
            OutlinedButton(onPressed: () => ref.invalidate(homeViewModelProvider), child: const Text('다시 불러오기')),
          ))],
          data: (source) {
            final visible = _visible(source, user?.id ?? '');
            if (visible.isEmpty) return [SliverToBoxAdapter(child: _empty(
              _search.text.isNotEmpty ? '검색 결과가 없습니다' : '아직 이곳에 앨범이 없습니다',
              _search.text.isNotEmpty ? '다른 이름으로 검색해 보세요.' : '첫 앨범을 만들고 사진을 담아보세요.',
              _search.text.isNotEmpty ? null : FilledButton(onPressed: () => _create(), child: const Text('앨범 만들기')),
            ))];
            return [
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(bottom: 16), child: Text('앨범 ${visible.length}개', style: TextStyle(fontSize: 13, color: WebPalette.of(context).muted)))),
              SliverLayoutBuilder(builder: (context, bounds) {
                final columns = bounds.crossAxisExtent >= 1120 ? 4 : bounds.crossAxisExtent >= 820 ? 3 : bounds.crossAxisExtent >= 520 ? 2 : 1;
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisExtent: 354, mainAxisSpacing: 22, crossAxisSpacing: 22),
                  delegate: SliverChildBuilderDelegate((context, index) => _albumCard(visible[index]), childCount: visible.length),
                );
              }),
            ];
          },
        ),
        SliverToBoxAdapter(child: Padding(
          padding: EdgeInsets.only(top: 40, bottom: 16),
          child: Text('사진과 앨범은 로그인한 계정에 저장됩니다.', style: TextStyle(fontSize: 12, color: WebPalette.of(context).muted)),
        )),
      ]),
    );
  }

  Widget _empty(String title, String description, Widget? action) => WebSurface(
    padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
    child: Center(child: Column(children: [
      Icon(Icons.photo_album_outlined, size: 38, color: WebPalette.of(context).muted),
      const SizedBox(height: 20),
      Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(description, style: TextStyle(color: WebPalette.of(context).muted)),
      if (action != null) ...[const SizedBox(height: 24), action],
    ])),
  );

  Widget _albumCard(Album album) {
    final url = [album.coverThumbnailUrl, album.coverPreviewUrl, album.coverImageUrl, album.coverOriginalUrl]
        .whereType<String>().where((value) => value.trim().isNotEmpty).firstOrNull;
    final physical = album.physicalCoverSize;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: WebPalette.of(context).surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: WebPalette.of(context).line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: Material(color: WebPalette.of(context).canvas, child: InkWell(
          onTap: () => _open(album),
          child: Stack(children: [
            Positioned.fill(child: Padding(padding: const EdgeInsets.all(24), child: url == null
              ? Icon(Icons.auto_stories_outlined, color: WebPalette.of(context).muted, size: 48)
              : SnapfitImage(urlOrGs: url, fit: BoxFit.contain))),
            Positioned(top: 10, right: 10, child: IconButton(
              tooltip: _favorites.contains(album.id) ? '즐겨찾기 해제' : '즐겨찾기 추가',
              onPressed: () => _favorite(album.id),
              style: IconButton.styleFrom(backgroundColor: WebPalette.of(context).surface),
              icon: Icon(_favorites.contains(album.id) ? Icons.star_rounded : Icons.star_border_rounded, color: WebPalette.of(context).brandInk, size: 21),
            )),
          ]),
        ))),
        Padding(padding: const EdgeInsets.fromLTRB(18, 16, 18, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(album.title.trim().isEmpty ? '제목 없는 앨범' : album.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 7),
          Text('${physical.displayName} · ${album.targetPages > 0 ? album.targetPages : album.totalPages}쪽', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: WebPalette.of(context).muted)),
          const SizedBox(height: 6),
          Text('${isCompletedAlbum(album) ? '작성 완료' : '작성 중'} · ${formatAlbumDate(album.updatedAt.isNotEmpty ? album.updatedAt : album.createdAt)}', style: TextStyle(fontSize: 12, color: WebPalette.of(context).muted)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => _open(album), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13)), child: const Text('앨범 열기'))),
            const SizedBox(width: 8),
            Tooltip(message: '제작 사양과 주문 준비 확인', child: IconButton(onPressed: () => _print(album), icon: Icon(Icons.local_printshop_outlined, color: WebPalette.of(context).brandInk, size: 20))),
          ]),
        ])),
      ]),
    );
  }
}
