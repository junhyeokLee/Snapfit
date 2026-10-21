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
  int _examplePhoto = 0;
  bool get _isFrame => widget.productKey.startsWith('frame:');

  Widget _artwork() => _application
      ? MaterialApplicationPreview(
          productKey: widget.productKey,
          type: widget.type,
          material: widget.preview(context),
          photoIndex: _examplePhoto,
        )
      : MaterialOriginalPreview(
          productKey: widget.productKey,
          child: widget.preview(context),
        );

  void _zoom() => kIsWeb
      ? showWebAwareDialog<void>(
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
                        _application ? '앨범 적용 예시' : widget.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      tooltip: '미리보기 닫기',
                      icon: const Icon(Icons.close),
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
                        child: AspectRatio(aspectRatio: 1, child: _artwork()),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        )
      : showDialog<void>(
          context: context,
          builder: (ctx) => Dialog.fullscreen(
            child: Scaffold(
              backgroundColor: SnapFitColors.backgroundOf(ctx),
              appBar: AppBar(
                backgroundColor: SnapFitColors.backgroundOf(context),
                title: Text(
                  _application ? '앨범 적용 예시' : widget.title,
                  style: ExperienceFormStyle.text(
                    context,
                    16,
                    weight: FontWeight.w600,
                  ),
                ),
                leading: IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
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
                          color: _application
                              ? ExperienceFormStyle.surface(ctx)
                              : MaterialOriginalPreview.backgroundFor(
                                  widget.productKey,
                                ),
                          child: InteractiveViewer(
                            maxScale: 4,
                            child: SizedBox.expand(child: _artwork()),
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
    final product = catalog.asData?.value
        .where((item) => item.productKey == widget.productKey)
        .firstOrNull;
    final unavailable =
        !owned &&
        (product != null
            ? (!product.isActive || product.pointPrice == null)
            : catalog.hasValue &&
                  !freeTemplateMaterialProductKeys.contains(widget.productKey));
    final checking = !owned && catalog.isLoading && !catalog.hasValue;
    final retry = !owned && catalog.hasError && !catalog.hasValue;
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
        : SegmentedButton<bool>(
            key: const ValueKey('material-preview-mode'),
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              side: BorderSide.none,
              shape: const StadiumBorder(),
              backgroundColor: ExperienceFormStyle.surface(context),
              foregroundColor: ExperienceFormStyle.ink(context),
              selectedBackgroundColor: ExperienceFormStyle.selection(context),
              selectedForegroundColor: ExperienceFormStyle.selectionInk(
                context,
              ),
              textStyle: ExperienceFormStyle.text(context, 12),
              minimumSize: const Size(0, 44),
            ),
            segments: const [
              ButtonSegment(value: false, label: Text('소재')),
              ButtonSegment(value: true, label: Text('앨범 적용 예시')),
            ],
            selected: {_application},
            onSelectionChanged: (value) =>
                setState(() => _application = value.single),
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
            CatalogFavoriteButton(
              bookmark: true,
              unframed: true,
              itemKey: widget.favoriteKey,
              label: widget.title,
            ),
          ],
        ),
        if (!landscape && !kIsWeb) title(),
        SizedBox(height: landscape ? 12 : 24),
        Divider(color: ExperienceFormStyle.line(context)),
        const SizedBox(height: 16),
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
        const SizedBox(height: 20),
        _materialUsageLine(
          Icons.collections_bookmark_outlined,
          '여러 앨범에 계속 사용',
          '구매한 소재는 이 계정에서 계속 사용할 수 있어요.',
        ),
        const SizedBox(height: 18),
        _materialUsageLine(
          Icons.layers_outlined,
          _isFrame ? '사진과 분리된 프레임' : '독립된 꾸밈 소재',
          _isFrame ? '미리보기 사진은 포함되지 않아요.' : '예시에 추가한 사진과 문구, 배치는 포함되지 않아요.',
        ),
        const SizedBox(height: 20),
        Text(
          '무료 소재는 구매 없이 이용할 수 있어요.',
          style: ExperienceFormStyle.text(context, 12, secondary: true),
        ),
      ],
    );
    final stage = Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                key: const ValueKey('material-detail-stage'),
                color: _application
                    ? ExperienceFormStyle.surface(context)
                    : MaterialOriginalPreview.backgroundFor(widget.productKey),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    onTap: _zoom,
                    child: CatalogArtworkHero(
                      tag: _application ? null : widget.heroTag,
                      child: _artwork(),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: IconButton(
                  tooltip: '소재 크게 보기',
                  onPressed: _zoom,
                  style: IconButton.styleFrom(
                    backgroundColor: ExperienceFormStyle.surface(context),
                  ),
                  icon: Icon(
                    Icons.open_in_full,
                    size: 18,
                    color: ExperienceFormStyle.ink(context),
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
                    icon: Icon(
                      Icons.refresh,
                      size: 20,
                      color: ExperienceFormStyle.ink(context),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: SizedBox(width: double.infinity, child: mode),
        ),
      ],
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
            onPressed: _busy || checking || unavailable
                ? null
                : retry
                ? () => ref.invalidate(pointShopCatalogProvider)
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
            icon: const Icon(Icons.arrow_back, size: 18),
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
                onPressed: _busy || checking || unavailable
                    ? null
                    : retry
                    ? () => ref.invalidate(pointShopCatalogProvider)
                    : _requestAccess,
                style: ExperienceFormStyle.primary(context),
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
    appBar: const ExperienceHeader(title: '소재 상세'),
    body: body,
  );
}
