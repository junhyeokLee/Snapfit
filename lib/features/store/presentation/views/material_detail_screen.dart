import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../shared/web/web_design.dart';
import '../widgets/web/web_design_detail_layout.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/templates/free_template_material_policy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/catalog_favorite_widgets.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/widgets/catalog_artwork_hero.dart';
import '../../../point_shop/data/point_shop_provider.dart';
import '../../../point_shop/presentation/point_shop_access.dart';
import '../widgets/material_application_preview.dart';
import '../widgets/material_original_preview.dart';
import '../widgets/material_album_picker.dart';
import '../widgets/store_detail_workspace.dart';
import '../widgets/store_detail_gallery.dart';
import '../../../../shared/widgets/experience_icon.dart';

typedef _MaterialPreviewInputs = ({
  ThemeData theme,
  MediaQueryData? media,
  TextDirection? direction,
  Locale? locale,
  TextStyle textStyle,
  IconThemeData iconTheme,
});

_MaterialPreviewInputs _previewInputs(BuildContext context) => (
  theme: Theme.of(context),
  media: MediaQuery.maybeOf(context),
  direction: Directionality.maybeOf(context),
  locale: Localizations.maybeLocaleOf(context),
  textStyle: DefaultTextStyle.of(context).style,
  iconTheme: IconTheme.of(context),
);

class MaterialDetailScreen extends ConsumerStatefulWidget {
  const MaterialDetailScreen({
    super.key,
    required this.productKey,
    required this.favoriteKey,
    required this.title,
    required this.type,
    required this.preview,
    this.heroTag,
  });

  final String productKey, favoriteKey, title, type;
  final WidgetBuilder preview;
  final Object? heroTag;

  @override
  ConsumerState<MaterialDetailScreen> createState() =>
      _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends ConsumerState<MaterialDetailScreen> {
  bool _busy = false;
  bool _application = false;
  bool _zoomOpen = false;
  int _examplePhoto = 0;
  Widget? _materialPreview;
  _MaterialPreviewInputs? _materialInputs;
  bool get _isFrame => widget.productKey.startsWith('frame:');

  @override
  void didUpdateWidget(MaterialDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preview != widget.preview ||
        oldWidget.productKey != widget.productKey) {
      _materialPreview = null;
    }
  }

  Widget get _material {
    final inputs = _previewInputs(context);
    // Route visibility changes do not change the artwork. Keep one source
    // widget until the material or its actual display inputs change.
    if (_materialInputs != inputs) {
      _materialInputs = inputs;
      _materialPreview = null;
    }
    return _materialPreview ??= widget.preview(context);
  }

  Widget _artwork({bool? application, int? photoIndex}) =>
      (application ?? _application)
      ? MaterialApplicationPreview(
          productKey: widget.productKey,
          type: widget.type,
          material: _material,
          photoIndex: photoIndex ?? _examplePhoto,
        )
      : MaterialOriginalPreview(
          productKey: widget.productKey,
          child: _material,
        );

  Future<void> _zoom() async {
    if (_zoomOpen || !mounted || ModalRoute.of(context)?.isCurrent == false)
      return;
    _zoomOpen = true;
    final application = _application;
    final photoIndex = _examplePhoto;
    // Keep the selected example stable while allowing display inputs to update.
    try {
      final artwork = Builder(
        builder: (zoomContext) {
          // The dialog has its own inherited dependencies. Subscribe here so
          // a theme change also replaces a context-derived, cached source.
          _previewInputs(zoomContext);
          return _artwork(application: application, photoIndex: photoIndex);
        },
      );
      if (kIsWeb) {
        await showWebAwareDialog<void>(
          context: context,
          maxWidth: 1000,
          maxHeight: 800,
          builder: (dialogContext) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 12, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        application ? '앨범 적용 예시' : widget.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      tooltip: '미리보기 닫기',
                      icon: const ExperienceIcon('X'),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: WebPalette.of(context).line),
              Expanded(
                child: ColoredBox(
                  color: WebPalette.of(context).canvas,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Center(
                        child: AspectRatio(aspectRatio: 1, child: artwork),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        final route = DialogRoute<void>(
          context: context,
          builder: (ctx) => Dialog.fullscreen(
            child: Scaffold(
              backgroundColor: SnapFitColors.backgroundOf(ctx),
              appBar: AppBar(
                backgroundColor: SnapFitColors.backgroundOf(context),
                title: Text(
                  application ? '앨범 적용 예시' : widget.title,
                  style: ExperienceFormStyle.text(
                    context,
                    16,
                    weight: FontWeight.w600,
                  ),
                ),
                leading: IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.pop(ctx),
                  icon: const ExperienceIcon('X'),
                ),
              ),
              body: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 700,
                        maxHeight: 700,
                      ),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ColoredBox(
                          color: application
                              ? ExperienceFormStyle.surface(ctx)
                              : MaterialOriginalPreview.backgroundFor(
                                  widget.productKey,
                                ),
                          child: InteractiveViewer(
                            maxScale: 4,
                            child: RepaintBoundary(
                              child: SizedBox.expand(child: artwork),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await Navigator.of(context, rootNavigator: true).push(route);
        await route.completed;
      }
    } finally {
      _zoomOpen = false;
    }
  }

  Future<void> _requestAccess() async {
    if (_busy || ModalRoute.of(context)?.isCurrent == false) return;
    setState(() => _busy = true);
    try {
      final granted = await ensurePointShopAccess(
        context,
        ref,
        productKey: widget.productKey,
        title: widget.title,
      );
      if (granted && mounted && ModalRoute.of(context)?.isCurrent != false) {
        await pickAlbumForMaterial(
          context,
          ref,
          productKey: widget.productKey,
          title: widget.title,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(pointShopCatalogProvider);
    final owned =
        ref
            .watch(ownedPointShopKeysProvider)
            .asData
            ?.value
            .contains(widget.productKey) ??
        false;
    final product = catalog.value
        ?.where((item) => item.productKey == widget.productKey)
        .firstOrNull;
    final unavailable =
        !owned &&
        (product != null
            ? (!product.isActive || product.pointPrice == null)
            : catalog.hasValue &&
                  !freeTemplateMaterialProductKeys.contains(widget.productKey));
    final checking = !owned && catalog.isLoading && !catalog.hasValue;
    final retry = !owned && catalog.hasError && !catalog.isLoading;
    final actionLabel = owned
        ? '사용할 앨범 선택'
        : checking
        ? '가격 확인 중'
        : retry
        ? '가격 다시 확인'
        : unavailable
        ? '판매 준비 중'
        : (product?.pointPrice ?? 0) == 0
        ? '무료로 이용하기'
        : '${product!.pointPrice}P로 구매';
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    Widget title() => Text(
      widget.title,
      style: ExperienceFormStyle.text(
        context,
        22,
        weight: FontWeight.w600,
      ).copyWith(height: 1.3),
    );
    final mode = kIsWeb
        ? Wrap(
            key: const ValueKey('material-preview-mode'),
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final application in [false, true])
                ChoiceChip(
                  label: Text(application ? '앨범 적용 예시' : '원본 소재'),
                  selected: _application == application,
                  onSelected: (_) => setState(() => _application = application),
                  showCheckmark: false,
                  selectedColor: WebPalette.of(context).softBrand,
                ),
            ],
          )
        : StoreGalleryTabs(
            key: const ValueKey('material-preview-mode'),
            labels: const ['소재', '앨범 적용 예시'],
            selected: _application ? 1 : 0,
            onChanged: (value) => setState(() => _application = value == 1),
          );
    final information = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.type,
                    style: ExperienceFormStyle.text(
                      context,
                      12,
                      color: ExperienceFormStyle.muted(context),
                    ),
                  ),
                  if (landscape && !kIsWeb) ...[
                    const SizedBox(height: 6),
                    title(),
                  ],
                ],
              ),
            ),
            if (kIsWeb)
              CatalogFavoriteButton(
                bookmark: true,
                unframed: true,
                itemKey: widget.favoriteKey,
                label: widget.title,
              ),
          ],
        ),
        if (!landscape && !kIsWeb) title(),
        const SizedBox(height: 12),
        if (!kIsWeb)
          Text(
            '원본 비율 유지 · 크기와 회전 조절',
            style: ExperienceFormStyle.text(context, 12, secondary: true),
          ),
        const SizedBox(height: 20),
        if (kIsWeb)
          Row(
            children: [
              Expanded(
                child: Text(
                  '소재 이용 안내',
                  style: ExperienceFormStyle.text(
                    context,
                    16,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(
                child: Align(
                  alignment: Alignment.topRight,
                  child: PointShopProductBadge(
                    productKey: widget.productKey,
                    unlistedLabel:
                        freeTemplateMaterialProductKeys.contains(
                          widget.productKey,
                        )
                        ? '무료'
                        : '판매 준비 중',
                    compact: false,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
        if (kIsWeb) const SizedBox(height: 20),
        if (kIsWeb)
          _materialUsageLine(
            Icons.collections_bookmark_outlined,
            '여러 앨범에 계속 사용',
            '구매한 소재는 이 계정에서 계속 사용할 수 있어요.',
          ),
        if (kIsWeb) const SizedBox(height: 18),
        if (kIsWeb)
          _materialUsageLine(
            Icons.layers_outlined,
            _isFrame ? '사진과 분리된 프레임' : '독립된 꾸밈 소재',
            _isFrame ? '미리보기 사진은 포함되지 않아요.' : '예시에 추가한 사진과 문구, 배치는 포함되지 않아요.',
          ),
        if (!kIsWeb)
          StoreDetailSection(
            key: const ValueKey('material-gallery-information'),
            title: '소재 이용 안내',
            summary: _isFrame
                ? '프레임만 제공 · 미리보기 사진 제외'
                : '꾸밈 소재만 제공 · 예시에 추가한 사진과 문구 제외',
            child: Column(
              children: [
                _materialUsageLine(
                  Icons.collections_bookmark_outlined,
                  '여러 앨범에 계속 사용',
                  '구매한 소재는 이 계정에서 계속 사용할 수 있어요.',
                ),
                const SizedBox(height: 18),
                _materialUsageLine(
                  Icons.layers_outlined,
                  _isFrame ? '사진과 분리된 프레임' : '독립된 꾸밈 소재',
                  _isFrame
                      ? '미리보기 사진은 포함되지 않아요.'
                      : '예시에 추가한 사진과 문구, 배치는 포함되지 않아요.',
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Text(
          '무료 소재는 구매 없이 이용할 수 있어요.',
          style: ExperienceFormStyle.text(context, 12, secondary: true),
        ),
      ],
    );
    final artwork = Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          key: const ValueKey('material-detail-stage'),
          color: _application
              ? ExperienceFormStyle.surface(context)
              : MaterialOriginalPreview.backgroundFor(widget.productKey),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GestureDetector(
              onTap: _zoom,
              child: CatalogArtworkHero(
                tag: _application ? null : widget.heroTag,
                child: _artwork(),
              ),
            ),
          ),
        ),
        if (_application && !_isFrame)
          Positioned(
            left: 8,
            bottom: 8,
            child: IconButton(
              key: const ValueKey('material-example-next'),
              tooltip: '다른 사진으로 보기',
              onPressed: () => setState(() => _examplePhoto++),
              style: IconButton.styleFrom(
                backgroundColor: ExperienceFormStyle.surface(context),
              ),
              icon: ExperienceIcon('RefreshCw', size: 20, color: ExperienceFormStyle.ink(context),
              ),
            ),
          ),
      ],
    );
    final stage = Padding(
      padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 0 : 18),
      child: Column(
        children: [
          mode,
          const SizedBox(height: 8),
          Expanded(
            child: StoreGallerySurface(
              onExpand: _zoom,
              expandTooltip: '소재 크게 보기',
              child: artwork,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _application ? '사진과 함께 배치한 모습' : '원본 소재',
                    style: ExperienceFormStyle.text(
                      context,
                      11,
                      secondary: true,
                    ),
                  ),
                ),
                Text(
                  '원본 비율 유지',
                  style: ExperienceFormStyle.text(context, 11, secondary: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (kIsWeb) {
      final palette = WebPalette.of(context);
      final preview = WebSurface(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 6,
              children: [
                Text(
                  '소재 미리보기',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
                Text(
                  '원본 비율로 표시',
                  style: TextStyle(fontSize: 12, color: palette.muted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(child: stage),
          ],
        ),
      );
      final action = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 22,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.type} · 앨범 편집에 사용할 소재',
            style: TextStyle(fontSize: 13, color: palette.muted),
          ),
          const SizedBox(height: 18),
          PointShopProductBadge(
            productKey: widget.productKey,
            unlistedLabel:
                freeTemplateMaterialProductKeys.contains(widget.productKey)
                ? '무료'
                : '판매 준비 중',
            compact: false,
          ),
          const SizedBox(height: 18),
          FilledButton(
            key: const ValueKey('material-access'),
            onPressed: _busy || checking
                ? null
                : retry
                ? () => ref.invalidate(pointShopCatalogProvider)
                : unavailable
                ? null
                : _requestAccess,
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(actionLabel),
          ),
          const SizedBox(height: 12),
          Text(
            '사용할 앨범을 선택한 다음 편집 화면에서 위치와 크기를 조절하세요.',
            style: TextStyle(fontSize: 13, height: 1.6, color: palette.muted),
          ),
        ],
      );
      return SnapFitWebShell(
        section: WebSection.designs,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.maybePop(context),
            icon: const ExperienceIcon('ArrowLeft', size: 18),
            label: const Text('목록으로'),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WebPageHeading(title: '소재 상세'),
            const SizedBox(height: 20),
            Expanded(
              child: WebDesignDetailLayout(
                preview: preview,
                action: action,
                information: information,
              ),
            ),
          ],
        ),
      );
    }
    return _frame(
      body: StoreDetailWorkspace(
        portraitStageHeight: (MediaQuery.sizeOf(context).height * .44).clamp(
          260.0,
          384.0,
        ),
        stage: stage,
        fields: information,
        actions: Row(
          children: [
            Flexible(
              child: PointShopProductBadge(
                productKey: widget.productKey,
                unlistedLabel:
                    freeTemplateMaterialProductKeys.contains(widget.productKey)
                    ? '무료'
                    : '판매 준비 중',
                compact: false,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: FilledButton(
                key: const ValueKey('material-access'),
                onPressed: _busy || checking
                    ? null
                    : retry
                    ? () => ref.invalidate(pointShopCatalogProvider)
                    : unavailable
                    ? null
                    : _requestAccess,
                style: StoreGalleryStyle.primary(context),
                child: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _materialUsageLine(IconData icon, String title, String detail) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(
          icon,
          size: 20,
          color: ExperienceFormStyle.selectionInk(context),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: ExperienceFormStyle.text(
                context,
                13,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              detail,
              style: ExperienceFormStyle.text(
                context,
                12,
                secondary: true,
              ).copyWith(height: 1.55),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _frame({required Widget body}) => Scaffold(
    backgroundColor: SnapFitColors.backgroundOf(context),
    appBar: ExperienceHeader(
      title: '소재 상세',
      showNotifications: false,
      showDivider: false,
      actions: [
        CatalogFavoriteButton(
          bookmark: true,
          unframed: true,
          itemKey: widget.favoriteKey,
          label: widget.title,
        ),
      ],
    ),
    body: body,
  );
}
