import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/cover_size.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/platform_ui.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/layer.dart';
import '../widgets/create_flow/album_create_step1.dart';
import '../widgets/create_flow/album_create_step2.dart';
import '../viewmodels/album_editor_view_model.dart';
import 'add_cover_screen.dart';
import 'page_editor_screen.dart';

/// 앨범 생성 플로우 화면 (스텝1~3)
class AlbumCreateFlowScreen extends ConsumerStatefulWidget {
  final List<List<LayerModel>>? initialTemplatePages;
  final Map<String, List<List<LayerModel>>>? initialTemplatePagesByAspect;
  final String? initialAlbumTitle;
  final List<String>? initialTemplatePreviewImages;
  final CoverSize? initialCoverSize;

  const AlbumCreateFlowScreen({
    super.key,
    this.initialTemplatePages,
    this.initialTemplatePagesByAspect,
    this.initialAlbumTitle,
    this.initialTemplatePreviewImages,
    this.initialCoverSize,
  });

  @override
  ConsumerState<AlbumCreateFlowScreen> createState() =>
      _AlbumCreateFlowScreenState();
}

class _AlbumCreateFlowScreenState extends ConsumerState<AlbumCreateFlowScreen> {
  static const int _maxPageCount = 50;
  int _currentStep = 0;
  String _albumTitle = '';

  CoverSize? _selectedCover;
  int _selectedPageCount = 10;
  int _templateMinPageCount = 10;
  bool _allowEditing = true;
  List<String> _invitedEmails = [];
  int? _createdAlbumId;
  List<List<LayerModel>>? _resolvedTemplatePages;
  List<List<LayerModel>>? _baseTemplatePages;
  Map<String, List<List<LayerModel>>>? _templatePagesByAspect;

  /// 커버 편집 단계(step 1)에서 AppBar 완료 버튼이 호출할 콜백
  VoidCallback? _onCompletePressed;

  List<List<LayerModel>> _hydrateTemplatePages(List<List<LayerModel>> pages) {
    final images = widget.initialTemplatePreviewImages ?? const <String>[];
    if (images.isEmpty) return pages;

    var imageCursor = 0;
    return pages
        .map((page) {
          return page
              .map((layer) {
                if (layer.type != LayerType.image) return layer;
                final hasUrl =
                    (layer.previewUrl != null &&
                        layer.previewUrl!.isNotEmpty) ||
                    (layer.imageUrl != null && layer.imageUrl!.isNotEmpty) ||
                    (layer.originalUrl != null &&
                        layer.originalUrl!.isNotEmpty);
                if (hasUrl) return layer;
                final url = images[imageCursor % images.length];
                imageCursor++;
                return layer.copyWith(
                  previewUrl: url,
                  imageUrl: url,
                  originalUrl: url,
                );
              })
              .toList(growable: false);
        })
        .toList(growable: false);
  }

  String _aspectKeyFromCover(CoverSize cover) {
    final ratio = cover.ratio;
    if (ratio >= 1.05) return 'landscape';
    if (ratio <= 0.95) return 'portrait';
    return 'square';
  }

  CoverSize _coverForAspectKey(String key) {
    final normalized = key.toLowerCase();
    if (normalized == 'portrait') {
      return coverSizes.firstWhere(
        (s) => s.name == '세로형',
        orElse: () => coverSizes.first,
      );
    }
    if (normalized == 'landscape') {
      return coverSizes.firstWhere(
        (s) => s.name == '가로형',
        orElse: () => coverSizes.last,
      );
    }
    return coverSizes.firstWhere(
      (s) => s.name == '정사각형',
      orElse: () => coverSizes.first,
    );
  }

  CoverSize _resolveInitialCover() {
    if (widget.initialCoverSize != null) {
      return widget.initialCoverSize!;
    }
    final variants = _templatePagesByAspect;
    if (variants != null && variants.isNotEmpty) {
      if (variants['portrait']?.isNotEmpty ?? false) {
        return _coverForAspectKey('portrait');
      }
      if (variants['square']?.isNotEmpty ?? false) {
        return _coverForAspectKey('square');
      }
      if (variants['landscape']?.isNotEmpty ?? false) {
        return _coverForAspectKey('landscape');
      }
    }
    return coverSizes.firstWhere(
      (s) => s.name == '정사각형',
      orElse: () => coverSizes.first,
    );
  }

  void _applyTemplateByCoverIfNeeded(CoverSize cover) {
    final key = _aspectKeyFromCover(cover);
    final variants = _templatePagesByAspect;
    final selected = key == 'portrait'
        ? _baseTemplatePages
        : variants == null
        ? null
        : variants[key];
    if (selected == null || selected.isEmpty) return;
    // 기존에 충분한 페이지가 이미 해석된 상태라면,
    // 페이지 수가 부족한 variant로 덮어쓰지 않도록 방어한다.
    final currentResolvedCount = _resolvedTemplatePages?.length ?? 0;
    if (currentResolvedCount > 1 && selected.length <= 1) return;
    _resolvedTemplatePages = _hydrateTemplatePages(selected);
    _templateMinPageCount = (_resolvedTemplatePages!.length - 1).clamp(
      1,
      _maxPageCount,
    );
    _selectedPageCount = _selectedPageCount.clamp(
      _templateMinPageCount,
      _maxPageCount,
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialTemplatePagesByAspect != null &&
        widget.initialTemplatePagesByAspect!.isNotEmpty) {
      _templatePagesByAspect = widget.initialTemplatePagesByAspect!.map((k, v) {
        return MapEntry(k.toLowerCase(), v);
      });
    }
    if (widget.initialTemplatePages != null &&
        widget.initialTemplatePages!.isNotEmpty) {
      _baseTemplatePages = _hydrateTemplatePages(widget.initialTemplatePages!);
      _resolvedTemplatePages = _baseTemplatePages;
      (_templatePagesByAspect ??=
              <String, List<List<LayerModel>>>{})['portrait'] =
          _baseTemplatePages!;
    }
    if (widget.initialAlbumTitle != null &&
        widget.initialAlbumTitle!.trim().isNotEmpty) {
      _albumTitle = widget.initialAlbumTitle!.trim();
    }
    _selectedCover = _resolveInitialCover();
    if (_resolvedTemplatePages != null && _resolvedTemplatePages!.isNotEmpty) {
      // cover 제외 내지 페이지 수
      _templateMinPageCount = (_resolvedTemplatePages!.length - 1).clamp(
        1,
        _maxPageCount,
      );
      _selectedPageCount = _templateMinPageCount;
    }
    // 초기 진입 시에도 현재 선택 커버 비율(기본: 정사각형)에 맞는 variant를 즉시 적용한다.
    // 그래야 사용자가 정사각형을 한 번 더 탭하지 않아도 페이지/이미지 크기가 맞게 보인다.
    if (_selectedCover != null) {
      _applyTemplateByCoverIfNeeded(_selectedCover!);
    }
    ScreenLogger.enter(
      'AlbumCreateFlowScreen',
      '앨범 생성 플로우 Step 1~4 (정보 입력 → 커버 편집 → 친구 초대 → 페이지 편집)',
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final handled = _handleBack();
        return !handled; // handled == true 이면 pop 막기
      },
      child: Scaffold(
        backgroundColor: SnapFitColors.backgroundOf(context),
        appBar: AppBar(
          toolbarHeight: 62.h,
          backgroundColor: SnapFitColors.backgroundOf(context),
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              platformBackIcon(),
              color: SnapFitColors.textPrimaryOf(context),
              size: 18.sp,
            ),
            onPressed: _handleBack,
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SNAPFIT CREATE',
                style: TextStyle(
                  fontSize: 9.5.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  color: SnapFitColors.accent,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                _currentStep == 0
                    ? '어떤 추억을 담을까요?'
                    : _currentStep == 1
                    ? '표지를 먼저 다듬어요'
                    : '함께 볼 사람을 초대해요',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w900,
                  color: SnapFitColors.textPrimaryOf(context),
                  letterSpacing: -0.25,
                ),
              ),
            ],
          ),
          actions: [
            if (_currentStep == 1)
              Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: Center(
                  child: TextButton(
                    onPressed: _onCompletePressed,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      minimumSize: Size(64.w, 36.h),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      '다음',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: SnapFitColors.textPrimaryOf(context),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFlowProgress(),
            Expanded(child: _buildStepContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowProgress() {
    const labels = ['분위기 고르기', '표지 다듬기', '함께 완성'];
    final templateMode = widget.initialTemplatePages != null;
    final title = switch (_currentStep) {
      0 => '분위기에 맞춰 앨범을 시작해요',
      1 => '첫인상이 될 표지를 확인해요',
      _ => '완성 전 함께 볼 사람을 정해요',
    };
    final subtitle = switch (_currentStep) {
      0 => '여행, 가족, 아기 사진처럼 기록의 장면에 맞는 포토북을 만들어요.',
      1 => '사진과 제목이 잘 어울리는지 가볍게 다듬어보세요.',
      _ => '혼자 간직하거나, 초대 링크로 같이 편집할 수 있어요.',
    };

    return Container(
      margin: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
      padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 16.h),
      decoration: BoxDecoration(
        gradient: SnapFitColors.isDark(context)
            ? const LinearGradient(
                colors: [Color(0xFF18212D), Color(0xFF11151D)],
              )
            : const LinearGradient(
                colors: [Color(0xFFFFF7EB), Color(0xFFEAFBFD)],
              ),
        borderRadius: BorderRadius.circular(26.r),
        border: Border.all(color: SnapFitColors.overlayLightOf(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              SnapFitColors.isDark(context) ? 0.24 : 0.06,
            ),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: SnapFitColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999.r),
                ),
                child: Text(
                  templateMode ? '템플릿 빠른 시작' : '새 포토북 만들기',
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w900,
                    color: SnapFitColors.accent,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${_currentStep + 1}/3',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w900,
                  color: SnapFitColors.textMutedOf(context),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 20.sp,
              height: 1.18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.45,
              color: SnapFitColors.textPrimaryOf(context),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12.5.sp,
              height: 1.42,
              fontWeight: FontWeight.w600,
              color: SnapFitColors.textSecondaryOf(context),
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            children: List.generate(labels.length, (index) {
              final active = index <= _currentStep;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == labels.length - 1 ? 0 : 7.w,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        height: 5.h,
                        decoration: BoxDecoration(
                          color: active
                              ? SnapFitColors.accent
                              : SnapFitColors.overlayLightOf(context),
                          borderRadius: BorderRadius.circular(999.r),
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        labels[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          fontWeight: index == _currentStep
                              ? FontWeight.w900
                              : FontWeight.w700,
                          color: index == _currentStep
                              ? SnapFitColors.textPrimaryOf(context)
                              : SnapFitColors.textMutedOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return AlbumCreateStep1(
          albumTitle: _albumTitle,
          templateTitle: widget.initialAlbumTitle,
          templatePreviewImageUrl:
              widget.initialTemplatePreviewImages != null &&
                  widget.initialTemplatePreviewImages!.isNotEmpty
              ? widget.initialTemplatePreviewImages!.first
              : null,
          selectedCover: _selectedCover,
          selectedPageCount: _selectedPageCount,
          minPageCount: _templateMinPageCount,
          // 제목 변경은 부모의 setState를 매 키 입력마다 호출하지 않고,
          // 값만 보관해서 한글 IME 조합이 끊기지 않도록 한다.
          onTitleChanged: (title) => _albumTitle = title,
          onCoverSelected: (cover) => setState(() {
            _selectedCover = cover;
            _applyTemplateByCoverIfNeeded(cover);
          }),
          onPageCountChanged: (count) => setState(
            () => _selectedPageCount = count.clamp(
              _templateMinPageCount,
              _maxPageCount,
            ),
          ),
          onNext: () {
            final title = _albumTitle.trim();
            if (title.isNotEmpty && _selectedCover != null) {
              _albumTitle = title;
              setState(() => _currentStep = 1);
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('앨범 제목과 커버 비율을 확인해주세요.')),
            );
          },
        );
      case 1:
        // Step 2: 앨범 생성 페이지 (커버 편집 화면)
        if (_selectedCover == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return AddCoverScreen(
          isFromCreateFlow: true,
          initialCoverSize: _selectedCover,
          albumTitle: _albumTitle, // 앨범 제목 전달
          targetPages: _selectedPageCount, // 목표 페이지 수 전달
          initialTemplateCoverLayers:
              (_resolvedTemplatePages != null &&
                  _resolvedTemplatePages!.isNotEmpty)
              ? _resolvedTemplatePages!.first
              : null,
          onRegisterCompleteAction: (callback) {
            setState(() {
              _onCompletePressed = callback;
            });
          },
          onAlbumCreated: (albumId) {
            _handleAlbumCreated(albumId);
          },
        );
      case 2:
        // Step 3: 친구 초대 (마지막 단계)
        if (_createdAlbumId == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return AlbumCreateStep2(
          albumTitle: _albumTitle,
          selectedCover: _selectedCover!,
          selectedPageCount: _selectedPageCount,
          allowEditing: _allowEditing,
          albumId: _createdAlbumId,
          onAllowEditingChanged: (value) =>
              setState(() => _allowEditing = value),
          onNext: () {
            // 마지막 단계 완료 -> 편집 화면(Reader)으로 이동
            if (_createdAlbumId != null) {
              // 앨범이 아직 생성 중일 수 있으므로 ID만으로 더미 Album 생성
              final dummyAlbum = Album(
                id: _createdAlbumId!,
                ratio: _selectedCover!.ratio.toString(),
                targetPages: _selectedPageCount,
              );

              final vm = ref.read(albumEditorViewModelProvider.notifier);
              if (_resolvedTemplatePages != null &&
                  _resolvedTemplatePages!.isNotEmpty) {
                // 템플릿 페이지는 이미 메모리에 완성되어 있으므로 업로드 폴링을 기다리지 않는다.
                // 업로드/대표이미지 보정은 백그라운드에서 진행하되 편집 화면은 즉시 열린다.
                vm.beginCreatedTemplateAlbumForEdit(
                  albumId: dummyAlbum.id,
                  albumTitle: _albumTitle,
                  pages: _resolvedTemplatePages!,
                  initialCover: _selectedCover,
                );
              } else {
                // 일반 생성 경로만 서버 생성 완료를 기다린다.
                vm.prepareAlbumForEdit(dummyAlbum, waitForCreation: true);
              }

              // 즉시 편집 화면으로 이동
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const PageEditorScreen(initialPageIndex: 1),
                ),
              );
            }
          },
          onBack: () => setState(() => _currentStep = 1),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _handleAlbumCreated(int albumId) async {
    // 템플릿/일반 생성 모두 Step 3(친구 초대)로 이동
    setState(() {
      _createdAlbumId = albumId;
      _currentStep = 2;
    });
  }

  /// 뒤로가기 처리
  /// - Step 0: 플로우 종료 (Navigator.pop)
  /// - Step 1,2,3: 이전 스텝으로 이동
  /// return true 이면 이벤트를 소모했음을 의미 (WillPopScope에서 pop 방지)
  bool _handleBack() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep -= 1;
      });
      return true;
    } else {
      Navigator.pop(context);
      return true;
    }
  }
}
