import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../domain/entities/album.dart';
import '../../views/page_editor_screen.dart';
import '../editor/edit_cover.dart';
import 'home_paper_unfold_overlays.dart';

const _coverRadius = BorderRadius.only(
  topRight: Radius.circular(12),
  bottomRight: Radius.circular(12),
  bottomLeft: Radius.zero,
);

/// Paper: 앨범 페이지 편집 화면으로 갈 때 커버가 부채꼴로 펼쳐지며 드러나는 커스텀 라우트
class HomePaperUnfoldRoute extends PageRouteBuilder {
  final Album album;

  HomePaperUnfoldRoute({
    required this.album,
    Rect? cardRect,
    ui.Image? coverImage,
  }) : _cardRect = cardRect,
       _coverImage = coverImage,
       super(
         opaque: true,
         transitionDuration: const Duration(milliseconds: 450),
         reverseTransitionDuration: const Duration(milliseconds: 320),
         pageBuilder: (context, animation, secondaryAnimation) {
           return HomePaperUnfoldPage(
             album: album,
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

           if (coverImage != null &&
               rect != null &&
               rect.width > 0 &&
               rect.height > 0) {
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
                 HomeExpandOverlay(
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
class HomePaperUnfoldPage extends StatefulWidget {
  final Album album;
  final Rect? cardRect;
  final ui.Image? coverImage;

  const HomePaperUnfoldPage({
    super.key,
    required this.album,
    this.cardRect,
    this.coverImage,
  });

  @override
  State<HomePaperUnfoldPage> createState() => _HomePaperUnfoldPageState();
}

class _HomePaperUnfoldPageState extends State<HomePaperUnfoldPage>
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
    // 기존 PageEditorScreen 대신, 커버 편집 전용 EditCover를 사용해
    // 이전 버전의 커버 편집 경험(팝업 메뉴, 정사이즈 등)을 복원함
    final content = Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white, // 기본 배경색
      body: EditCover(editAlbum: widget.album),
    );
    final hasOverlay =
        widget.coverImage != null &&
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
          child: HomeCoverOpenOverlay(
            animation: _coverAnimation,
            coverImage: widget.coverImage!,
            openFromRight: true,
          ),
        ),
      ],
    );
  }
}
