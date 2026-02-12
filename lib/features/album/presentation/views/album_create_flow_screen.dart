import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/cover_size.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../domain/entities/album.dart';
import '../widgets/create_flow/album_create_step1.dart';
import '../widgets/create_flow/album_create_step2.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../viewmodels/cover_view_model.dart';
import 'album_reader_screen.dart';
import 'add_cover_screen.dart';
import '../../data/api/album_provider.dart';

/// 앨범 생성 플로우 화면 (스텝1~3)
class AlbumCreateFlowScreen extends ConsumerStatefulWidget {
  const AlbumCreateFlowScreen({super.key});

  @override
  ConsumerState<AlbumCreateFlowScreen> createState() => _AlbumCreateFlowScreenState();
}

class _AlbumCreateFlowScreenState extends ConsumerState<AlbumCreateFlowScreen> {
  int _currentStep = 0;
  String _albumTitle = '';
  /// 최초 진입 시 정사각형이 기본 선택되도록 설정
  CoverSize? _selectedCover = coverSizes.firstWhere(
    (s) => s.name == '정사각형',
    orElse: () => coverSizes.first,
  );
  int _selectedPageCount = 10;
  bool _allowEditing = true;
  List<String> _invitedEmails = [];
  int? _createdAlbumId;
  /// 커버 편집 단계(step 1)에서 AppBar 완료 버튼이 호출할 콜백
  VoidCallback? _onCompletePressed;

  @override
  void initState() {
    super.initState();
    ScreenLogger.enter('AlbumCreateFlowScreen', '앨범 생성 플로우 Step 1~4 (정보 입력 → 커버 편집 → 친구 초대 → 페이지 편집)');
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
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: SnapFitColors.textPrimaryOf(context), size: 18.sp),
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
            Expanded(
              child: _buildStepContent(),
            ),
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
          selectedCover: _selectedCover,
          selectedPageCount: _selectedPageCount,
          // 제목 변경은 부모의 setState를 매 키 입력마다 호출하지 않고,
          // 값만 보관해서 한글 IME 조합이 끊기지 않도록 한다.
          onTitleChanged: (title) => _albumTitle = title,
          onCoverSelected: (cover) => setState(() => _selectedCover = cover),
          onPageCountChanged: (count) => setState(() => _selectedPageCount = count),
          onNext: () {
            if (_albumTitle.isNotEmpty && _selectedCover != null) {
              setState(() => _currentStep = 1);
            }
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
          onRegisterCompleteAction: (callback) {
            setState(() {
              _onCompletePressed = callback;
            });
          },
          onAlbumCreated: (albumId) {
            // 앨범 생성 완료 후 앨범 ID 저장하고 Step 3로 이동
            setState(() {
              _createdAlbumId = albumId;
              _currentStep = 2; // 친구 초대 화면으로 이동
            });
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
          onAllowEditingChanged: (value) => setState(() => _allowEditing = value),
          onNext: () async {
            // 마지막 단계 완료 -> 편집 화면(Reader)으로 이동
            if (_createdAlbumId != null) {
              // 앨범이 아직 생성 중일 수 있으므로 ID만으로 더미 Album 생성
              final dummyAlbum = Album(
                id: _createdAlbumId!,
                ratio: _selectedCover!.ratio.toString(),
              );
              
              // 백그라운드에서 폴링 시작 (상태 설정 대기)
              await ref.read(albumEditorViewModelProvider.notifier).prepareAlbumForEdit(
                dummyAlbum,
                waitForCreation: true, // 앨범 생성 완료 대기
              );
              
              // 상태 업데이트가 UI에 반영되도록 약간의 지연
              await Future.delayed(const Duration(milliseconds: 100));
              
              if (mounted) {
                 // 즉시 편집 화면으로 이동 (로딩 화면 표시됨)
                 Navigator.pushReplacement(
                   context,
                   MaterialPageRoute(builder: (_) => const AlbumReaderScreen()),
                 );
              }
            }
          },
          onBack: () => setState(() => _currentStep = 1),
        );
      default:
        return const SizedBox.shrink();
    }
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
