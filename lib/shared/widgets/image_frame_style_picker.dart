import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/constants/snapfit_colors.dart';

/// 이미지 프레임 스타일 정의
class ImageFrameStyle {
  final String key;
  final String label;
  final String subtitle;
  final String category; // classic / vintage / pastel / artistic / basic

  const ImageFrameStyle({
    required this.key,
    required this.label,
    required this.subtitle,
    required this.category,
  });
}

/// 사용 가능한 이미지 프레임 스타일 목록
const List<ImageFrameStyle> imageFrameStyles = [
  ImageFrameStyle(key: '', label: '기본', subtitle: '원본 그대로', category: 'basic'),
  ImageFrameStyle(
    key: 'circle',
    label: '기본 원형',
    subtitle: 'Circle',
    category: 'basic',
  ),
  ImageFrameStyle(
    key: 'archSoft',
    label: '소프트 아치',
    subtitle: 'Editorial Arch',
    category: 'minimal',
  ),
  ImageFrameStyle(
    key: 'round',
    label: '소프트 라운드',
    subtitle: 'Pastel Dream',
    category: 'pastel',
  ),
  ImageFrameStyle(
    key: 'polaroid',
    label: '클래식 폴라로이드',
    subtitle: 'Standard White',
    category: 'classic',
  ),
  ImageFrameStyle(
    key: 'polaroidClassic',
    label: '카드 폴라로이드',
    subtitle: 'Cream Vintage',
    category: 'classic',
  ),
  ImageFrameStyle(
    key: 'polaroidWide',
    label: '와이드 폴라로이드',
    subtitle: 'Wide Shot',
    category: 'classic',
  ),
  ImageFrameStyle(
    key: 'polaroidFilm',
    label: '폴라로이드 필름',
    subtitle: 'Black Border',
    category: 'classic',
  ),
  ImageFrameStyle(
    key: 'film',
    label: '빈티지 필름 스트립',
    subtitle: 'Retro 35mm',
    category: 'vintage',
  ),
  ImageFrameStyle(
    key: 'vintage',
    label: '아티스틱 브러쉬',
    subtitle: 'Canvas Texture',
    category: 'artistic',
  ),
  ImageFrameStyle(
    key: 'softGlow',
    label: '소프트 글로우',
    subtitle: 'Highlight Mood',
    category: 'pastel',
  ),
  ImageFrameStyle(
    key: 'sticker',
    label: '스티커 프레임',
    subtitle: 'Bold Outline',
    category: 'artistic',
  ),
  ImageFrameStyle(
    key: 'sketch',
    label: '스케치 라인',
    subtitle: 'Hand-drawn',
    category: 'artistic',
  ),
  // 레트로 테크 & 픽셀
  ImageFrameStyle(
    key: 'win95',
    label: '90s 윈도우 프레임',
    subtitle: 'Win 95 Classic',
    category: 'retro',
  ),
  ImageFrameStyle(
    key: 'pixel8',
    label: '8비트 픽셀 보더',
    subtitle: 'Retro Game Style',
    category: 'retro',
  ),
  ImageFrameStyle(
    key: 'vhs',
    label: 'VHS 글리치',
    subtitle: 'Analog Static',
    category: 'retro',
  ),
  ImageFrameStyle(
    key: 'neon',
    label: '네온 사이버펑크',
    subtitle: 'Glowing Night',
    category: 'retro',
  ),
  // 낙서 & 스티커
  ImageFrameStyle(
    key: 'crayon',
    label: '손그림 크레파스',
    subtitle: 'Messy Crayon',
    category: 'artistic',
  ),
  ImageFrameStyle(
    key: 'notebook',
    label: '수업시간 낙서장',
    subtitle: 'Notebook Margin',
    category: 'artistic',
  ),
  ImageFrameStyle(
    key: 'tapeClip',
    label: '테이프 & 클립',
    subtitle: 'Tape & Clip Set',
    category: 'artistic',
  ),
  ImageFrameStyle(
    key: 'comicBubble',
    label: '코믹 말풍선',
    subtitle: 'Comic Bubble',
    category: 'artistic',
  ),
  ImageFrameStyle(
    key: 'blob',
    label: '뉴포스트 블랍',
    subtitle: 'Organic Mask',
    category: 'artistic',
  ),
  ImageFrameStyle(
    key: 'ticketStub',
    label: '티켓 카드',
    subtitle: 'RSVP Ticket',
    category: 'classic',
  ),
  // 미니멀 & 기하학
  ImageFrameStyle(
    key: 'thinDoubleLine',
    label: '씬 더블 라인',
    subtitle: 'Elegant Spacing',
    category: 'minimal',
  ),
  ImageFrameStyle(
    key: 'offsetColorBlock',
    label: '오프셋 컬러 블록',
    subtitle: 'Asymmetrical Border',
    category: 'minimal',
  ),
  ImageFrameStyle(
    key: 'floatingGlass',
    label: '플로팅 글래스',
    subtitle: 'Glassmorphism',
    category: 'minimal',
  ),
  ImageFrameStyle(
    key: 'gradientEdge',
    label: '그라데이션 엣지',
    subtitle: 'Blending Border',
    category: 'minimal',
  ),
  // 빈티지 페이퍼 & 아카이브
  ImageFrameStyle(
    key: 'tornNotebook',
    label: '찢어진 노트 페이지',
    subtitle: 'Torn Notebook',
    category: 'vintage',
  ),
  ImageFrameStyle(
    key: 'oldNewspaper',
    label: '오래된 신문 조각',
    subtitle: 'Old Newspaper',
    category: 'vintage',
  ),
  ImageFrameStyle(
    key: 'postalStamp',
    label: '우표 프레임',
    subtitle: 'Postal Stamp',
    category: 'vintage',
  ),
  ImageFrameStyle(
    key: 'kraftPaper',
    label: '크라프트 종이',
    subtitle: 'Brown Kraft Paper',
    category: 'vintage',
  ),
  // 클래식 갤러리
  ImageFrameStyle(
    key: 'goldFrame',
    label: '황금 갤러리',
    subtitle: 'Masterpiece Frame',
    category: 'classic',
  ),
  // 어반 프레임
  ImageFrameStyle(
    key: 'pinkSplatter',
    label: '핑크 스플래터',
    subtitle: 'Street Art',
    category: 'urban',
  ),
  ImageFrameStyle(
    key: 'toxicGlow',
    label: '톡시크 글로우',
    subtitle: 'Neon Lights',
    category: 'urban',
  ),
  ImageFrameStyle(
    key: 'stencilBlock',
    label: '스텐실 블록',
    subtitle: 'Concrete',
    category: 'urban',
  ),
  ImageFrameStyle(
    key: 'midnightDrip',
    label: '미드나잇 드립',
    subtitle: 'Tagged',
    category: 'urban',
  ),
  ImageFrameStyle(
    key: 'vaporStreet',
    label: '베이퍼 스트리트',
    subtitle: 'Acid',
    category: 'urban',
  ),
];

const _frameCategories = [
  {'key': 'all', 'label': '전체'},
  {'key': 'classic', 'label': '클래식'},
  {'key': 'vintage', 'label': '빈티지'},
  {'key': 'pastel', 'label': '파스텔'},
  {'key': 'artistic', 'label': '아티스틱'},
  {'key': 'retro', 'label': '레트로'},
  {'key': 'minimal', 'label': '미니멀'},
  {'key': 'urban', 'label': '어반'},
];

/// 이미지 프레임 스타일 선택 바텀시트
class ImageFrameStylePicker extends StatefulWidget {
  final String? selectedKey;
  final ValueChanged<String> onSelect;

  const ImageFrameStylePicker({
    super.key,
    required this.selectedKey,
    required this.onSelect,
  });

  static Future<String?> show(
    BuildContext context, {
    required String? currentKey,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ImageFrameStylePicker(
        selectedKey: currentKey,
        onSelect: (key) => Navigator.pop(ctx, key),
      ),
    );
  }

  @override
  State<ImageFrameStylePicker> createState() => _ImageFrameStylePickerState();
}

class _ImageFrameStylePickerState extends State<ImageFrameStylePicker> {
  String _selectedCategory = 'all';

  List<ImageFrameStyle> get _visibleStyles {
    if (_selectedCategory == 'all') return imageFrameStyles;
    return imageFrameStyles
        .where((s) => s.category == _selectedCategory || s.category == 'basic')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        boxShadow: [
          BoxShadow(
            color: SnapFitColors.isDark(context)
                ? SnapFitColors.accentLight.withOpacity(0.25)
                : Colors.black.withOpacity(0.18),
            blurRadius: 20.r,
            offset: Offset(0, -4.h),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 12.h),
            // 드래그 핸들
            Container(
              width: 48.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: SnapFitColors.overlayMediumOf(context),
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
            SizedBox(height: 20.h),
            // 제목
            Text(
              '사진 프레임 세트',
              style: TextStyle(
                color: SnapFitColors.textPrimaryOf(context),
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 12.h),
            // 카테고리 탭
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: _frameCategories.map((c) {
                  final key = c['key'] as String;
                  final label = c['label'] as String;
                  final bool selected = _selectedCategory == key;
                  return Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedCategory = key);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? SnapFitColors.accent.withOpacity(0.12)
                              : SnapFitColors.overlayLightOf(context),
                          borderRadius: BorderRadius.circular(999.r),
                          border: Border.all(
                            color: selected
                                ? SnapFitColors.accent
                                : SnapFitColors.overlayMediumOf(context),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: selected
                                ? SnapFitColors.accent
                                : SnapFitColors.textSecondaryOf(context),
                            fontSize: 12.sp,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 12.h),
            // 프레임 스타일 카드 그리드 (조금 더 높게)
            SizedBox(
              height: 420.h,
              child: Padding(
                padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 16.h),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12.w,
                    mainAxisSpacing: 16.h,
                    childAspectRatio: 3 / 4,
                  ),
                  itemCount: _visibleStyles.length,
                  itemBuilder: (context, index) {
                    final style = _visibleStyles[index];
                    final isSelected = (widget.selectedKey ?? '') == style.key;
                    return _FrameStyleItem(
                      style: style,
                      isSelected: isSelected,
                      onTap: () => widget.onSelect(style.key),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrameStyleItem extends StatelessWidget {
  final ImageFrameStyle style;
  final bool isSelected;
  final VoidCallback onTap;

  const _FrameStyleItem({
    required this.style,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: SnapFitColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: isSelected
                ? SnapFitColors.accent
                : SnapFitColors.overlayStrongOf(context),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10.r,
              offset: Offset(0, 4.h),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(8.w),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(child: _buildFramePreview(style.key)),
                    if (style.key == 'polaroid')
                      Positioned(
                        top: -2.h,
                        right: -2.w,
                        child: Container(
                          width: 22.w,
                          height: 22.w,
                          decoration: BoxDecoration(
                            color: SnapFitColors.accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.star,
                            size: 12.sp,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Column(
                children: [
                  Text(
                    style.label,
                    style: TextStyle(
                      color: SnapFitColors.textPrimaryOf(context),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    style.subtitle,
                    style: TextStyle(
                      color: SnapFitColors.textSecondaryOf(context),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: 6.h),
          ],
        ),
      ),
    );
  }

  Widget _buildFramePreview(String key) {
    final placeholder = Container(
      decoration: const BoxDecoration(color: Color(0xFFE6E9F0)),
    );

    Widget content;
    switch (key) {
      case 'circle':
        // 기본 원형: 바텀시트 디자인대로 원형 클리핑
        content = ClipOval(child: placeholder);
        break;
      case 'archSoft':
        content = ClipPath(clipper: _ArchPreviewClipper(), child: placeholder);
        break;
      case 'round':
        // 소프트 라운드: 카드 없이 사진만 둥글게 (바텀시트와 동일 18.r)
        content = ClipRRect(
          borderRadius: BorderRadius.circular(18.r),
          child: placeholder,
        );
        break;
      case 'polaroid':
        content = _previewPolaroidStandard(placeholder);
        break;
      case 'polaroidClassic':
        content = _previewPolaroidClassic(placeholder);
        break;
      case 'polaroidWide':
        content = _previewPolaroidWide(placeholder);
        break;
      case 'polaroidFilm':
        content = _previewPolaroidFilm(placeholder);
        break;
      case 'sticker':
        content = Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6.r),
            child: placeholder,
          ),
        );
        break;
      case 'vintage':
        // 아티스틱 브러쉬 느낌: 연그레이-블루 이중 경계
        content = Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: const Color(0xFFE0E4F2), width: 2),
          ),
          padding: EdgeInsets.all(10.w),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FF),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: const Color(0xFFD0D7F0), width: 1.4),
            ),
          ),
        );
        break;
      case 'film':
        content = _previewFilmStrip();
        break;
      case 'softGlow':
        content = Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFF5FB), Color(0xFFE9F4FF)],
            ),
            borderRadius: BorderRadius.circular(24.r),
          ),
          padding: EdgeInsets.all(10.w),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.r),
            child: placeholder,
          ),
        );
        break;
      case 'sketch':
        content = Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(4.r),
            border: Border.all(color: Colors.black87, width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2.r),
            child: placeholder,
          ),
        );
        break;
      case 'win95':
        content = _previewWin95();
        break;
      case 'pixel8':
        content = _previewPixel8(placeholder);
        break;
      case 'vhs':
        content = _previewVhs();
        break;
      case 'neon':
        content = _previewNeon(placeholder);
        break;
      case 'crayon':
        content = _previewCrayon(placeholder);
        break;
      case 'notebook':
        content = _previewNotebook(placeholder);
        break;
      case 'tapeClip':
        content = _previewTapeClip(placeholder);
        break;
      case 'comicBubble':
        content = _previewComicBubble(placeholder);
        break;
      case 'thinDoubleLine':
        content = _previewThinDoubleLine(placeholder);
        break;
      case 'offsetColorBlock':
        content = _previewOffsetColorBlock(placeholder);
        break;
      case 'floatingGlass':
        content = _previewFloatingGlass(placeholder);
        break;
      case 'gradientEdge':
        content = _previewGradientEdge(placeholder);
        break;
      case 'tornNotebook':
        content = _previewTornNotebook(placeholder);
        break;
      case 'oldNewspaper':
        content = _previewOldNewspaper(placeholder);
        break;
      case 'postalStamp':
        content = _previewPostalStamp(placeholder);
        break;
      case 'kraftPaper':
        content = _previewKraftPaper(placeholder);
        break;
      case 'goldFrame':
        content = _previewGoldFrame(placeholder);
        break;
      case 'ticketStub':
        content = Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: const Color(0xFF243B53),
                borderRadius: BorderRadius.circular(18.r),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F0E6),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: placeholder,
                ),
              ),
            ),
            Positioned(left: -6.w, top: 38.h, child: _ticketNotch()),
            Positioned(right: -6.w, top: 38.h, child: _ticketNotch()),
            Positioned(left: -6.w, bottom: 24.h, child: _ticketNotch()),
            Positioned(right: -6.w, bottom: 24.h, child: _ticketNotch()),
          ],
        );
        break;
      case 'pinkSplatter':
        content = _previewPinkSplatter(placeholder);
        break;
      case 'toxicGlow':
        content = _previewToxicGlow(placeholder);
        break;
      case 'stencilBlock':
        content = _previewStencilBlock(placeholder);
        break;
      case 'midnightDrip':
        content = _previewMidnightDrip(placeholder);
        break;
      case 'vaporStreet':
        content = _previewVaporStreet(placeholder);
        break;
      default:
        content = placeholder;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: content,
        );
      },
    );
  }

  Widget _ticketNotch() => Container(
    width: 12.w,
    height: 12.w,
    decoration: BoxDecoration(
      color: const Color(0xFFF7F0E6),
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFF243B53), width: 1.w),
    ),
  );

  /// 레퍼런스: 클래식 폴라로이드 - 실제 적용된 프레임과 동일 비율/사진 영역
  Widget _previewPolaroidStandard(Widget child) {
    return AspectRatio(
      // 실제 폴라로이드와 동일하게 세로가 더 긴 비율
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: const Color(0xFFE0E3EC), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        // 실제 프레임과 동일: 좌우/위 20, 아래 80
        padding: EdgeInsets.fromLTRB(20.w, 40.h, 20.w, 80.h),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6.r),
          child: SizedBox.expand(child: child),
        ),
      ),
    );
  }

  /// 크림톤 카드 폴라로이드 (Cream Vintage) – 실제 적용된 프레임과 동일 비율/사진 영역
  Widget _previewPolaroidClassic(Widget child) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFEF5),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFE8E4D8), width: 1.1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 7,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        // 실제 프레임과 동일: 좌우/위 20, 아래 80
        padding: EdgeInsets.fromLTRB(20.w, 40.h, 20.w, 80.h),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6.r),
          child: SizedBox.expand(child: child),
        ),
      ),
    );
  }

  Widget _previewPolaroidWide(Widget child) {
    return Container(
      padding: EdgeInsets.fromLTRB(2.w, 6.w, 2.w, 14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.35), width: 0.8),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(3.r), child: child),
    );
  }

  /// 폴라로이드 필름 – 검은 카드 + 폴라로이드 비율
  Widget _previewPolaroidFilm(Widget child) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(20.w, 40.h, 20.w, 80.h),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6.r),
          child: child,
        ),
      ),
    );
  }

  /// 레퍼런스: 빈티지 필름 스트립 - 짙은 남색, 양쪽 4개씩 연한 타공, 중앙 화면
  Widget _previewFilmStrip() {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF151B2C),
          borderRadius: BorderRadius.circular(10.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 8.h),
        child: Row(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (_) {
                return Container(
                  width: 5.w,
                  height: 5.w,
                  margin: EdgeInsets.symmetric(vertical: 2.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3D4556),
                    borderRadius: BorderRadius.circular(1.r),
                  ),
                );
              }),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2433),
                  borderRadius: BorderRadius.circular(6.r),
                ),
              ),
            ),
            SizedBox(width: 4.w),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (_) {
                return Container(
                  width: 5.w,
                  height: 5.w,
                  margin: EdgeInsets.symmetric(vertical: 2.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3D4556),
                    borderRadius: BorderRadius.circular(1.r),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  /// 90s 윈도우 프레임 – 다크블루 타이틀바 + 흰 콘텐츠
  Widget _previewWin95() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFC0C0C0),
        border: Border.all(color: const Color(0xFF808080), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            height: 22.h,
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            color: const Color(0xFF000080),
            child: Row(
              children: [
                Text(
                  'image.exe',
                  style: TextStyle(color: Colors.white, fontSize: 11.sp),
                ),
                const Spacer(),
                _win95Button(const Color(0xFFC0C0C0)),
                SizedBox(width: 2.w),
                _win95Button(const Color(0xFFC0C0C0)),
                SizedBox(width: 2.w),
                _win95Button(const Color(0xFFC0C0C0)),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              alignment: Alignment.center,
              child: Icon(
                Icons.image_outlined,
                size: 24.r,
                color: const Color(0xFFC0C0C0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _win95Button(Color bg) {
    return Container(
      width: 14.w,
      height: 12.h,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: const Color(0xFF808080)),
      ),
      child: Icon(Icons.close, size: 8.r, color: Colors.black87),
    );
  }

  /// 8비트 픽셀 보더 – 검은 테두리 + 흰 내부 + 점선 + 코너 컬러
  Widget _previewPixel8(Widget placeholder) {
    const cornerColors = [
      Color(0xFFFFFF00),
      Color(0xFFFF0000),
      Color(0xFF0000FF),
      Color(0xFF00FF00),
    ];
    return Container(
      padding: EdgeInsets.all(2.w),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black, width: 1),
            ),
            child: Center(
              child: Container(
                margin: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black54, width: 1),
                ),
                child: placeholder,
              ),
            ),
          ),
          Positioned(
            top: -2,
            left: -2,
            child: Container(width: 6.w, height: 6.w, color: cornerColors[0]),
          ),
          Positioned(
            top: -2,
            right: -2,
            child: Container(width: 6.w, height: 6.w, color: cornerColors[1]),
          ),
          Positioned(
            bottom: -2,
            left: -2,
            child: Container(width: 6.w, height: 6.w, color: cornerColors[2]),
          ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(width: 6.w, height: 6.w, color: cornerColors[3]),
          ),
        ],
      ),
    );
  }

  /// VHS 글리치 – 어두운 화면, 스캔라인, PLAY + 타임코드
  Widget _previewVhs() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Stack(
        children: [
          // 스캔라인 느낌
          Positioned.fill(child: CustomPaint(painter: _ScanLinePainter())),
          Padding(
            padding: EdgeInsets.all(6.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'PLAY',
                      style: TextStyle(
                        color: const Color(0xFF00FF00),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Icon(
                      Icons.play_arrow,
                      color: const Color(0xFF00FF00),
                      size: 12.r,
                    ),
                  ],
                ),
                const Spacer(),
                Center(
                  child: Text(
                    'SP 00:12:44',
                    style: TextStyle(color: Colors.white70, fontSize: 9.sp),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 네온 사이버펑크 – 검은 내부 + 시안 글로우 테두리
  Widget _previewNeon(Widget placeholder) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: const Color(0xFF00FFFF), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FFFF).withOpacity(0.6),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      padding: EdgeInsets.all(3.w),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2.r),
            child: Container(
              color: Colors.black,
              child: FittedBox(fit: BoxFit.cover, child: placeholder),
            ),
          ),
          Positioned(
            top: 2,
            left: 2,
            child: CustomPaint(
              size: Size(12.w, 12.w),
              painter: _NeonCornerPainter(),
            ),
          ),
        ],
      ),
    );
  }

  /// 손그림 크레파스 – 연한 오렌지/피치, 점선 테두리
  Widget _previewCrayon(Widget placeholder) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFE4CC),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE8B88A), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.r),
        child: placeholder,
      ),
    );
  }

  /// 수업시간 낙서장 – 흰 노트, 좌우 점선(타공), 연한 핑크 라인
  Widget _previewNotebook(Widget placeholder) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          _notebookMarginDots(),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: Colors.pink.shade100, width: 1),
                ),
              ),
              child: placeholder,
            ),
          ),
          _notebookMarginDots(),
        ],
      ),
    );
  }

  Widget _notebookMarginDots() {
    return SizedBox(
      width: 8.w,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          6,
          (_) => Container(
            width: 3.w,
            height: 3.w,
            decoration: BoxDecoration(
              color: const Color(0xFFB0B0B0),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  /// 테이프 & 클립 – 클립 상단, 테이프 우하단
  Widget _previewTapeClip(Widget placeholder) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6F0),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFE8E4DC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: 12.h,
              left: 6.w,
              right: 6.w,
              bottom: 6.h,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6.r),
              child: placeholder,
            ),
          ),
          Positioned(
            top: -4,
            left: 0,
            right: 0,
            child: Center(
              child: Icon(
                Icons.attach_file,
                size: 20.r,
                color: const Color(0xFF505050),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: Transform.rotate(
              angle: 0.3,
              child: Container(
                width: 28.w,
                height: 14.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEB3B).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(2.r),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 코믹 말풍선 – 굵은 검은 테두리
  Widget _previewComicBubble(Widget placeholder) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.black, width: 3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5.r),
        child: placeholder,
      ),
    );
  }

  /// 씬 더블 라인 – 얇은 밝은 회색 이중선 테두리
  Widget _previewThinDoubleLine(Widget placeholder) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(8.w),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4.r),
          border: Border.all(color: const Color(0xFFE0E4EC), width: 1),
        ),
        padding: EdgeInsets.all(4.w),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE8ECF0), width: 1),
            borderRadius: BorderRadius.circular(2.r),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2.r),
            child: placeholder,
          ),
        ),
      ),
    );
  }

  /// 오프셋 컬러 블록 – 상단·좌측 검은 테두리, 하단·우측 연한 파란 인셋
  Widget _previewOffsetColorBlock(Widget placeholder) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.r),
        border: Border(
          top: BorderSide(color: Colors.black, width: 4),
          left: BorderSide(color: Colors.black, width: 4),
          right: BorderSide(color: const Color(0xFFB0D0E8), width: 1),
          bottom: BorderSide(color: const Color(0xFFB0D0E8), width: 1),
        ),
      ),
      margin: EdgeInsets.only(right: 4.w, bottom: 4.h),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2.r),
        child: placeholder,
      ),
    );
  }

  /// 플로팅 글래스 – 글래스모피즘 다층
  Widget _previewFloatingGlass(Widget placeholder) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA0B0E0).withOpacity(0.25),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.all(6.w),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: placeholder,
          ),
        ),
      ),
    );
  }

  /// 그라데이션 엣지 – 파랑→보라·핑크 테두리
  Widget _previewGradientEdge(Widget placeholder) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.r),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6EB5FF), Color(0xFFB88AFF), Color(0xFFFF9EC5)],
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(2.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6.r),
          child: placeholder,
        ),
      ),
    );
  }

  /// 찢어진 노트 페이지 – 크림 배경, 찢어진 하단·우측, 점선 내부, 바인더 구멍
  Widget _previewTornNotebook(Widget placeholder) {
    return ClipPath(
      clipper: _TornPaperEdgeClipper(),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF0),
          boxShadow: [
            BoxShadow(
              color: Colors.brown.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(10.w, 10.w, 8.w, 12.h),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(10.w),
                child: CustomPaint(
                  painter: _DashedRectPainter(
                    color: const Color(0xFFE8E0D0),
                    strokeWidth: 1,
                    borderRadius: 4.r,
                    dashWidth: 3,
                    dashSpace: 4,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12.h,
              left: 12.w,
              child: Container(
                width: 6.w,
                height: 6.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0C8B8).withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(padding: EdgeInsets.all(12.w), child: placeholder),
          ],
        ),
      ),
    );
  }

  /// 오래된 신문 조각 – 베이지, 상단 헤더 영역, 하단 텍스트 라인
  Widget _previewOldNewspaper(Widget placeholder) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E6),
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: const Color(0xFFE0D8C8), width: 1),
      ),
      child: Column(
        children: [
          Container(height: 12.h, color: const Color(0xFFE8E0D4)),
          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
              color: const Color(0xFFF8F4EC),
              child: placeholder,
            ),
          ),
          Container(
            height: 3.h,
            margin: EdgeInsets.symmetric(horizontal: 8.w),
            color: const Color(0xFFD8D0C4),
          ),
          SizedBox(height: 2.h),
          Container(
            height: 3.h,
            margin: EdgeInsets.symmetric(horizontal: 8.w),
            color: const Color(0xFFD8D0C4),
          ),
          SizedBox(height: 6.h),
        ],
      ),
    );
  }

  /// 우표 프레임 – 톱니 천공(좌·상·우), 우측상단 날짜 스탬프
  Widget _previewPostalStamp(Widget placeholder) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2.r),
        border: Border.all(color: const Color(0xFFC0C0C0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipPath(
        clipper: _StampPerforationClipper(),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.all(8.w),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2.r),
                child: placeholder,
              ),
            ),
            Positioned(
              top: 6.h,
              right: 6.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E8E8),
                  borderRadius: BorderRadius.circular(999.r),
                ),
                child: Text(
                  '1924',
                  style: TextStyle(
                    fontSize: 8.sp,
                    color: const Color(0xFF707070),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 크라프트 종이 – 갈색, 안쪽 더 진한 테두리
  Widget _previewKraftPaper(Widget placeholder) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFB8956E),
        borderRadius: BorderRadius.circular(4.r),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(6.w),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFC9A86C),
          borderRadius: BorderRadius.circular(2.r),
          border: Border.all(color: const Color(0xFFA08050), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(1.r),
          child: placeholder,
        ),
      ),
    );
  }

  /// 황금 갤러리 – 두꺼운 황금색 테두리
  Widget _previewGoldFrame(Widget placeholder) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2.r),
        border: Border.all(color: const Color(0xFFC9A227), width: 10),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B6914).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(4.w),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(1.r),
        child: placeholder,
      ),
    );
  }

  /// 핑크 스플래터 – 점선 마젠타·핑크 테두리
  Widget _previewPinkSplatter(Widget placeholder) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: placeholder),
          Positioned.fill(
            child: CustomPaint(
              painter: _DashedRectPainter(
                color: const Color(0xFFFF60A0),
                strokeWidth: 2,
                borderRadius: 8.r,
                dashWidth: 5,
                dashSpace: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 톡시크 글로우 – 두꺼운 네온 그린 테두리
  Widget _previewToxicGlow(Widget placeholder) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: const Color(0xFF39FF14), width: 3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF39FF14).withOpacity(0.5),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5.r),
        child: placeholder,
      ),
    );
  }

  /// 스텐실 블록 – 크림 배경, 스텐실 느낌 테두리
  Widget _previewStencilBlock(Widget placeholder) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4EC),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFD0B898), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: placeholder,
      ),
    );
  }

  /// 미드나잇 드립 – 베이지 태그, 상단 구멍·끈
  Widget _previewMidnightDrip(Widget placeholder) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0E8DC),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: const Color(0xFFD8D0C0)),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: 14.h,
              left: 6.w,
              right: 6.w,
              bottom: 6.h,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: placeholder,
            ),
          ),
          Positioned(
            top: 2,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 12.w,
                height: 8.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0D8C8),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(4.r),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 베이퍼 스트리트 – 분홍·보라 그라데이션 느낌 테두리
  Widget _previewVaporStreet(Widget placeholder) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFC44DFF), width: 3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC44DFF).withOpacity(0.35),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6.r),
        child: Stack(
          fit: StackFit.expand,
          children: [
            placeholder,
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFFF6B9D).withOpacity(0.2),
                    const Color(0xFFC44DFF).withOpacity(0.12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// VHS 스캔라인
class _ScanLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.03);
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 네온 코너 L자
class _NeonCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00FFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const r = 6.0;
    canvas.drawPath(
      Path()
        ..moveTo(0, r)
        ..lineTo(0, 0)
        ..lineTo(r, 0),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 찢어진 종이 가장자리 클리퍼
class _TornPaperEdgeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width - 8, 0);
    path.lineTo(size.width, 8);
    path.lineTo(size.width, size.height - 12);
    for (var i = 0.0; i < 6; i++) {
      path.lineTo(size.width - 4 - (i * 3), size.height - 8 + (i % 2) * 4);
    }
    path.lineTo(12, size.height);
    path.lineTo(0, size.height - 8);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ArchPreviewClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final archBottom = size.height * 0.32;
    final midX = size.width * 0.5;
    return Path()
      ..moveTo(0, size.height)
      ..lineTo(0, archBottom)
      ..quadraticBezierTo(midX, 0, size.width, archBottom)
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// 우표 톱니 천공 클리퍼 (좌·상·우만 톱니)
class _StampPerforationClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// 점선 사각형 페인터 (프리뷰용)
class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double borderRadius;
  final double dashWidth;
  final double dashSpace;

  _DashedRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.borderRadius,
    this.dashWidth = 4,
    this.dashSpace = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final segment = metric.extractPath(distance, distance + dashWidth);
        canvas.drawPath(segment, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
