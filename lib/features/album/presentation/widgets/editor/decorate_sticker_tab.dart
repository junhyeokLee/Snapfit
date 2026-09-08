import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../point_shop/presentation/point_shop_access.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../controllers/layer_builder.dart';
import '../../../../../core/templates/studio_decoration_catalog.dart';
import '../../../../../core/templates/studio_word_art_catalog.dart';
import '../../../../../shared/widgets/studio_word_art_preview.dart';
import '../../../../../shared/widgets/studio_decoration.dart';
import '../../../../../shared/widgets/catalog_favorite_widgets.dart';

class DecorateStickerTab extends ConsumerStatefulWidget {
  final Color surfaceColor;
  final void Function(String sticker)? onStickerTap;

  const DecorateStickerTab({
    super.key,
    required this.surfaceColor,
    this.onStickerTap,
  });

  @override
  ConsumerState<DecorateStickerTab> createState() => _DecorateStickerTabState();
}

class _DecorateStickerTabState extends ConsumerState<DecorateStickerTab> {
  String? _selectedStickerValue;
  bool _isApplying = false;
  bool _favoritesOnly = false;
  String? _collection;

  static const List<_StickerItem> _stickersAll = [
    _StickerItem.deco("stickerBlueStar", scale: 1.0),
    _StickerItem.deco("stickerBlueStarSmall", scale: 0.74),
    _StickerItem.deco("stickerRibbonBlue", scale: 1.0),
    _StickerItem.deco("stickerPaperClip", scale: 0.92),
    _StickerItem.deco("stickerFlowerPink", scale: 1.0),
    _StickerItem.deco("stickerFlowerCoral", scale: 0.9),
    _StickerItem.deco("stickerDaisyWhite", scale: 1.0),
    _StickerItem.deco("stickerHeartRed", scale: 0.9),
    _StickerItem.deco("stickerLeafGreen", scale: 0.9),
    _StickerItem.deco("stickerSparkleBlue", scale: 0.9),
    _StickerItem.deco("stickerBowPink", scale: 0.95),
    _StickerItem.deco("stickerScribbleBlue", scale: 0.95),
    _StickerItem.deco("stickerBrushPink", scale: 0.95),
    _StickerItem.deco("stickerBlobGreen", scale: 0.95),
    _StickerItem.deco("stickerArrowCoral", scale: 0.95),
    _StickerItem.deco("stickerLeafCornerLeft", scale: 0.85),
    _StickerItem.deco("stickerLeafCornerRight", scale: 0.85),
    _StickerItem.deco("stickerCloudSoft", scale: 1.05),
    _StickerItem.deco("stickerCherryBlossom", scale: 1.0),
    _StickerItem.deco("stickerEnvelopeBlue", scale: 1.0),
    _StickerItem.deco("stickerCloverGreen", scale: 0.95),
    _StickerItem.deco("stickerInstantCamera", scale: 1.0),
    _StickerItem.deco("stickerTicketPaper", scale: 1.0),
    _StickerItem.deco("stickerTapeBeige", scale: 1.1),
    _StickerItem.deco("stickerTornNoteBeige", scale: 1.0),
    _StickerItem.deco("stickerCatDoodle", scale: 1.15),
    // expanded premium deco set
    _StickerItem.deco("stickerTapeDotsBlue", scale: 1.05),
    _StickerItem.deco("stickerTapeStripePink", scale: 1.05),
    _StickerItem.deco("stickerSparkleGold", scale: 0.95),
    _StickerItem.deco("stickerStarGold", scale: 0.95),
    _StickerItem.deco("stickerHeartPink", scale: 0.95),
    _StickerItem.asset("assets/sticker/scrap1.png"),
    _StickerItem.asset("assets/sticker/scrap2.png"),
    _StickerItem.asset("assets/sticker/scrap3.png"),
    _StickerItem.emoji("🎀"),
    _StickerItem.emoji("✿"),
    _StickerItem.emoji("❀"),
    _StickerItem.emoji("✾"),
    _StickerItem.emoji("✶"),
    _StickerItem.emoji("ฅ^•ﻌ•^ฅ"),
    _StickerItem.emoji("⌇"),
    _StickerItem.emoji("◈"),
    // hearts / sparkle
    _StickerItem.emoji("❤️"),
    _StickerItem.emoji("🧡"),
    _StickerItem.emoji("💛"),
    _StickerItem.emoji("💚"),
    _StickerItem.emoji("💙"),
    _StickerItem.emoji("💜"),
    _StickerItem.emoji("🖤"),
    _StickerItem.emoji("🤍"),
    _StickerItem.emoji("🩷"),
    _StickerItem.emoji("💖"),
    _StickerItem.emoji("💘"),
    _StickerItem.emoji("💝"),
    _StickerItem.emoji("💞"),
    _StickerItem.emoji("💟"),
    _StickerItem.emoji("✨"),
    _StickerItem.emoji("⭐"),
    _StickerItem.emoji("🌟"),
    _StickerItem.emoji("💫"),
    _StickerItem.emoji("🔥"),
    _StickerItem.emoji("🌈"),
    _StickerItem.emoji("☀️"),
    _StickerItem.emoji("🌤️"),
    _StickerItem.emoji("🌙"),
    _StickerItem.emoji("⚡"),
    // faces / hands
    _StickerItem.emoji("😊"),
    _StickerItem.emoji("😍"),
    _StickerItem.emoji("🥰"),
    _StickerItem.emoji("😎"),
    _StickerItem.emoji("🤩"),
    _StickerItem.emoji("🥳"),
    _StickerItem.emoji("😭"),
    _StickerItem.emoji("😆"),
    _StickerItem.emoji("🤝"),
    _StickerItem.emoji("👏"),
    _StickerItem.emoji("🙌"),
    _StickerItem.emoji("👍"),
    _StickerItem.emoji("🫶"),
    _StickerItem.emoji("🙏"),
    // pets / nature
    _StickerItem.emoji("🐶"),
    _StickerItem.emoji("🐱"),
    _StickerItem.emoji("🐰"),
    _StickerItem.emoji("🐻"),
    _StickerItem.emoji("🐼"),
    _StickerItem.emoji("🦊"),
    _StickerItem.emoji("🐾"),
    _StickerItem.emoji("🌸"),
    _StickerItem.emoji("🌷"),
    _StickerItem.emoji("🌼"),
    _StickerItem.emoji("🍀"),
    _StickerItem.emoji("🌿"),
    _StickerItem.emoji("🌵"),
    _StickerItem.emoji("🍃"),
    // party / deco
    _StickerItem.emoji("🎈"),
    _StickerItem.emoji("🎉"),
    _StickerItem.emoji("🎊"),
    _StickerItem.emoji("🎁"),
    _StickerItem.emoji("🎨"),
    _StickerItem.emoji("🖍️"),
    _StickerItem.emoji("📸"),
    _StickerItem.emoji("🧸"),
    _StickerItem.emoji("🍰"),
    _StickerItem.emoji("🧁"),
    _StickerItem.emoji("🍭"),
    _StickerItem.emoji("🍓"),
    _StickerItem.emoji("🍒"),
    // travel / daily
    _StickerItem.emoji("✈️"),
    _StickerItem.emoji("🚗"),
    _StickerItem.emoji("🏠"),
    _StickerItem.emoji("🛍️"),
    _StickerItem.emoji("☕"),
    _StickerItem.emoji("🍿"),
    _StickerItem.emoji("🎧"),
    _StickerItem.emoji("📚"),
    _StickerItem.emoji("🕶️"),
    _StickerItem.emoji("⌚"),
    _StickerItem.emoji("🧩"),
    _StickerItem.emoji("📎"),
    _StickerItem.emoji("✎"),
    _StickerItem.emoji("❧"),
    _StickerItem.emoji("✧"),
    _StickerItem.emoji("❦"),
  ];

  @override
  Widget build(BuildContext context) => CatalogFavoritesBuilder(
    builder: (context, favorites) {
      return DefaultTabController(
        length: 6,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CatalogFavoriteFilter(
                  selected: _favoritesOnly,
                  onChanged: (value) => setState(() => _favoritesOnly = value),
                ),
              ),
            ),
            if (!_favoritesOnly)
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                indicatorSize: TabBarIndicatorSize.label,
                tabs: const [
                  Tab(text: '새 컬렉션'),
                  Tab(text: '종이'),
                  Tab(text: '스티커'),
                  Tab(text: '테이프'),
                  Tab(text: '꾸민 문구'),
                  Tab(text: '기존 장식'),
                ],
              ),
            Expanded(
              child: _favoritesOnly
                  ? _grid(
                      [
                        ..._studioEntries(studioDecorations),
                        ..._wordArtEntries(),
                        ..._legacyEntries(),
                      ],
                      favorites,
                      onlyFavorites: true,
                    )
                  : TabBarView(
                      children: [
                        Column(
                          children: [
                            SizedBox(
                              height: 52,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                children: [
                                  for (final label in [
                                    null,
                                    ...studioDecorations
                                        .map((s) => s.collection)
                                        .whereType<String>()
                                        .toSet(),
                                  ])
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        label: Text(label ?? '전체 소재'),
                                        selected: _collection == label,
                                        onSelected: (_) =>
                                            setState(() => _collection = label),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: _grid(
                                _studioEntries(
                                  studioDecorations.where(
                                    (s) =>
                                        _collection == null ||
                                        s.collection == _collection,
                                  ),
                                ),
                                favorites,
                              ),
                            ),
                          ],
                        ),
                        for (final category in StudioDecorationCategory.values)
                          _grid(
                            _studioEntries(
                              studioDecorations.where(
                                (s) => s.category == category,
                              ),
                            ),
                            favorites,
                          ),
                        _grid(_wordArtEntries(), favorites),
                        _grid(_legacyEntries(), favorites),
                      ],
                    ),
            ),
          ],
        ),
      );
    },
  );

  List<({String value, String label, String? productKey, Widget preview})>
  _studioEntries(Iterable<StudioDecorationSpec> items) => [
    for (final item in items)
      (
        value: item.insertionValue,
        label: item.label,
        productKey: 'sticker:${item.id}',
        preview: AspectRatio(
          aspectRatio: item.aspectRatio,
          child: RepaintBoundary(child: StudioDecoration(spec: item)),
        ),
      ),
  ];

  List<({String value, String label, String? productKey, Widget preview})>
  _wordArtEntries() => [
    for (final art in studioWordArts)
      (
        value: art.insertionValue,
        label: art.label,
        productKey: art.productKey,
        preview: StudioWordArtPreview(art: art),
      ),
  ];

  List<({String value, String label, String? productKey, Widget preview})>
  _legacyEntries() => [
    for (final item in _stickersAll)
      (
        value: item.valueForInsert,
        productKey: null,
        label: item.isAsset
            ? '스크랩 종이 ${item.value.substring(item.value.length - 5, item.value.length - 4)}'
            : item.isDeco
            ? (_legacyLabels[item.value] ?? '장식')
            : item.value,
        preview: _buildStickerVisual(item),
      ),
  ];

  static const _legacyLabels = {
    'stickerBlueStar': '블루 스타',
    'stickerBlueStarSmall': '작은 블루 스타',
    'stickerRibbonBlue': '블루 리본',
    'stickerPaperClip': '페이퍼 클립',
    'stickerFlowerPink': '핑크 꽃',
    'stickerFlowerCoral': '코랄 꽃',
    'stickerDaisyWhite': '화이트 데이지',
    'stickerHeartRed': '레드 하트',
    'stickerLeafGreen': '초록 잎',
    'stickerSparkleBlue': '블루 반짝임',
    'stickerBowPink': '핑크 리본',
    'stickerScribbleBlue': '파란 낙서',
    'stickerBrushPink': '핑크 붓 터치',
    'stickerBlobGreen': '초록 조각',
    'stickerArrowCoral': '코랄 화살표',
    'stickerLeafCornerLeft': '왼쪽 잎 장식',
    'stickerLeafCornerRight': '오른쪽 잎 장식',
    'stickerCloudSoft': '구름',
    'stickerCherryBlossom': '벚꽃',
    'stickerEnvelopeBlue': '파란 편지',
    'stickerCloverGreen': '클로버',
    'stickerInstantCamera': '즉석 카메라',
    'stickerTicketPaper': '종이 티켓',
    'stickerTapeBeige': '종이 테이프',
    'stickerTornNoteBeige': '찢어진 메모',
    'stickerCatDoodle': '고양이 낙서',
    'stickerTapeDotsBlue': '파란 도트 테이프',
    'stickerTapeStripePink': '핑크 줄무늬 테이프',
    'stickerSparkleGold': '골드 반짝임',
    'stickerStarGold': '골드 스타',
    'stickerHeartPink': '핑크 하트',
  };

  Widget _grid(
    List<({String value, String label, String? productKey, Widget preview})>
    source,
    CatalogFavorites favorites, {
    bool onlyFavorites = false,
  }) {
    final items = favorites.arrange(
      source,
      (s) => CatalogFavoriteKeys.decoration(s.value),
      onlyFavorites: onlyFavorites,
    );
    if (items.isEmpty)
      return CatalogFavoritesEmpty(
        onShowAll: () => setState(() => _favoritesOnly = false),
      );
    final colors = Theme.of(context).colorScheme;
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisExtent: 142 + 56 * scale,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        Future<void> insert() async {
          if (_isApplying) return;
          _isApplying = true;
          try {
            if (item.productKey != null &&
                !await ensurePointShopAccess(
                  context,
                  ref,
                  productKey: item.productKey!,
                  title: item.label,
                ))
              return;
            if (!mounted) return;
            setState(() => _selectedStickerValue = item.value);
            widget.onStickerTap?.call(item.value);
          } finally {
            _isApplying = false;
          }
        }

        return CatalogFavoriteTile(
          key: ValueKey(item.value),
          itemKey: CatalogFavoriteKeys.decoration(item.value),
          label: item.label,
          child: Semantics(
            button: true,
            label: '${item.label} 추가',
            onTap: insert,
            child: Material(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: insert,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedStickerValue == item.value
                          ? SnapFitColors.accent
                          : colors.outlineVariant,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 44, 12, 8),
                  child: Column(
                    children: [
                      Expanded(child: Center(child: item.preview)),
                      const SizedBox(height: 8),
                      Text(
                        item.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (item.productKey != null)
                        PointShopProductBadge(productKey: item.productKey!)
                      else
                        Text(
                          '무료',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStickerVisual(_StickerItem sticker) {
    if (sticker.isAsset) {
      return Image.asset(
        sticker.value,
        fit: BoxFit.contain,
        width: 42.w,
        height: 42.w,
      );
    }
    if (sticker.isDeco) {
      return _DecoStickerPreview(style: sticker.value);
    }
    return Text(sticker.value, style: TextStyle(fontSize: 28.sp));
  }
}

class _StickerItem {
  final String value;
  final bool isAsset;
  final bool isDeco;
  final double scale;

  const _StickerItem.emoji(this.value)
    : isAsset = false,
      isDeco = false,
      scale = 1.0;
  const _StickerItem.asset(this.value)
    : isAsset = true,
      isDeco = false,
      scale = 1.0;
  const _StickerItem.deco(this.value, {this.scale = 1.0})
    : isAsset = false,
      isDeco = true;

  String get valueForInsert {
    if (isAsset) return 'asset:$value';
    if (isDeco) return 'deco:$value@$scale';
    return value;
  }
}

class _DecoStickerPreview extends StatelessWidget {
  final String style;

  const _DecoStickerPreview({required this.style});

  @override
  Widget build(BuildContext context) {
    // 실제 캔버스 적용과 동일한 렌더 결과로 미리보기 표시
    return DecoStickerVisual(style: style, width: 40.w, height: 40.w);
  }
}

/// 레이아웃(찢김 스크랩) 전용 탭
class DecorateLayoutTab extends StatelessWidget {
  final Color surfaceColor;
  final void Function(String layoutKey)? onLayoutTap;

  const DecorateLayoutTab({
    super.key,
    required this.surfaceColor,
    this.onLayoutTap,
  });

  static const List<String> _layoutKeys = ['scrap1', 'scrap2', 'scrap3'];

  @override
  Widget build(BuildContext context) => CatalogFavoriteGrid<String>(
    items: _layoutKeys,
    keyOf: (key) =>
        CatalogFavoriteKeys.decoration('asset:assets/sticker/$key.png'),
    labelOf: (key) => '스크랩 종이 ${_layoutKeys.indexOf(key) + 1}',
    itemBuilder: (context, key) => Material(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => onLayoutTap?.call(key),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 44, 12, 12),
          child: Column(
            children: [
              Expanded(
                child: Image.asset(
                  'assets/sticker/$key.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '스크랩 종이 ${_layoutKeys.indexOf(key) + 1}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
