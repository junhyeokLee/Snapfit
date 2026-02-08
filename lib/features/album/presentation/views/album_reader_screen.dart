import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/cover_size.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/snapfit_gradient_background.dart';
import '../../domain/entities/album_page.dart';
import '../controllers/layer_builder.dart';
import '../controllers/layer_interaction_manager.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../widgets/reader/album_reader_empty_state.dart';
import '../widgets/reader/album_reader_footer.dart';
import '../widgets/reader/album_reader_page_card.dart';
import '../widgets/reader/album_reader_peek_card.dart';
import '../widgets/reader/album_reader_thumbnail_strip.dart';
import '../widgets/reader/slow_page_physics.dart';

class AlbumReaderScreen extends ConsumerStatefulWidget {
  const AlbumReaderScreen({super.key});

  @override
  ConsumerState<AlbumReaderScreen> createState() => _AlbumReaderScreenState();
}

class _AlbumReaderScreenState extends ConsumerState<AlbumReaderScreen> {
  late final PageController _pageController;
  late final LayerInteractionManager _previewInteraction;
  late final LayerBuilder _previewBuilder;
  Size _baseCanvasSize = const Size(300, 400);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _previewInteraction = LayerInteractionManager.preview(ref, () => _baseCanvasSize);
    _previewBuilder = LayerBuilder(_previewInteraction, () => _baseCanvasSize);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(albumEditorViewModelProvider);
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final state = asyncState.value;

    if (state == null) {
      return const Scaffold(
        backgroundColor: SnapFitColors.background,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final pages = vm.pages.where((p) => !p.isCover).toList(growable: false);
    final pageCount = pages.isEmpty ? 1 : pages.length;
    final coverCanvas = state.coverCanvasSize;
    _baseCanvasSize = coverCanvas ?? coverCanvasBaseSize(state.selectedCover);
    final ratio = _baseCanvasSize.width / _baseCanvasSize.height;

    final screenH = MediaQuery.sizeOf(context).height;
    final pageH = (screenH * 0.58).clamp(260.0, 520.0);
    final pageW = pageH * ratio;

    return Scaffold(
      backgroundColor: SnapFitColors.background,
      body: SnapFitGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: pages.isEmpty
                    ? AlbumReaderEmptyState(
                        isLoading: asyncState.isLoading,
                        baseCanvasSize: _baseCanvasSize,
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            left: 12.w,
                            child: AlbumReaderPeekCard(
                              layers: pages.first.layers,
                              targetW: pageW * 0.38,
                              targetH: pageH * 0.38,
                              previewBuilder: _previewBuilder,
                              baseCanvasSize: _baseCanvasSize,
                            ),
                          ),
                          Positioned(
                            right: 12.w,
                            child: AlbumReaderPeekCard(
                              layers: pages.last.layers,
                              targetW: pageW * 0.38,
                              targetH: pageH * 0.38,
                              previewBuilder: _previewBuilder,
                              baseCanvasSize: _baseCanvasSize,
                            ),
                          ),
                          PageView.builder(
                            controller: _pageController,
                            physics: const SlowPagePhysics(),
                            itemCount: pageCount,
                            itemBuilder: (context, index) {
                              final page = pages[index];
                              final delta = (_pageController.hasClients
                                      ? (_pageController.page ?? index) - index
                                      : 0.0)
                                  .clamp(-1.0, 1.0)
                                  .toDouble();
                              return Center(
                                child: AlbumReaderPageCard(
                                  layers: page.layers,
                                  targetW: pageW,
                                  targetH: pageH,
                                  previewBuilder: _previewBuilder,
                                  baseCanvasSize: _baseCanvasSize,
                                  delta: delta,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
              ),
              if (pages.isNotEmpty) ...[
                AlbumReaderFooter(
                  pageController: _pageController,
                  totalPages: pages.length,
                ),
                AlbumReaderThumbnailStrip(
                  pages: pages,
                  pageController: _pageController,
                  previewBuilder: _previewBuilder,
                  baseCanvasSize: _baseCanvasSize,
                  height: 70.h,
                ),
                SizedBox(height: 10.h),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
