import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../shared/web/web_design.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../core/constants/snapfit_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/catalog_favorite_widgets.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/widgets/catalog_artwork_hero.dart';
import '../../../point_shop/data/point_shop_provider.dart';
import '../../../point_shop/presentation/point_shop_access.dart';
import '../widgets/material_application_preview.dart';
import '../widgets/material_original_preview.dart';
import '../widgets/material_album_picker.dart';
import '../../../album/presentation/widgets/create_flow/creation_workspace.dart';

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

  void _zoom() => kIsWeb ? showWebAwareDialog<void>(
    context: context,
    maxWidth: 1000,
    maxHeight: 800,
    builder: (dialogContext) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.fromLTRB(24, 18, 12, 18), child: Row(children: [
        Expanded(child: Text(_application ? '앨범 적용 예시' : widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
        IconButton(onPressed: () => Navigator.pop(dialogContext), tooltip: '미리보기 닫기', icon: const Icon(Icons.close)),
      ])),
      Divider(height: 1, color: WebPalette.of(context).line),
      Expanded(child: ColoredBox(
        color: WebPalette.of(context).canvas,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(child: AspectRatio(aspectRatio: 1, child: _artwork())),
          ),
        ),
      )),
    ]),
  ) : showDialog<void>(
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
        product != null &&
        (!product.isActive || product.pointPrice == null);
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
    final mode = SegmentedButton<bool>(
      key: const ValueKey('material-preview-mode'),
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        backgroundColor: ExperienceFormStyle.surface(context),
        foregroundColor: ExperienceFormStyle.ink(context),
        selectedBackgroundColor: ExperienceFormStyle.selection(context),
        selectedForegroundColor: ExperienceFormStyle.selectionInk(context),
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
                  if (landscape) ...[const SizedBox(height: 6), title()],
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
        if (!landscape) title(),
        SizedBox(height: landscape ? 12 : 24),
        Divider(color: ExperienceFormStyle.line(context)),
        const SizedBox(height: 16),
        Text(
          '소재 이용 안내',
          style: ExperienceFormStyle.text(context, 15, weight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Text(
          '구매한 소재는 이 계정에서 계속 사용할 수 있어요.',
          style: ExperienceFormStyle.text(
            context,
            13,
            color: ExperienceFormStyle.muted(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '무료 소재는 구매 없이 이용할 수 있어요.',
          style: ExperienceFormStyle.text(
            context,
            13,
            color: ExperienceFormStyle.muted(context),
          ),
        ),
        if (widget.type == '프레임') ...[
          const SizedBox(height: 8),
          Text(
            '미리보기 사진은 포함되지 않아요.',
            style: ExperienceFormStyle.text(
              context,
              13,
              color: ExperienceFormStyle.muted(context),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          '예시에 추가한 사진과 문구, 배치는 포함되지 않아요.',
          style: ExperienceFormStyle.text(
            context,
            12,
            color: ExperienceFormStyle.muted(context),
          ),
        ),
      ],
    );
    return _frame(
      body: CreationWorkspace(
        portraitStageHeight: (MediaQuery.sizeOf(context).height * .44).clamp(
          240.0,
          400.0,
        ),
        stage: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    key: const ValueKey('material-detail-stage'),
                    color: _application
                        ? ExperienceFormStyle.surface(context)
                        : MaterialOriginalPreview.backgroundFor(
                            widget.productKey,
                          ),
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
                  if (_application && widget.type != '프레임')
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
        ),
        fields: information,
        actions: Row(
          children: [
            Flexible(
              child: PointShopProductBadge(
                productKey: widget.productKey,
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

  Widget _frame({required Widget body}) {
    if (!kIsWeb) return Scaffold(backgroundColor: SnapFitColors.backgroundOf(context), appBar: const ExperienceHeader(title: '소재 상세'), body: body);
    return SnapFitWebShell(
      section: WebSection.designs,
      actions: [TextButton.icon(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back, size: 18), label: const Text('목록으로'))],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        WebPageHeading(eyebrow: 'DESIGN / MATERIAL', title: widget.title, description: '${widget.type} · 원본 소재와 앨범에 적용한 예시를 비교해보세요.'),
        const SizedBox(height: 24),
        Expanded(child: WebSurface(padding: EdgeInsets.zero, child: body)),
      ]),
    );
  }
}
