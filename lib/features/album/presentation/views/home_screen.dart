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
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/snapfit_gradient_background.dart';
import '../../../auth/data/dto/auth_response.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/layer.dart';
import '../../domain/entities/layer_export_mapper.dart';
import '../widgets/cover/cover.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../viewmodels/home_view_model.dart';
import 'add_cover_screen.dart';
import 'album_reader_screen.dart';
import 'fanned_pages_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final albumsAsync = ref.watch(homeViewModelProvider);
    final authAsync = ref.watch(authViewModelProvider);
    Future<void> handleCreateAlbum() async {
      final created = await Navigator.pushNamed(context, '/add_cover');
      if (created == true && context.mounted) {
        await ref.read(homeViewModelProvider.notifier).refresh();
      }
    }

    Future<void> handleLogout() async {
      await ref.read(authViewModelProvider.notifier).logout();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃되었습니다.')),
      );
    }

    final albums = albumsAsync.asData?.value;
    final sortedAlbums = albums == null
        ? null
        : (List<Album>.from(albums)
          ..sort((a, b) => (b.createdAt).compareTo(a.createdAt)));
    final selectedAlbum = (sortedAlbums == null || sortedAlbums.isEmpty)
        ? null
        : sortedAlbums[_selectedIndex.clamp(0, sortedAlbums.length - 1)];

    return Scaffold(
      backgroundColor: SnapFitColors.background,
      body: Container(
        color: Colors.black,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 8.h),
                child: _HomeHeader(
                  onSearch: () {},
                  onNotification: () {},
                  onLogout: handleLogout,
                  userInfo: authAsync.value,
                  isLoading: authAsync.isLoading,
                ),
              ),
              Expanded(
                child: albumsAsync.when(
                  data: (albums) {
                    final sorted = List<Album>.from(albums)
                      ..sort((a, b) => (b.createdAt).compareTo(a.createdAt));
                    return sorted.isEmpty
                        ? _buildEmptyState(context)
                        : _AlbumListView(
                            albums: sorted,
                            selectedIndex: _selectedIndex,
                            onSelect: (index) {
                              setState(() => _selectedIndex = index);
                            },
                            onOpen: (album, index) async {
                              setState(() => _selectedIndex = index);
                              await _openAlbum(context, ref, album);
                            },
                            onEdit: (album) => _onEditSelected(context, album),
                            onDelete: (album) => _onDeleteSelected(context, album),
                          );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: SnapFitColors.textPrimary),
                  ),
                  error: (err, stack) => _buildErrorState(context, err),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _CreateAlbumFab(onPressed: handleCreateAlbum),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Future<void> _onEditSelected(BuildContext context, Album album) async {
    try {
      final vm = ref.read(albumEditorViewModelProvider.notifier);
      await ref.read(albumEditorViewModelProvider.future);
      await vm.prepareAlbumForEdit(album);
      if (!context.mounted) return;
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

  Future<void> _onDeleteSelected(BuildContext context, Album album) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('앨범 삭제'),
        content: const Text('이 앨범을 삭제하시겠어요?\n복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제'),
          ),
        ],
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

  static Widget _buildEmptyState(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Center(
          child: Text(
            '앨범이 비어있습니다.',
            style: TextStyle(
              fontSize: 18.sp,
              color: SnapFitColors.textPrimary.withOpacity(0.9),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildErrorState(BuildContext context, Object err) {
    final isTimeout = err is DioException &&
        err.type == DioExceptionType.connectionTimeout;
    if (isTimeout) {
      return _buildEmptyState(context);
    }

    final isConnectionRefused =
        err is DioException && err.type == DioExceptionType.connectionError;
    final textColor = SnapFitColors.textPrimary.withOpacity(0.9);
    final subColor = SnapFitColors.textSecondary.withOpacity(0.7);
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

/// 홈 화면 상단 헤더 (제목 + 아이콘)
class _HomeHeader extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onNotification;
  final VoidCallback onLogout;
  final UserInfo? userInfo;
  final bool isLoading;

  const _HomeHeader({
    required this.onSearch,
    required this.onNotification,
    required this.onLogout,
    required this.userInfo,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final statusLabel = isLoading
        ? '로그인 확인중'
        : userInfo == null
            ? '로그인 필요'
            : '${userInfo!.provider.toUpperCase()} 로그인';
    return Row(
      children: [
        Row(
          children: [
            Text(
              '나의 앨범',
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
                color: SnapFitColors.textPrimary,
              ),
            ),
            SizedBox(width: 10.w),
            _AuthStatusChip(label: statusLabel, isActive: userInfo != null),
          ],
        ),
        const Spacer(),
        _RoundIconButton(icon: Icons.search, onTap: onSearch),
        SizedBox(width: 10.w),
        _RoundIconButton(icon: Icons.notifications_none, onTap: onNotification),
        SizedBox(width: 10.w),
        _RoundIconButton(icon: Icons.logout, onTap: onLogout),
      ],
    );
  }
}

/// 로그인 상태 표시
class _AuthStatusChip extends StatelessWidget {
  final String label;
  final bool isActive;

  const _AuthStatusChip({
    required this.label,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: isActive
            ? SnapFitColors.accent.withOpacity(0.18)
            : SnapFitColors.overlayMedium,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isActive
              ? SnapFitColors.accent.withOpacity(0.6)
              : SnapFitColors.overlayStrong,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w600,
          color: isActive ? SnapFitColors.accentLight : SnapFitColors.textMuted,
        ),
      ),
    );
  }
}

/// 홈 화면 앨범 리스트 뷰
class _AlbumListView extends StatelessWidget {
  final List<Album> albums;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Future<void> Function(Album album, int index) onOpen;
  final Future<void> Function(Album album) onEdit;
  final Future<void> Function(Album album) onDelete;

  const _AlbumListView({
    required this.albums,
    required this.selectedIndex,
    required this.onSelect,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 120.h),
      itemCount: albums.length,
      separatorBuilder: (_, __) => SizedBox(height: 14.h),
      itemBuilder: (context, index) {
        final album = albums[index];
        return _AlbumListCard(
          album: album,
          isSelected: index == selectedIndex,
          onTap: () async {
            onSelect(index);
            await onOpen(album, index);
          },
          onEdit: () => onEdit(album),
          onDelete: () => onDelete(album),
        );
      },
    );
  }
}

/// 홈 화면 앨범 카드 (리스트형)
class _AlbumListCard extends StatelessWidget {
  final Album album;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AlbumListCard({
    required this.album,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final coverUrl = album.coverThumbnailUrl ??
        album.coverPreviewUrl ??
        album.coverImageUrl;
    final created = _formatDate(album.createdAt);
    final pagesText = '${album.totalPages} pages';
    final ratio = _parseCoverRatio(album.ratio);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        padding: EdgeInsets.fromLTRB(18.w, 22.h, 18.w, 34.h),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 16.r,
              offset: Offset(0, 8.h),
            ),
          ],
        ),
        child: Stack(
          children: [
            Row(
              children: [
                _AlbumCoverThumbnail(
                  album: album,
                  height: 138.h,
                ),
                SizedBox(width: 18.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              album.coverTheme?.isNotEmpty == true
                                  ? album.coverTheme!
                                  : '앨범',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                                color: SnapFitColors.textPrimary,
                              ),
                            ),
                          ),
                          _RoleChip(label: 'OWNER'),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        '$created · $pagesText',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: SnapFitColors.textMuted,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      _CollaboratorDots(),
                      SizedBox(height: 26.h),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              right: 0,
              bottom: 2.h,
              child: Row(
                children: [
                  _CardIconButton(
                    icon: Icons.edit,
                    onTap: onEdit,
                    background: SnapFitColors.accent.withOpacity(0.2),
                    iconColor: SnapFitColors.accentLight,
                  ),
                  SizedBox(width: 8.w),
                  _CardIconButton(
                    icon: Icons.delete_outline,
                    onTap: onDelete,
                    background: const Color(0xFFE53935).withOpacity(0.18),
                    iconColor: const Color(0xFFE53935),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 앨범 커버 썸네일
class _AlbumCoverThumbnail extends StatelessWidget {
  final Album album;
  final double height;

  const _AlbumCoverThumbnail({
    required this.album,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = _parseCoverRatio(album.ratio);
    double width = height * ratio;
    double scaledHeight = height;
    final maxWidth = ratio > 1 ? 140.w : 150.w;
    if (width > maxWidth) {
      final scale = maxWidth / width;
      width = maxWidth;
      scaledHeight = height * scale;
    }
    final shadowScale = (scaledHeight / 280).clamp(0.35, 0.7);
    final theme = _resolveCoverTheme(album.coverTheme);
    final canvasSize = Size(width, scaledHeight);

    final layers = _parseCoverLayers(
      album.coverLayersJson,
      canvasSize: canvasSize,
    );

    if (layers != null && layers.isNotEmpty) {
      return _CoverFrame(
        width: width,
        height: scaledHeight,
        shadowScale: shadowScale,
        child: CoverLayout(
          aspect: ratio,
          layers: layers,
          isInteracting: false,
          leftSpine: 12.w,
          onCoverSizeChanged: (_) {},
          buildImage: (layer) => _buildStaticImage(layer),
          buildText: (layer) => _buildStaticText(layer),
          sortedByZ: (list) => list..sort((a, b) => a.id.compareTo(b.id)),
          theme: theme,
        ),
      );
    }

    final imageUrl = album.coverThumbnailUrl ??
        album.coverPreviewUrl ??
        album.coverImageUrl;
    final hasUrl = imageUrl?.isNotEmpty == true;

    return _CoverFrame(
      width: width,
      height: scaledHeight,
      shadowScale: shadowScale,
      child: hasUrl
          ? SnapfitImage(
              urlOrGs: imageUrl!,
              fit: BoxFit.cover,
              cacheManager: snapfitImageCacheManager,
            )
          : Container(
              color: Colors.grey[300],
              child: Icon(
                Icons.photo_album_outlined,
                size: 28.sp,
                color: Colors.grey[600],
              ),
            ),
    );
  }
}

class _CoverFrame extends StatelessWidget {
  final double width;
  final double height;
  final double shadowScale;
  final Widget child;

  const _CoverFrame({
    required this.width,
    required this.height,
    required this.shadowScale,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 18.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: _coverRadius,
          boxShadow: _FocusWrap.coverStyleShadowForScale(shadowScale, 0),
        ),
        child: ClipRRect(
          borderRadius: _coverRadius,
          child: child,
        ),
      ),
    );
  }
}

/// 역할 배지
class _RoleChip extends StatelessWidget {
  final String label;

  const _RoleChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: SnapFitColors.accent.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: SnapFitColors.accent.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          color: SnapFitColors.accentLight,
        ),
      ),
    );
  }
}

/// 협업자 표시 점(디자인용 자리)
class _CollaboratorDots extends StatelessWidget {
  const _CollaboratorDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Dot(color: SnapFitColors.textMuted.withOpacity(0.7)),
        SizedBox(width: 6.w),
        _Dot(color: SnapFitColors.textMuted.withOpacity(0.7)),
        SizedBox(width: 6.w),
        _Dot(color: SnapFitColors.textMuted.withOpacity(0.7)),
        SizedBox(width: 8.w),
        _PlusDot(label: '+3'),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;

  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14.w,
      height: 14.w,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _PlusDot extends StatelessWidget {
  final String label;

  const _PlusDot({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24.w,
      height: 24.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SnapFitColors.accent,
        shape: BoxShape.circle,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.sp,
          fontWeight: FontWeight.w700,
          color: SnapFitColors.textPrimary,
        ),
      ),
    );
  }
}

/// 홈 화면 우측 하단 새 앨범 버튼
class _CreateAlbumFab extends StatelessWidget {
  final VoidCallback onPressed;

  const _CreateAlbumFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'create_album_fab',
          onPressed: onPressed,
          backgroundColor: SnapFitColors.accent,
          elevation: 6,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        SizedBox(height: 6.h),
        Text(
          '앨범 만들기',
          style: TextStyle(
            fontSize: 11.sp,
            color: SnapFitColors.accentLight,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// 홈 우하단 액션 버튼 묶음 (편집/삭제/생성)
class _CardIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color background;
  final Color iconColor;

  const _CardIconButton({
    required this.icon,
    required this.onTap,
    required this.background,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 30.w,
        height: 30.w,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16.sp, color: iconColor),
      ),
    );
  }
}

/// 둥근 아이콘 버튼
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        width: 36.w,
        height: 36.w,
        decoration: BoxDecoration(
          color: SnapFitColors.overlayLight,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18.sp, color: SnapFitColors.textPrimary),
      ),
    );
  }
}

/// 날짜 포맷 (yyyy.MM.dd)
String _formatDate(String raw) {
  if (raw.isEmpty) return '----.--.--';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final mm = parsed.month.toString().padLeft(2, '0');
  final dd = parsed.day.toString().padLeft(2, '0');
  return '${parsed.year}.$mm.$dd';
}

double _parseCoverRatio(String raw) {
  if (raw.isEmpty) return 6 / 8;
  final parts = raw.split(':');
  if (parts.length == 2) {
    final w = double.tryParse(parts[0]);
    final h = double.tryParse(parts[1]);
    if (w != null && h != null && h != 0) return w / h;
  }
  final value = double.tryParse(raw);
  if (value != null && value > 0) return value;
  return 6 / 8;
}

CoverTheme _resolveCoverTheme(String? label) {
  if (label == null || label.isEmpty) return CoverTheme.classic;
  final normalized = label.trim().toLowerCase();
  for (final theme in CoverTheme.values) {
    if (theme.label.toLowerCase() == normalized) {
      return theme;
    }
  }
  return CoverTheme.classic;
}

List<LayerModel>? _parseCoverLayers(
  String raw, {
  required Size canvasSize,
}) {
  if (raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final pages = decoded['pages'] as List<dynamic>?;
    final List<dynamic> layerList = (pages != null && pages.isNotEmpty)
        ? ((pages[0] as Map<String, dynamic>)['layers'] as List?) ?? []
        : (decoded['layers'] as List?) ?? [];
    if (layerList.isEmpty) return null;
    return layerList
        .map(
          (l) => LayerExportMapper.fromJson(
            l as Map<String, dynamic>,
            canvasSize: canvasSize,
          ),
        )
        .toList();
  } catch (_) {
    return null;
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

/// 앨범 열기 (리더 화면)
Future<void> _openAlbum(BuildContext context, WidgetRef ref, Album album) async {
  final vm = ref.read(albumEditorViewModelProvider.notifier);
  await ref.read(albumEditorViewModelProvider.future);
  await vm.prepareAlbumForEdit(album);
  if (!context.mounted) return;
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const _PaperUnfoldPage()),
  );
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
    ui.Image? coverImage;
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

      final boundary = _coverRepaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        try {
          coverImage = await boundary.toImage(pixelRatio: 2.0);
        } catch (_) {}
      }

      if (!context.mounted) return;
      Navigator.of(context).push(
        _PaperUnfoldRoute(cardRect: cardRect, coverImage: coverImage),
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

/// 앨범 카드가 제자리에서 사라락~ 페이드아웃되며 전환되는 오버레이 (이동/확대 없음)
class _ExpandOverlay extends StatefulWidget {
  final Animation<double> animation;
  final ui.Image coverImage;
  final Rect cardRect;

  const _ExpandOverlay({
    required this.animation,
    required this.coverImage,
    required this.cardRect,
  });

  @override
  State<_ExpandOverlay> createState() => _ExpandOverlayState();
}

class _ExpandOverlayState extends State<_ExpandOverlay> {
  @override
  void dispose() {
    widget.coverImage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.cardRect.width;
    final h = widget.cardRect.height;

    return Positioned(
      left: widget.cardRect.left,
      top: widget.cardRect.top,
      child: AnimatedBuilder(
        animation: widget.animation,
        builder: (context, _) {
          final t = widget.animation.value;
          final opacity = (1.0 - Curves.easeOutCubic.transform(t)).clamp(0.0, 1.0);
          return IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: SizedBox(
                width: w,
                height: h,
                child: ClipRRect(
                  borderRadius: _coverRadius,
                  child: RawImage(
                    image: widget.coverImage,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          );
        },
      ),
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
          transitionDuration: const Duration(milliseconds: 450),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (context, animation, secondaryAnimation) {
            return _PaperUnfoldPage(
              cardRect: cardRect,
              coverImage: coverImage,
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            final rect = cardRect;

            if (coverImage != null && rect != null && rect.width > 0 && rect.height > 0) {
              return Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  FadeTransition(
                    opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: const Interval(0.25, 1.0, curve: Curves.easeOut),
                      ),
                    ),
                    child: child,
                  ),
                  _ExpandOverlay(
                    animation: curved,
                    coverImage: coverImage!,
                    cardRect: rect,
                  ),
                ],
              );
            }
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
                alignment: Alignment.center,
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
    final content = AlbumReaderScreen();
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

