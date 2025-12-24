import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/edit_cover.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_view_model.dart';

import '../../data/models/cover_size.dart';
import '../viewmodels/album_editor_view_model.dart';


class AddCoverScreen extends ConsumerStatefulWidget {
  const AddCoverScreen({super.key});

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
    // 기본 선택 세로형(6x8) 설정
    _selectedCover = coverSizes.firstWhere(
      (s) => s.name == '세로형',
      orElse: () => coverSizes.first,
    );
    //  이미 초기화된 경우 재호출 안 함
    Future.microtask(() {
      if (!_initialized) {
        ref.read(albumEditorViewModelProvider.notifier).fetchInitialData();
        ref.read(albumEditorViewModelProvider.notifier).selectCover(_selectedCover);
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

              child: const Stack(
                children: [
                  Positioned.fill(
                    child: EditCover(),  // 완전 고정
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