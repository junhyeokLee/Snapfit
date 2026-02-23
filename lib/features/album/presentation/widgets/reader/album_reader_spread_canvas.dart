import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/album_page.dart';
import '../../controllers/layer_builder.dart';
import '../../controllers/layer_interaction_manager.dart';
import 'album_reader_editable_canvas.dart';

/// 앨범 리더용 2페이지 스프레드(양면) 캔버스
class AlbumReaderSpreadCanvas extends StatelessWidget {
  final AlbumPage? leftPage;
  final AlbumPage? rightPage;
  final double canvasW;
  final double canvasH;
  final LayerInteractionManager interaction;
  final LayerBuilder layerBuilder;
  final ValueChanged<Size> onCanvasSizeChanged;

  const AlbumReaderSpreadCanvas({
    super.key,
    this.leftPage,
    this.rightPage,
    required this.canvasW,
    required this.canvasH,
    required this.interaction,
    required this.layerBuilder,
    required this.onCanvasSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: canvasW * 2,
      height: canvasH,
      decoration: BoxDecoration(
        color: SnapFitColors.pureWhite,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 왼쪽 페이지
              SizedBox(
                width: canvasW,
                height: canvasH,
                child: leftPage != null
                    ? AlbumReaderEditableCanvas(
                        page: leftPage!,
                        canvasW: canvasW,
                        canvasH: canvasH,
                        interaction: interaction,
                        layerBuilder: layerBuilder,
                        canvasKey: GlobalKey(),
                        onCanvasSizeChanged: onCanvasSizeChanged,
                        showShadow: false,
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 1), // 페이지 사이 구분선
              // 오른쪽 페이지
              SizedBox(
                width: canvasW,
                height: canvasH,
                child: rightPage != null
                    ? AlbumReaderEditableCanvas(
                        page: rightPage!,
                        canvasW: canvasW,
                        canvasH: canvasH,
                        interaction: interaction,
                        layerBuilder: layerBuilder,
                        canvasKey: GlobalKey(),
                        onCanvasSizeChanged: onCanvasSizeChanged,
                        showShadow: false,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          // 중앙 책심(Spine) 효과
          Center(
            child: Container(
              width: 1.w,
              height: canvasH,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.0),
                    Colors.black.withOpacity(0.1),
                  ],
                ),
              ),
            ),
          ),
          // 중앙 그림자 효과 (입체감)
          Center(
            child: Container(
              width: 20.w,
              height: canvasH,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.05),
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.05),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
