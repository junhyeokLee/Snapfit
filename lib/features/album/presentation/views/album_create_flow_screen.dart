import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/cover_size.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/layer.dart';
import '../widgets/create_flow/album_create_step1.dart';
import '../widgets/create_flow/album_create_step2.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../viewmodels/cover_view_model.dart';
import 'album_reader_screen.dart';
import 'add_cover_screen.dart';
import 'page_editor_screen.dart';
import '../../data/api/album_provider.dart';

/// 앨범 생성 플로우 화면 (스텝1~3)
class AlbumCreateFlowScreen extends ConsumerStatefulWidget {
  final List<List<LayerModel>>? initialTemplatePages;
  final Map<String, List<List<LayerModel>>>? initialTemplatePagesByAspect;
  final String? initialAlbumTitle;
  final List<String>? initialTemplatePreviewImages;

  const AlbumCreateFlowScreen({
    super.key,
    this.initialTemplatePages,
    this.initialTemplatePagesByAspect,
    this.initialAlbumTitle,
    this.initialTemplatePreviewImages,
  });

  @override
  ConsumerState<AlbumCreateFlowScreen> createState() =>
      _AlbumCreateFlowScreenState();
}

class _AlbumCreateFlowScreenState extends ConsumerState<AlbumCreateFlowScreen> {
  static const int _maxPageCount = 50;
  int _currentStep = 0;
  String _albumTitle = '';

  /// 최초 진입 시 정사각형이 기본 선택되도록 설정
  CoverSize? _selectedCover = coverSizes.firstWhere(
    (s) => s.name == '정사각형',
    orElse: () => coverSizes.first,
  );
  int _selectedPageCount = 10;
  int _templateMinPageCount = 10;
  bool _allowEditing = true;
  List<String> _invitedEmails = [];
  int? _createdAlbumId;
  List<List<LayerModel>>? _resolvedTemplatePages;
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

  void _applyTemplateByCoverIfNeeded(CoverSize cover) {
    final variants = _templatePagesByAspect;
    if (variants == null || variants.isEmpty) return;
    final key = _aspectKeyFromCover(cover);
    final selected = variants[key];
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
      _templatePagesByAspect = widget.initialTemplatePagesByAspect!.map((
        k,
        v,
      ) {
        return MapEntry(k.toLowerCase(), v);
      });
    }
    if (widget.initialTemplatePages != null &&
        widget.initialTemplatePages!.isNotEmpty) {
      _resolvedTemplatePages = _hydrateTemplatePages(
        widget.initialTemplatePages!,
      );
    }
    if (widget.initialAlbumTitle != null &&
        widget.initialAlbumTitle!.trim().isNotEmpty) {
      _albumTitle = widget.initialAlbumTitle!.trim();
    }
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
          backgroundColor: SnapFitColors.backgroundOf(context),
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: SnapFitColors.textPrimaryOf(context),
              size: 18.sp,
            ),
            onPressed: _handleBack,
          ),
          title: Text(
            '앨범 생성',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: SnapFitColors.textPrimaryOf(context),
            ),
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
            // 스텝 단계 표시 (스텝1과 동일 스타일)
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
              child: Text(
                'STEP ${(_currentStep + 1).toString().padLeft(2, '0')}/03',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: SnapFitColors.accent,
                ),
              ),
            ),
            // 스텝별 콘텐츠
            Expanded(child: _buildStepContent()),
          ],
        ),
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
                // 템플릿 경로에서도 Step3 이후에 페이지 편집으로 진입할 때
                // 템플릿 페이지가 적용되도록 큐를 먼저 주입한다.
                vm.queueTemplatePagesForNextLoad(_resolvedTemplatePages!);
              }

              // 백그라운드에서 폴링 시작 (await 하지 않음 → 즉시 화면 전환)
              // PageEditorScreen의 isCreatingInBackground 오버레이가 "생성 중" 표시
              vm.prepareAlbumForEdit(dummyAlbum, waitForCreation: true);

              // 즉시 편집 화면으로 이동 (로딩 오버레이 표시됨)
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
