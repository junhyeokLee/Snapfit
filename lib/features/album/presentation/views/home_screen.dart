import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/cache/snapfit_cache_manager.dart';
import '../../../../shared/snapfit_image.dart';
import '../../../../core/constants/cover_size.dart';
import '../../../../core/constants/cover_theme.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/layer.dart';
import '../../domain/entities/layer_export_mapper.dart';
import '../widgets/cover/cover.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../viewmodels/home_view_model.dart';
import 'add_cover_screen.dart';
import 'album_spread_screen.dart';
import 'fanned_pages_view.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(homeViewModelProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7d7a97), Color(0xFF9893a9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: albumsAsync.when(
          data: (albums) {
            final sorted = List<Album>.from(albums)
              ..sort((a, b) => (b.createdAt).compareTo(a.createdAt));
            return sorted.isEmpty
                ? _buildEmptyState(context, ref)
                : _AlbumSlider(albums: sorted);
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          error: (err, stack) => _buildErrorState(context, err, ref),
        ),
      ),
    );
  }

  static Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Center(
          child: Text(
            '앨범이 비어있습니다.',
            style: TextStyle(fontSize: 18.sp, color: Colors.white.withOpacity(0.9)),
          ),
        ),
        Positioned(
          bottom: 80.h,
          child: _CircleActionButton(
            icon: Icons.add,
            onPressed: () async {
              final created = await Navigator.pushNamed(context, '/add_cover');
              if (created == true && context.mounted) {
                await ref.read(homeViewModelProvider.notifier).refresh();
              }
            },
          ),
        ),
      ],
    );
  }

  static Widget _buildErrorState(BuildContext context, Object err, WidgetRef ref) {
    final isTimeout = err is DioException &&
        err.type == DioExceptionType.connectionTimeout;
    if (isTimeout) {
      return _buildEmptyState(context, ref);
    }

    final isConnectionRefused =
        err is DioException && err.type == DioExceptionType.connectionError;
    final textColor = Colors.white.withOpacity(0.9);
    final subColor = Colors.white.withOpacity(0.7);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 48.sp, color: subColor),
            SizedBox(height: 16.h),
            Text(
              isConnectionRefused
                  ? '서버에 연결할 수 없습니다\n(Connection refused)'
                  : '에러 발생',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: textColor),
              textAlign: TextAlign.center,
            ),
            if (isConnectionRefused) ...[
              SizedBox(height: 12.h),
              Text(
                '• 백엔드를 0.0.0.0:8080 으로 실행했는지 확인\n'
                '• PC와 폰이 같은 Wi‑Fi인지 확인\n'
                '• dio_provider의 baseUrl을 PC LAN IP로 설정',
                style: TextStyle(fontSize: 13.sp, color: subColor),
                textAlign: TextAlign.center,
              ),
            ] else
              Padding(
                padding: EdgeInsets.only(top: 12.h),
                child: Text('$err', style: TextStyle(fontSize: 13.sp, color: subColor)),
              ),
          ],
        ),
      ),
    );
  }
}

const _coverRadius = BorderRadius.only(
  topRight: Radius.circular(12),
  bottomRight: Radius.circular(12),
  bottomLeft: Radius.zero,
);

/// 포커스 시 앨범 생성 페이지(cover.dart)와 동일한 그림자 + 살짝 들리는 애니메이션
/// - 그림자: cover.dart _AnimatedCoverContainer와 동일 (focus 0 → 기본, focus 1 → 선택 시)
/// - 들림: scale 1.03 + 위로 살짝 이동
/// [applyShadow] false면 그림자 없음 (레이어 커버는 CoverLayout 자체 그림자 사용)
class _FocusWrap extends StatelessWidget {
  final double focus;
  final bool applyShadow;
  final Widget child;

  const _FocusWrap({
    required this.focus,
    required this.child,
    this.applyShadow = true,
  });

  /// 앨범 생성 페이지 cover.dart 오른쪽·아래쪽 그림자와 동일한 비율로 맞춤
  /// [scale] = 메인 커버 너비 / 앨범생성 커버 기준 너비(280)
  /// [focus] 0→1 일 때 기본 그림자에서 들어올린(animate) 그림자로 보간 → 커질 때 그림자도 함께 강해짐
  static List<BoxShadow> coverStyleShadowForScale(double scale, [double focus = 0]) {
    final baseOffset1 = const Offset(14, 12);
    final liftedOffset1 = const Offset(14, 44);
    final baseOffset2 = const Offset(24, 12);
    final liftedOffset2 = const Offset(28, 44);
    final blur1 = 1 + 10 * focus;   // 10 → 20
    final blur2 = 1 + 8 * focus;    // 10 → 18
    return [
      BoxShadow(
        color: Color.lerp(
          Colors.black.withOpacity(0.12),
          Colors.black.withOpacity(0.18),
          focus,
        )!,
        blurRadius: blur1 * scale,
        offset: Offset.lerp(baseOffset1, liftedOffset1, focus)! * scale,
      ),
      BoxShadow(
        color: Color.lerp(
          const Color(0xFF5c5d8d).withOpacity(0.12),
          const Color(0xFF5c5d8d).withOpacity(0.18),
          focus,
        )!,
        blurRadius: blur2 * scale,
        offset: Offset.lerp(baseOffset2, liftedOffset2, focus)! * scale,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scale = 0.98 + 0.15 * focus;
    // 포커스일수록 살짝 위로 들림 (픽셀)
    final translateY = -18.0 * focus;

    final content = Transform.translate(
      offset: Offset(0, translateY),
      child: Transform.scale(
        scale: scale,
        child: applyShadow
            ? Container(
                decoration: BoxDecoration(
                  borderRadius: _coverRadius,
                  boxShadow: coverStyleShadowForScale(1.0),
                ),
                child: child,
              )
            : child,
      ),
    );
    return content;
  }
}

/// PageController 보유, 스크롤 시 포커스(페이지) 기반 그림자/스케일 보간
/// 커버 가운데 아래 쪽에 추가/휴지통 원형 버튼 배치, 휴지통은 현 위치(포커스) 앨범만 삭제
class _AlbumSlider extends ConsumerStatefulWidget {
  final List<Album> albums;

  const _AlbumSlider({required this.albums});

  @override
  ConsumerState<_AlbumSlider> createState() => _AlbumSliderState();
}

class _AlbumSliderState extends ConsumerState<_AlbumSlider> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    // 한 화면에 "가운데 1장 + 양옆 카드가 동시에 보이도록" 설정
    _pageController = PageController(viewportFraction: 0.7);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int get _currentPage {
    final p = _pageController.page;
    if (p == null) return 0;
    final i = p.round().clamp(0, widget.albums.length - 1);
    return i;
  }

  Future<void> _onAddPressed(BuildContext context) async {
    final created = await Navigator.pushNamed(context, '/add_cover');
    if (created == true && context.mounted) {
      await ref.read(homeViewModelProvider.notifier).refresh();
    }
  }

  Future<void> _onDeletePressed(BuildContext context) async {
    if (widget.albums.isEmpty) return;
    final album = widget.albums[_currentPage];
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 200),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.8 + 0.2 * value,
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: Container(
            constraints: BoxConstraints(maxWidth: 320.w),
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20.r,
                  offset: Offset(0, 10.h),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8.r,
                  offset: Offset(0, 4.h),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 아이콘
                Container(
                  width: 64.w,
                  height: 64.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 32.sp,
                    color: const Color(0xFFE53935),
                  ),
                ),
                SizedBox(height: 20.h),
                // 제목
                Text(
                  '앨범 삭제',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 12.h),
                // 내용
                Text(
                  '이 앨범을 삭제하시겠어요?\n복구할 수 없습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 24.h),
                // 버튼들
                Row(
                  children: [
                    // 취소 버튼
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(ctx).pop(false),
                          borderRadius: BorderRadius.circular(12.r),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              '취소',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    // 삭제 버튼
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(ctx).pop(true),
                          borderRadius: BorderRadius.circular(12.r),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFE53935),
                                  Color(0xFFC62828),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12.r),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE53935).withOpacity(0.3),
                                  blurRadius: 8.r,
                                  offset: Offset(0, 4.h),
                                ),
                              ],
                            ),
                            child: Text(
                              '삭제',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(homeViewModelProvider.notifier).deleteAlbum(album);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('앨범이 삭제되었습니다.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }

  Future<void> _onEditPressed(BuildContext context) async {
    if (widget.albums.isEmpty) return;
    final album = widget.albums[_currentPage];
    try {
      final vm = ref.read(albumEditorViewModelProvider.notifier);
      await ref.read(albumEditorViewModelProvider.future);
      await vm.prepareAlbumForEdit(album);
      if (!context.mounted) return;
      // 연필 아이콘: "앨범 생성/커버 편집" 화면으로 이동해서 커버를 다시 수정할 수 있게 함
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddCoverScreen(editAlbum: album),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('앨범 편집을 열 수 없습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        AnimatedBuilder(
          animation: _pageController,
          builder: (context, _) {
            return PageView.builder(
              controller: _pageController,
              itemCount: widget.albums.length,
              itemBuilder: (context, index) {
                final album = widget.albums[index];
                return _AlbumCoverCard(
                  album: album,
                  index: index,
                  pageController: _pageController,
                );
              },
            );
          },
        ),
        // 커버 가운데 아래 쪽 원형 버튼: 추가 / 휴지통 (현 위치 앨범만 삭제)
        Positioned(
          bottom: 80.h,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CircleActionButton(
                icon: Icons.add,
                onPressed: () => _onAddPressed(context),
              ),
              SizedBox(width: 16.w),
              _CircleActionButton(
                icon: Icons.edit_outlined,
                onPressed: widget.albums.isEmpty ? null : () => _onEditPressed(context),
              ),
              SizedBox(width: 16.w),
              _CircleActionButton(
                icon: Icons.delete_outline,
                onPressed: widget.albums.isEmpty
                    ? null
                    : () => _onDeletePressed(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 커버 아래 중앙에 쓰는 원형 액션 버튼
class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _CircleActionButton({
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.25),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48.w,
          height: 48.w,
          child: Icon(icon, color: Colors.white, size: 24.sp),
        ),
      ),
    );
  }
}

class _AlbumCoverCard extends ConsumerStatefulWidget {
  final Album album;
  final int index;
  final PageController pageController;

  const _AlbumCoverCard({
    required this.album,
    required this.index,
    required this.pageController,
  });

  @override
  ConsumerState<_AlbumCoverCard> createState() => _AlbumCoverCardState();
}

class _AlbumCoverCardState extends ConsumerState<_AlbumCoverCard>
    with SingleTickerProviderStateMixin {
  final GlobalKey _coverRepaintKey = GlobalKey();
  late final AnimationController _tapController;
  late final Animation<double> _tapScale;
  Timer? _pendingUnpress;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _tapScale = Tween<double>(begin: 1, end: 0.92).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeOut),
    );
  }

  void _cancelPendingUnpress() {
    _pendingUnpress?.cancel();
    _pendingUnpress = null;
  }

  @override
  void dispose() {
    _cancelPendingUnpress();
    _tapController.dispose();
    super.dispose();
  }

  /// 0..1, 포커스일수록 1 (중앙에 가까울수록 1)
  double _focusFactor() {
    final page = widget.pageController.page ?? widget.index.toDouble();
    final diff = (page - widget.index).abs();
    if (diff >= 1) return 0;
    return 1 - diff;
  }

  @override
  Widget build(BuildContext context) {
    final coverSize = coverSizes.firstWhere(
      (s) => s.ratio.toString() == widget.album.ratio,
      orElse: () => coverSizes.first,
    );
    final focus = _focusFactor();

    return Padding(
      // 카드 간격을 줄여 여러 장이 동시에 보이도록
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 40.h),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 홈 셀(PageView 뷰포트) 안에서 세로/가로/정사각형이 같은 비중으로 보이도록
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final base = w < h ? w : h;
          final ratio = coverSize.ratio;
          final canvasSize = ratio <= 1
              ? Size(base * ratio, base)
              : Size(base, base / ratio);

          Widget coverContent;

          if (widget.album.coverLayersJson.isNotEmpty) {
            List<LayerModel>? layers;
            try {
              final decoded =
                  jsonDecode(widget.album.coverLayersJson) as Map<String, dynamic>;
              // 새 형식: pages 배열 → 커버(0번) 레이어 추출. 기존: layers 직접
              final pages = decoded['pages'] as List<dynamic>?;
              final List<dynamic> layerList = (pages != null && pages.isNotEmpty)
                  ? ((pages[0] as Map<String, dynamic>)['layers'] as List?) ?? []
                  : (decoded['layers'] as List?) ?? [];
              layers = layerList
                  .map(
                    (l) => LayerExportMapper.fromJson(
                      l as Map<String, dynamic>,
                      canvasSize: canvasSize,
                    ),
                  )
                  .toList();
            } catch (_) {
              layers = null;
            }
            if (layers != null && layers.isNotEmpty) {
              coverContent = SizedBox(
                width: base,
                height: base,
                child: CoverLayout(
                  aspect: coverSize.ratio,
                  layers: layers,
                  isInteracting: false,
                  leftSpine: 14.0,
                  onCoverSizeChanged: (_) {},
                  buildImage: (layer) => _buildStaticImage(layer),
                  buildText: (layer) => _buildStaticText(layer),
                  sortedByZ: (list) =>
                      list..sort((a, b) => a.id.compareTo(b.id)),
                  theme: CoverTheme.classic,
                ),
              );
            } else {
              // 레이어 파싱 실패 또는 빈 레이어 → coverImageUrl 폴백
              final imageUrl =
                  widget.album.coverThumbnailUrl ??
                  widget.album.coverPreviewUrl ??
                  widget.album.coverImageUrl;
              final hasUrl = (imageUrl as String?)?.isNotEmpty == true;
              final cw = ratio >= 1 ? base : base * ratio;
              final ch = ratio <= 1 ? base : base / ratio;
              final shadowScale = cw / 180;
              coverContent = SizedBox(
                width: cw,
                height: ch,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: _coverRadius,
                    boxShadow: _FocusWrap.coverStyleShadowForScale(
                        shadowScale, focus),
                  ),
                  child: ClipRRect(
                    borderRadius: _coverRadius,
                    child: hasUrl
                        ? SnapfitImage(
                            urlOrGs: imageUrl as String,
                            fit: BoxFit.cover,
                            cacheManager: snapfitImageCacheManager,
                          )
                        : Container(
                            color: Colors.grey[300],
                            child: Icon(
                              Icons.photo_album_outlined,
                              size: 48.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                  ),
                ),
              );
            }
          } else {
            final imageUrl =
                widget.album.coverThumbnailUrl ??
                widget.album.coverPreviewUrl ??
                widget.album.coverImageUrl;
            final hasUrl = (imageUrl as String?)?.isNotEmpty == true;
            final cw = ratio >= 1 ? base : base * ratio;
            final ch = ratio <= 1 ? base : base / ratio;
            final shadowScale = cw / 180;

            coverContent = SizedBox(
              width: cw,
              height: ch,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: _coverRadius,
                  boxShadow: _FocusWrap.coverStyleShadowForScale(
                      shadowScale, focus),
                ),
                child: ClipRRect(
                  borderRadius: _coverRadius,
                  child: hasUrl
                      ? SnapfitImage(
                          urlOrGs: imageUrl as String,
                          fit: BoxFit.cover,
                          cacheManager: snapfitImageCacheManager,
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: Icon(
                            Icons.photo_album_outlined,
                            size: 48.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                ),
              ),
            );
          }

          final closedCover = RepaintBoundary(
            key: _coverRepaintKey,
            child: _FocusWrap(
              focus: focus,
              applyShadow: false,
              child: Center(child: coverContent),
            ),
          );

          return GestureDetector(
            onTapDown: (_) {
              _cancelPendingUnpress();
              _tapController.forward();
            },
            onTapUp: (_) {
              _cancelPendingUnpress();
              _pendingUnpress = Timer(const Duration(milliseconds: 120), () {
                if (mounted) _tapController.reverse();
                _pendingUnpress = null;
              });
            },
            onTapCancel: () {
              _cancelPendingUnpress();
              _tapController.reverse();
            },
            onTap: () => _onTapThenNavigate(context),
            child: AnimatedBuilder(
              animation: _tapScale,
              builder: (context, child) {
                return Transform.scale(
                  scale: _tapScale.value,
                  alignment: Alignment.center,
                  child: Opacity(
                    opacity: _tapScale.value,
                    child: child,
                  ),
                );
              },
              child: closedCover,
            ),
          );
        },
      ),
    );
  }

  /// 눌림 애니메이션이 끝난 뒤에만 화면 전환 (짧게 눌러도 무조건 다 눌린 다음 넘어감)
  void _onTapThenNavigate(BuildContext context) {
    _cancelPendingUnpress();
    _tapController.forward();
    void onStatus(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        _tapController.removeStatusListener(onStatus);
        _tapController.reset();
        _handleTap(context);
      }
    }
    if (_tapController.status == AnimationStatus.completed) {
      _tapController.reset();
      _handleTap(context);
      return;
    }
    _tapController.addStatusListener(onStatus);
  }

  Future<void> _handleTap(BuildContext context) async {
    Rect? cardRect;
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final offset = box.localToGlobal(Offset.zero);
      cardRect = Rect.fromLTWH(offset.dx, offset.dy, box.size.width, box.size.height);
    }

    try {
      final vm = ref.read(albumEditorViewModelProvider.notifier);
      await ref.read(albumEditorViewModelProvider.future);
      await vm.prepareAlbumForEdit(widget.album);
      if (!context.mounted) return;

      // 바로 반응: 준비 완료 즉시 라우트 푸시(커버 캡처 대기 없음)
      Navigator.of(context).push(
        _PaperUnfoldRoute(cardRect: cardRect, coverImage: null),
      );
    } catch (e) {
      if (mounted) _tapController.reverse();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('앨범 편집을 열 수 없습니다: $e')),
        );
      }
    }
  }

  Widget _buildStaticImage(LayerModel layer) {
    final url = layer.previewUrl ?? layer.imageUrl ?? layer.originalUrl ?? '';
    if (url.isEmpty) {
      return Container(color: Colors.grey[300]);
    }
    return SnapfitImage(
      urlOrGs: url,
      fit: BoxFit.cover,
      cacheManager: snapfitImageCacheManager,
    );
  }

  Widget _buildStaticText(LayerModel layer) {
    return Text(
      layer.text ?? '',
      style: layer.textStyle,
      textAlign: layer.textAlign,
    );
  }
}

/// Paper: 앨범 페이지 편집 화면으로 갈 때 커버가 부채꼴로 펼쳐지며 드러나는 커스텀 라우트
class _PaperUnfoldRoute extends PageRouteBuilder {
  _PaperUnfoldRoute({Rect? cardRect, ui.Image? coverImage})
      : _cardRect = cardRect,
        _coverImage = coverImage,
        super(
          opaque: true,
          transitionDuration: const Duration(milliseconds: 220),
          reverseTransitionDuration: const Duration(milliseconds: 180),
          pageBuilder: (context, animation, secondaryAnimation) {
            return _PaperUnfoldPage(
              cardRect: cardRect,
              coverImage: coverImage,
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              ),
            );
          },
        );

  final Rect? _cardRect;
  final ui.Image? _coverImage;
}

/// 라우트 위에 커버 열림 오버레이를 붙이고, 열림 애니메이션 후 앨범 페이지 편집 화면만 보이게 함
class _PaperUnfoldPage extends StatefulWidget {
  final Rect? cardRect;
  final ui.Image? coverImage;

  const _PaperUnfoldPage({this.cardRect, this.coverImage});

  @override
  State<_PaperUnfoldPage> createState() => _PaperUnfoldPageState();
}

class _PaperUnfoldPageState extends State<_PaperUnfoldPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _coverController;
  late final Animation<double> _coverAnimation;

  @override
  void initState() {
    super.initState();
    _coverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _coverAnimation = CurvedAnimation(
      parent: _coverController,
      curve: Curves.easeOutCubic,
    );
    _coverController.forward();
  }

  @override
  void dispose() {
    _coverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = const AlbumSpreadScreen();
    final hasOverlay = widget.coverImage != null &&
        widget.cardRect != null &&
        !widget.cardRect!.isEmpty;

    if (!hasOverlay) {
      return content;
    }

    final rect = widget.cardRect!;
    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        Positioned(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          child: _CoverOpenOverlay(
            animation: _coverAnimation,
            coverImage: widget.coverImage!,
            openFromRight: true,
          ),
        ),
      ],
    );
  }
}

/// 열린 책 상태: 캡처한 커버 rect·이미지 (Paper 전환용)
class _OpenedBookData {
  final Rect? cardRect;
  final ui.Image? coverImage;
  const _OpenedBookData({this.cardRect, this.coverImage});
}

/// Paper: 같은 화면에서 커버가 열리며 부채꼴 페이지가 드러나는 뷰
class _UnfoldBookView extends ConsumerStatefulWidget {
  final WidgetRef ref;
  final _OpenedBookData openedBook;
  final VoidCallback onClose;

  const _UnfoldBookView({
    required this.ref,
    required this.openedBook,
    required this.onClose,
  });

  @override
  ConsumerState<_UnfoldBookView> createState() => _UnfoldBookViewState();
}

class _UnfoldBookViewState extends ConsumerState<_UnfoldBookView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _coverController;
  late final Animation<double> _coverAnimation;

  @override
  void initState() {
    super.initState();
    _coverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _coverAnimation = CurvedAnimation(
      parent: _coverController,
      curve: Curves.easeOutCubic,
    );
    _coverController.forward();
  }

  @override
  void dispose() {
    _coverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasCoverOverlay = widget.openedBook.coverImage != null &&
        widget.openedBook.cardRect != null &&
        !widget.openedBook.cardRect!.isEmpty;

    final spreadContent = FannedPagesView(onClose: widget.onClose);

    if (!hasCoverOverlay) {
      return spreadContent;
    }

    final rect = widget.openedBook.cardRect!;
    return Stack(
      fit: StackFit.expand,
      children: [
        spreadContent,
        Positioned(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          child: _CoverOpenOverlay(
            animation: _coverAnimation,
            coverImage: widget.openedBook.coverImage!,
            openFromRight: true,
          ),
        ),
      ],
    );
  }
}

/// Paper: 커버가 오른쪽 등 기준으로 열리며 그 아래 부채꼴 페이지가 드러남
class _CoverOpenOverlay extends StatefulWidget {
  final Animation<double> animation;
  final ui.Image coverImage;
  final bool openFromRight;

  const _CoverOpenOverlay({
    required this.animation,
    required this.coverImage,
    this.openFromRight = true,
  });

  @override
  State<_CoverOpenOverlay> createState() => _CoverOpenOverlayState();
}

class _CoverOpenOverlayState extends State<_CoverOpenOverlay> {
  @override
  void dispose() {
    widget.coverImage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, _) {
        final t = widget.animation.value;
        final angleY = widget.openFromRight
            ? t * (3.141592 / 2)
            : -t * (3.141592 / 2);
        final opacity = (1.0 - t).clamp(0.0, 1.0);
        final alignment = widget.openFromRight ? Alignment.centerRight : Alignment.centerLeft;

        return IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Transform(
              alignment: alignment,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angleY),
              child: RawImage(
                image: widget.coverImage,
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      },
    );
  }
}
