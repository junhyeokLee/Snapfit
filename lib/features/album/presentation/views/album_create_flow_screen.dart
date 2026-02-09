import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/cover_size.dart';
import '../../../../core/constants/snapfit_colors.dart';
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
  CoverSize? _selectedCover;
  int _selectedPageCount = 10;
  bool _allowEditing = true;
  List<String> _invitedEmails = [];
  int? _createdAlbumId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: SnapFitColors.backgroundOf(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: SnapFitColors.textPrimaryOf(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '앨범 생성',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
      ),
      body: Column(
        children: [
          // 스텝별 콘텐츠
          Expanded(
            child: _buildStepContent(),
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
          selectedCover: _selectedCover,
          selectedPageCount: _selectedPageCount,
          onTitleChanged: (title) => setState(() => _albumTitle = title),
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
          onAlbumCreated: (albumId) {
            // 앨범 생성 완료 후 앨범 ID 저장하고 Step 3로 이동
            setState(() {
              _createdAlbumId = albumId;
              _currentStep = 2; // 친구 초대 화면으로 이동
            });
          },
        );
      case 2:
        // Step 3: 친구 초대
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
            // Step 4로 이동 전에 앨범 로드
            if (_createdAlbumId != null) {
              try {
                final albumRepository = ref.read(albumRepositoryProvider);
                final album = await albumRepository.fetchAlbum(_createdAlbumId.toString());
                await ref.read(albumEditorViewModelProvider.notifier).prepareAlbumForEdit(album);
                
                if (mounted) {
                  setState(() => _currentStep = 3);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('앨범 로드 실패: $e')),
                  );
                }
              }
            }
          },
          onBack: () => setState(() => _currentStep = 1),
        );
      case 3:
        // Step 4: 페이지 편집 화면
        if (_createdAlbumId == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return const AlbumReaderScreen();
      default:
        return const SizedBox.shrink();
    }
  }

}
