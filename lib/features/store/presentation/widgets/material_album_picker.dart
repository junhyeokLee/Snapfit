import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../shared/web/web_design.dart';
import '../../../../core/navigation/web_app_location.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../album/data/api/album_provider.dart';
import '../../../album/domain/entities/album.dart';
import '../../../album/domain/entities/album_page.dart';
import '../../../album/presentation/controllers/store_material_insertion.dart';
import '../../../album/presentation/viewmodels/album_editor_view_model.dart';
import '../../../album/presentation/viewmodels/home_view_model.dart';
import '../../../album/presentation/views/page_editor_screen.dart';
import '../../../album/presentation/widgets/home/home_album_cover_thumbnail.dart';
import '../../../album/presentation/widgets/web/web_saved_album_artwork.dart';
import '../../../point_shop/data/point_shop_provider.dart';
import '../../../point_shop/domain/point_shop_product.dart';
import '../../../point_shop/presentation/point_shop_artwork.dart';
import 'template_page_renderer.dart';
import 'material_original_preview.dart';
import 'template_book_artwork.dart';

Future<T?> _choose<T>(BuildContext context, Widget child) =>
    kIsWeb ? showWebAwareDialog<T>(context: context, maxWidth: 1000, maxHeight: 800, builder: (_) => child) : showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: SnapFitColors.backgroundOf(context),
      constraints: const BoxConstraints(maxWidth: 760),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => child,
    );

Future<void> pickAlbumForMaterial(
  BuildContext context,
  WidgetRef ref, {
  required String productKey,
  required String title,
}) async {
  if (!isStoreMaterialSupported(productKey)) return;
  final selected = await _choose<Album>(
    context,
    MaterialAlbumPicker(productKey: productKey, title: title),
  );
  if (selected == null || !context.mounted) return;
  final repository = ref.read(albumRepositoryProvider);
  final shop = ref.read(pointShopRepositoryProvider);
  final userId = shop.currentUserId;
  bool locked = false;
  try {
    final album = await repository.fetchAlbum(selected.id.toString());
    if (!context.mounted) return;
    if (userId == null || userId != shop.currentUserId) {
      throw const PointShopException('authentication_required');
    }
    if (album.userId != userId) throw StateError('album_read_only');
    if (album.lockedById != null && album.lockedById != userId) {
      throw StateError('album_locked');
    }
    await repository.lockAlbum(album.id);
    locked = true;
    if (!context.mounted || userId != shop.currentUserId) return;
    await ref.read(albumEditorViewModelProvider.future);
    if (!context.mounted || userId != shop.currentUserId) return;
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    await vm.prepareAlbumForEdit(album);
    vm.loadPendingEditAlbumIfNeeded(Size.zero);
    if (!context.mounted || userId != shop.currentUserId) return;
    final page = await _choose<int>(
      context,
      MaterialPagePicker(
        title: title,
        productKey: productKey,
        pages: vm.pages,
        ratio: vm.selectedCover.ratio,
        albumTitle: album.title,
      ),
    );
    if (page == null || !context.mounted || userId != shop.currentUserId)
      return;
    final access = await shop.getAccess(productKey);
    if (!context.mounted || userId != shop.currentUserId) return;
    if (access.productKey != productKey ||
        (!access.owned && !(access.available && access.isFree))) {
      throw const PointShopException('point_shop_product_unavailable');
    }
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        settings: kIsWeb
            ? WebAppRouteSettings(WebAppLocation(WebAppPage.editor, '${album.id}'))
            : null,
        builder: (_) => PageEditorScreen(
          initialPageIndex: page,
          initialMaterialKey: productKey,
        ),
      ),
    );
    if (context.mounted) ref.read(homeViewModelProvider.notifier).refresh();
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is PointShopException
                ? error.message
                : error is StateError && error.message == 'album_locked'
                ? '다른 멤버가 편집 중이에요. 잠시 후 다시 선택해 주세요.'
                : error is StateError && error.message == 'album_read_only'
                ? '이 앨범은 읽기 전용이에요. 직접 만든 앨범을 선택해 주세요.'
                : '앨범을 열지 못했어요. 잠시 후 다시 시도해 주세요.',
          ),
        ),
      );
    }
  } finally {
    if (locked) {
      try {
        await repository.unlockAlbum(selected.id);
      } catch (_) {
        debugPrint('Material editor: could not release album lock');
      }
    }
  }
}

class _PickerShell extends StatelessWidget {
  const _PickerShell({
    required this.heading,
    required this.title,
    required this.productKey,
    required this.child,
    required this.step,
    this.subtitle,
  });
  final String heading, title, productKey;
  final Widget child;
  final int step;
  final String? subtitle;
  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final compact = kIsWeb || screen.width > screen.height;
    final product = Row(
      children: [
        SizedBox(
          width: compact ? 40 : 52,
          height: compact ? 40 : 52,
          child: DecoratedBox(
            // Keep the original artwork legible on either app theme.
            decoration: BoxDecoration(
              color: kIsWeb ? WebPalette.of(context).canvas : const Color(0xFFF3F4EF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: MaterialOriginalPreview(
                productKey: productKey,
                child: PointShopArtwork(productKey: productKey),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: ExperienceFormStyle.text(context, 13),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ExperienceFormStyle.text(context, 12, secondary: true),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    final headingRow = Row(
      children: [
        Expanded(
          child: Text(
            heading,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ExperienceFormStyle.text(
              context,
              18,
              weight: FontWeight.w600,
            ),
          ),
        ),
        Semantics(
          label: '2단계 중 $step단계',
          child: ExcludeSemantics(
            child: Text(
              '$step / 2',
              style: ExperienceFormStyle.text(context, 12, secondary: true),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: '닫기',
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.close,
            size: 22,
            color: ExperienceFormStyle.ink(context),
          ),
        ),
      ],
    );
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, box) => SizedBox(
          height: math.min(
            box.maxHeight,
            screen.height * (compact ? .94 : .88),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
                child: headingRow,
              ),
              Divider(height: 1, color: ExperienceFormStyle.line(context)),
              Expanded(
                child: compact && box.maxWidth >= 520
                    ? Row(
                        children: [
                          SizedBox(
                            width: box.maxWidth < 700 ? 132 : 172,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    height: box.maxHeight < 300 ? 92 : 130,
                                    child: PointShopArtwork(
                                      productKey: productKey,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    title,
                                    style: ExperienceFormStyle.text(
                                      context,
                                      13,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                  if (subtitle != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      subtitle!,
                                      style: ExperienceFormStyle.text(
                                        context,
                                        12,
                                        secondary: true,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          VerticalDivider(
                            width: 1,
                            color: ExperienceFormStyle.line(context),
                          ),
                          Expanded(child: child),
                        ],
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                            child: product,
                          ),
                          Expanded(child: child),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MaterialAlbumPicker extends ConsumerWidget {
  const MaterialAlbumPicker({
    super.key,
    required this.productKey,
    required this.title,
  });
  final String productKey, title;
  @override
  Widget build(BuildContext context, WidgetRef ref) => _PickerShell(
    heading: '사용할 앨범',
    title: title,
    productKey: productKey,
    step: 1,
    child: ref
        .watch(homeViewModelProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(homeViewModelProvider),
              child: const Text('앨범 다시 불러오기'),
            ),
          ),
          data: (albums) => albums.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ExperienceIcon(
                        'BookOpen',
                        size: 32,
                        color: ExperienceFormStyle.muted(context),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '사용할 앨범이 아직 없어요.',
                        style: ExperienceFormStyle.text(
                          context,
                          14,
                          secondary: true,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: albums.length,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: SnapFitColors.overlayLightOf(context),
                  ),
                  itemBuilder: (context, index) {
                    final album = albums[index];
                    final pageCount = album.totalPages > 0
                        ? album.totalPages
                        : album.targetPages;
                    return InkWell(
                      key: ValueKey('material-album-${album.id}'),
                      onTap: () => Navigator.pop(context, album),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 92,
                              height: 100,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: ExperienceFormStyle.surface(context),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: RepaintBoundary(
                                    child: kIsWeb
                                        ? WebSavedAlbumArtwork(album: album)
                                        : HomeAlbumCoverThumbnail(
                                      album: album,
                                      height: 88,
                                      maxWidth: 80,
                                      showShadow: false,
                                      showBookDepth: true,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    album.title.isEmpty
                                        ? '제목 없는 앨범'
                                        : album.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: ExperienceFormStyle.text(
                                      context,
                                      15,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${album.physicalCoverSize.name}${pageCount > 0 ? ' · $pageCount쪽' : ''}',
                                    style: ExperienceFormStyle.text(
                                      context,
                                      12,
                                      secondary: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ExperienceIcon(
                              'ChevronRight',
                              size: 20,
                              color: ExperienceFormStyle.muted(context),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
  );
}

class MaterialPagePicker extends StatelessWidget {
  const MaterialPagePicker({
    super.key,
    required this.title,
    required this.productKey,
    required this.pages,
    required this.ratio,
    this.albumTitle,
  });
  final String title, productKey;
  final String? albumTitle;
  final List<AlbumPage> pages;
  final double ratio;
  @override
  Widget build(BuildContext context) => _PickerShell(
    heading: '적용할 페이지',
    title: title,
    productKey: productKey,
    step: 2,
    subtitle:
        '${albumTitle == null || albumTitle!.isEmpty ? '' : '$albumTitle · '}표지 + ${math.max(0, pages.length - 1)}쪽',
    child: LayoutBuilder(
      builder: (context, box) {
        final columns = ((box.maxWidth - 24) / 156)
            .floor().clamp(kIsWeb ? 1 : 2, kIsWeb ? 6 : 5);
        final compact =
            MediaQuery.sizeOf(context).width >
            MediaQuery.sizeOf(context).height;
        final previewHeight = compact ? 138.0 : 174.0;
        final captionHeight =
            MediaQuery.textScalerOf(context).scale(13) * 1.5 + 20;
        final pageRatio = ratio.isFinite && ratio > 0 ? ratio : 1.0;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          itemCount: pages.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: previewHeight + captionHeight,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (context, index) {
            final label = index == 0 ? '표지' : '$index쪽';
            return Semantics(
              label: '$label에 $title 적용',
              button: true,
              child: InkWell(
                key: ValueKey('material-page-$index'),
                onTap: () => Navigator.pop(context, index),
                borderRadius: BorderRadius.circular(6),
                child: Column(
                  children: [
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: ExperienceFormStyle.surface(context),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: LayoutBuilder(
                            builder: (_, preview) {
                              final fitted = applyBoxFit(
                                BoxFit.contain,
                                Size(pageRatio, 1),
                                preview.biggest,
                              ).destination;
                              return Center(
                                child: RepaintBoundary(
                                  child: SizedBox(
                                    key: ValueKey('material-page-art-$index'),
                                    width: fitted.width,
                                    height: fitted.height,
                                    child: ColoredBox(
                                      color: Color(
                                        pages[index].backgroundColor ??
                                            0xFFFFFFFF,
                                      ),
                                      child: index == 0
                                          ? TemplateBookArtwork(
                                              canvas: Size(
                                                500,
                                                500 / pageRatio,
                                              ),
                                              firstPage: 0,
                                              paired: false,
                                              pageBuilder: (_, wrap) => FittedBox(
                                                child: ColoredBox(
                                                  color: Color(
                                                    pages[index]
                                                            .backgroundColor ??
                                                        0xFFFFFFFF,
                                                  ),
                                                  child: TemplatePageRenderer(
                                                    layers: pages[index].layers,
                                                    width: 500,
                                                    height: 500 / pageRatio,
                                                    designCanvasSize: Size(
                                                      500,
                                                      500 / pageRatio,
                                                    ),
                                                    showCanvasChrome: false,
                                                    wrapSpineArtwork: wrap,
                                                    preserveTypography: true,
                                                    imageDecodeWidth: 384,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : TemplatePageRenderer(
                                              layers: pages[index].layers,
                                              width: fitted.width,
                                              height: fitted.height,
                                              designCanvasSize: Size(
                                                500,
                                                500 / pageRatio,
                                              ),
                                              showCanvasChrome: false,
                                              preserveTypography: true,
                                              imageDecodeWidth: 384,
                                            ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: captionHeight,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: ExperienceFormStyle.text(
                                context,
                                13,
                                weight: index == 0
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          ExperienceIcon(
                            'ArrowRight',
                            size: 16,
                            color: ExperienceFormStyle.muted(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
