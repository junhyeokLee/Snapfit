import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/edit_cover.dart';

import '../../../../core/constants/cover_size.dart';
import '../../domain/entities/album.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../viewmodels/cover_view_model.dart';


/// 커버 편집 화면 (앨범 생성/편집 공통)
/// - editAlbum == null: 앨범 생성 모드 (새 커버 만들기)
/// - editAlbum != null: 앨범 편집 모드 (기존 커버 수정)
/// 
/// 참고: 앨범 내부 페이지 편집은 AlbumSpreadScreen 사용
class AddCoverScreen extends ConsumerStatefulWidget {
  /// 편집 모드: 홈에서 앨범 선택 후 이 화면으로 올 때 전달 (이미 prepareAlbumForEdit 호출됨)
  final Album? editAlbum;

  const AddCoverScreen({super.key, this.editAlbum});

  @override
  ConsumerState<AddCoverScreen> createState() => _AddCoverScreenState();
}

class _AddCoverScreenState extends ConsumerState<AddCoverScreen> {
  late final ScrollController _gridController;
  bool _initialized = false;
  late CoverSize _selectedCover;

  @override
  void initState() {
    super.initState();
    _gridController = ScrollController()
      ..addListener(() {
        final vm = ref.read(albumEditorViewModelProvider.notifier);
        if (_gridController.position.pixels >=
            _gridController.position.maxScrollExtent - 300) {
          vm.loadMore();
        }
      });
    _selectedCover = coverSizes.firstWhere(
      (s) => s.name == '세로형',
      orElse: () => coverSizes.first,
    );
    Future.microtask(() {
      if (!_initialized) {
        if (widget.editAlbum == null) {
          // + 버튼(신규 생성) 진입: 빈 레이아웃으로 시작 (기존 데이터/갤러리 불러오기 X)
          ref
              .read(albumEditorViewModelProvider.notifier)
              .resetForCreate(initialCover: _selectedCover);
        } else {
          // 편집 모드: 에디터에 이미 로드됨 → 커버 VM만 동기화
          final editorSt = ref.read(albumEditorViewModelProvider).asData?.value;
          if (editorSt != null) {
            ref.read(coverViewModelProvider.notifier).selectCover(editorSt.selectedCover);
            ref.read(coverViewModelProvider.notifier).updateTheme(editorSt.selectedTheme);
          }
        }
        _initialized = true;
      }
    });
  }

  @override
  void dispose() {
    _gridController.dispose();
    super.dispose();
  }

  IconData _iconForCover(CoverSize s) {
    final ratio = s.ratio;
    if (ratio > 1) {
      return Icons.crop_landscape;
    } else if (ratio < 1) {
      return Icons.crop_portrait;
    } else {
      return Icons.crop_square;
    }
  }


  @override
  Widget build(BuildContext context) {
    final async = ref.watch(albumEditorViewModelProvider);
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final st = async.asData?.value;

    return LayoutBuilder(
      builder: (context, constraints) {
        final fixedMediaQuery = MediaQuery.of(context).copyWith(
          viewInsets: EdgeInsets.zero,   // 키보드가 viewInsets를 밀어내는걸 완전 무시
          padding: EdgeInsets.zero,      // SafeArea 밀림 제거
        );

        return MediaQuery(
          data: fixedMediaQuery,
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: Colors.transparent,
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7d7a97), Color(0xFF9893a9)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),

              child: Stack(
                children: [
                  Positioned.fill(
                    child: EditCover(editAlbum: widget.editAlbum),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}