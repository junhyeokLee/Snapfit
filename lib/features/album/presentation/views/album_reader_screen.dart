import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/cover_size.dart';
import '../controllers/layer_builder.dart';
import '../controllers/layer_interaction_manager.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../widgets/reader/album_reader_empty_state.dart';
import '../widgets/reader/album_reader_footer.dart';
import '../widgets/reader/album_reader_page_card.dart';
import '../widgets/reader/album_reader_peek_card.dart';
import '../widgets/reader/album_reader_thumbnail_strip.dart';
import '../widgets/reader/slow_page_physics.dart';

/// 읽기 전용: 앨범 페이지를 크게 보는 화면
class AlbumReaderScreen extends ConsumerStatefulWidget {
  const AlbumReaderScreen({super.key});

  @override
  ConsumerState<AlbumReaderScreen> createState() => _AlbumReaderScreenState();
}

class _AlbumReaderScreenState extends ConsumerState<AlbumReaderScreen> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.97);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(albumEditorViewModelProvider);
    final state = asyncState.value;
    final vm = ref.read(albumEditorViewModelProvider.notifier);

    if (state == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (state.coverCanvasSize == null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        final baseSize = coverCanvasBaseSize(state.selectedCover);
        vm.loadPendingEditAlbumIfNeeded(baseSize);
      });
    }

    final pages = vm.pages.where((p) => !p.isCover).toList();
    final baseCanvasSize = coverCanvasBaseSize(state.selectedCover);
    final pageRatio = baseCanvasSize.width / baseCanvasSize.height;

    final previewInteraction = LayerInteractionManager.preview(
      ref,
      () => baseCanvasSize,
    );
    final previewBuilder = LayerBuilder(previewInteraction, () => baseCanvasSize);

    return Scaffold(
      backgroundColor: const Color(0xFF7d7a97),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "앨범 보기",
          style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final pageSize = calculatePagePreviewSize(
                  screen: MediaQuery.sizeOf(context),
                  constraints: constraints,
                  pageRatio: pageRatio,
                  maxHeightFactor: kPageReaderPreviewMaxHeightFactor,
                );
                final targetW = pageSize.width;
                final targetH = pageSize.height;

                return pages.isEmpty
                    ? AlbumReaderEmptyState(
                        isLoading: state.coverCanvasSize == null,
                        baseCanvasSize: baseCanvasSize,
                      )
                    : PageView.builder(
                        controller: _pageController,
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        physics: const SlowPagePhysics(),
                        itemCount: pages.length,
                        itemBuilder: (context, index) {
                          final page = pages[index];
                          final prevPage = (index - 1 >= 0) ? pages[index - 1] : null;
                          final nextPage = (index + 1 < pages.length) ? pages[index + 1] : null;
                          return AnimatedBuilder(
                            animation: _pageController,
                            builder: (context, child) {
                              final current = _pageController.hasClients
                                  ? (_pageController.page ?? index.toDouble())
                                  : index.toDouble();
                              final delta = (current - index).clamp(-1.0, 1.0);
                              final eased = Curves.easeOutCubic.transform(delta.abs()) * delta.sign;
                              final tilt = 0.14 * eased;
                              final alignment =
                                  delta >= 0 ? Alignment.centerLeft : Alignment.centerRight;

                              return Center(
                                child: Transform(
                                  alignment: alignment,
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, 0.02)
                                    ..rotateY(tilt),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.center,
                                    children: [
                                      if (prevPage != null)
                                        Positioned(
                                          left: -targetW * 0.18,
                                          child: SizedBox(
                                            width: targetW * 0.32,
                                            height: targetH,
                                            child: Opacity(
                                              opacity: 0.65,
                                              child: AlbumReaderPeekCard(
                                                layers: prevPage.layers,
                                                targetW: targetW * 0.32,
                                                targetH: targetH,
                                                previewBuilder: previewBuilder,
                                                baseCanvasSize: baseCanvasSize,
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (nextPage != null)
                                        Positioned(
                                          right: -targetW * 0.18,
                                          child: SizedBox(
                                            width: targetW * 0.32,
                                            height: targetH,
                                            child: Opacity(
                                              opacity: 0.65,
                                              child: AlbumReaderPeekCard(
                                                layers: nextPage.layers,
                                                targetW: targetW * 0.32,
                                                targetH: targetH,
                                                previewBuilder: previewBuilder,
                                                baseCanvasSize: baseCanvasSize,
                                              ),
                                            ),
                                          ),
                                        ),
                                      AlbumReaderPageCard(
                                        layers: page.layers,
                                        targetW: targetW,
                                        targetH: targetH,
                                        previewBuilder: previewBuilder,
                                        baseCanvasSize: baseCanvasSize,
                                        delta: delta,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
              },
            ),
          ),
          if (pages.isNotEmpty)
            AlbumReaderFooter(
              pageController: _pageController,
              totalPages: pages.length,
            ),
          AlbumReaderThumbnailStrip(
            pages: pages,
            pageController: _pageController,
            previewBuilder: previewBuilder,
            baseCanvasSize: baseCanvasSize,
            height: 70.h,
          ),
        ],
      ),
    );
  }
}
