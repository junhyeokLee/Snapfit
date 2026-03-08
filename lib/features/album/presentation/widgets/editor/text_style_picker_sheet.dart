import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';

/// 텍스트 스타일 선택용 바텀시트 (이미지 레퍼런스: 탭·섹션·카드 구조)
class TextStylePickerSheet extends StatefulWidget {
  final String? selectedKey;
  final ValueChanged<String> onSelect;

  const TextStylePickerSheet({
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
      builder: (ctx) => TextStylePickerSheet(
        selectedKey: currentKey,
        onSelect: (key) => Navigator.pop(ctx, key),
      ),
    );
  }

  @override
  State<TextStylePickerSheet> createState() => _TextStylePickerSheetState();
}

/// 카테고리별 스타일 아이템 (키, 라벨, 프리뷰용 타입)
class _TextStyleItem {
  final String key;
  final String previewType;

  const _TextStyleItem({required this.key, required this.previewType});
}

/// 기본: 없음(테두리/색 없음) + 라운드
const List<_TextStyleItem> _basicStyles = [
  _TextStyleItem(key: '', previewType: 'none'),
  _TextStyleItem(key: 'round', previewType: 'round'),
];
/// 말풍선 – 라운드(왼쪽/가운데/오른쪽) / 사각형(왼쪽/가운데/오른쪽)
const List<_TextStyleItem> _speechBubbles = [
  _TextStyleItem(key: 'bubble', previewType: 'tailLeft'),
  _TextStyleItem(key: 'bubbleCenter', previewType: 'tailCenter'),
  _TextStyleItem(key: 'bubbleRight', previewType: 'tailRight'),
  _TextStyleItem(key: 'bubbleSquare', previewType: 'tailSquareLeft'),
  _TextStyleItem(key: 'bubbleSquareCenter', previewType: 'tailSquareCenter'),
  _TextStyleItem(key: 'bubbleSquareRight', previewType: 'tailSquareRight'),
];
/// 라벨 & 태그 – 타원 채움, 점선 태그, 아웃라인, 시안 채움 등
const List<_TextStyleItem> _labels = [
  _TextStyleItem(key: 'label', previewType: 'oval'),
  _TextStyleItem(key: 'labelSolid', previewType: 'labelSolid'),
  _TextStyleItem(key: 'tag', previewType: 'tag'),
  _TextStyleItem(key: 'labelOutline', previewType: 'labelOutline'),
];
/// 메모지 – 스티커노트 느낌, 여러 색상 (찢어짐 없음)
const List<_TextStyleItem> _notes = [
  _TextStyleItem(key: 'note', previewType: 'noteYellow'),
  _TextStyleItem(key: 'noteBlue', previewType: 'noteBlue'),
  _TextStyleItem(key: 'notePink', previewType: 'notePink'),
  _TextStyleItem(key: 'noteMint', previewType: 'noteMint'),
  _TextStyleItem(key: 'noteLavender', previewType: 'noteLavender'),
];
const List<_TextStyleItem> _tapes = [
  _TextStyleItem(key: 'tape', previewType: 'stripe'),
  _TextStyleItem(key: 'tapeYellow', previewType: 'tapeYellow'),
  _TextStyleItem(key: 'tapePink', previewType: 'tapePink'),
];

class _TextStylePickerSheetState extends State<TextStylePickerSheet> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    final surface = SnapFitColors.surfaceOf(context);
    final textPrimary = SnapFitColors.textPrimaryOf(context);
    final textSecondary = SnapFitColors.textSecondaryOf(context);
    final overlayLight = SnapFitColors.overlayLightOf(context);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? SnapFitColors.accentLight.withOpacity(0.2)
                : Colors.black.withOpacity(0.12),
            blurRadius: 20.r,
            offset: Offset(0, -4.h),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 560.h,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 12.h),
              Center(
                child: Container(
                  width: 48.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: SnapFitColors.overlayMediumOf(context),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              // 헤더: 제목 + 검색 아이콘 (이미지처럼)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Row(
                  children: [
                    Text(
                      '텍스트 및 스티커',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.search,
                      size: 22.r,
                      color: textSecondary,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              // 카테고리 탭 (말풍선 / 라벨 & 태그 / 메모지 / 마스킹 테이프) – 가로 스크롤
              SizedBox(
                height: 40.h,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  children: [
                    _buildTab('말풍선', 0),
                    SizedBox(width: 12.w),
                    _buildTab('라벨 & 태그', 1),
                    SizedBox(width: 12.w),
                    _buildTab('메모지', 2),
                    SizedBox(width: 12.w),
                    _buildTab('마스킹 테이프', 3),
                  ],
                ),
              ),
              SizedBox(height: 14.h),
              // 검색 바
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Container(
                  height: 44.h,
                  decoration: BoxDecoration(
                    color: overlayLight,
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 14.w),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        size: 20.r,
                        color: textSecondary,
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        '데코레이션 검색',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              // 섹션 리스트 (한 스크롤에 모두)
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: 24.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection(
                        titleKo: '기본',
                        titleEn: 'Basic',
                        items: _basicStyles,
                      ),
                      SizedBox(height: 24.h),
                      _buildSection(
                        titleKo: '말풍선',
                        titleEn: 'Speech Bubbles',
                        items: _speechBubbles,
                      ),
                      SizedBox(height: 24.h),
                      _buildSection(
                        titleKo: '라벨 & 태그',
                        titleEn: 'Labels',
                        items: _labels,
                      ),
                      SizedBox(height: 24.h),
                      _buildSection(
                        titleKo: '메모지',
                        titleEn: 'Sticky Notes',
                        items: _notes,
                      ),
                      SizedBox(height: 24.h),
                      _buildSection(
                        titleKo: '마스킹 테이프',
                        titleEn: 'Tapes',
                        items: _tapes,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? SnapFitColors.accent
                  : SnapFitColors.textSecondaryOf(context),
              fontSize: 14.sp,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          SizedBox(height: 8.h),
          Container(
            height: 2.5,
            width: isSelected ? 24.w : 0,
            decoration: BoxDecoration(
              color: SnapFitColors.accent,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String titleKo,
    required String titleEn,
    required List<_TextStyleItem> items,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$titleKo ($titleEn)',
                style: TextStyle(
                  color: SnapFitColors.textPrimaryOf(context),
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Text(
                  '모두 보기',
                  style: TextStyle(
                    color: SnapFitColors.accent,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 100.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => SizedBox(width: 12.w),
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = (widget.selectedKey ?? '') == item.key;
                return GestureDetector(
                  onTap: () => widget.onSelect(item.key),
                  child: Container(
                    width: 88.w,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: isSelected
                            ? SnapFitColors.accent
                            : SnapFitColors.overlayStrongOf(context),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _buildStylePreview(item.previewType),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 말풍선·라벨·메모지·테이프 시각 프리뷰 (바텀시트 디자인과 동일)
  Widget _buildStylePreview(String previewType) {
    switch (previewType) {
      case 'none':
        return _previewNone();
      case 'round':
        return _previewRound();
      case 'tailLeft':
        return _previewBubbleTailLeft();
      case 'tailCenter':
        return _previewBubbleTailCenter();
      case 'tailRight':
        return _previewBubbleTailRight();
      case 'tailSquareLeft':
        return _previewBubbleSquareLeft();
      case 'tailSquareCenter':
        return _previewBubbleSquareCenter();
      case 'tailSquareRight':
        return _previewBubbleSquareRight();
      case 'oval':
        return _previewLabelOval();
      case 'tag':
        return _previewTagDashed();
      case 'labelSolid':
        return _previewLabelSolid();
      case 'labelOutline':
        return _previewLabelOutline();
      case 'noteYellow':
        return _previewNoteYellow();
      case 'noteBlue':
        return _previewNoteBlue();
      case 'notePink':
        return _previewNotePink();
      case 'noteMint':
        return _previewNoteMint();
      case 'noteLavender':
        return _previewNoteLavender();
      case 'stripe':
        return _previewTapeStripe();
      case 'tapeYellow':
        return _previewTapeYellow();
      case 'tapePink':
        return _previewTapePink();
      default:
        return Icon(Icons.text_fields, size: 28.r, color: SnapFitColors.textSecondaryOf(context));
    }
  }

  /// 기본 없음 – 테두리/색 없음
  Widget _previewNone() {
    return Icon(Icons.text_fields, size: 28.r, color: SnapFitColors.textSecondaryOf(context));
  }

  /// 라운드 – 흰색 pill (바텀시트 디자인)
  Widget _previewRound() {
    return Container(
      width: 56.w,
      height: 28.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: const Color(0xFFE0E4EC), width: 1),
      ),
    );
  }

  /// 라벨 – 진한 파랑 채움 (MEMORIES 스타일)
  Widget _previewLabelSolid() {
    return Container(
      width: 64.w,
      height: 26.h,
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(999.r),
      ),
    );
  }

  /// 라벨 – 아웃라인만 (TODAY 스타일)
  Widget _previewLabelOutline() {
    return Container(
      width: 52.w,
      height: 26.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: SnapFitColors.accent, width: 1.5),
      ),
    );
  }

  /// 메모지 민트
  Widget _previewNoteMint() {
    return Container(
      width: 52.w,
      height: 36.h,
      decoration: BoxDecoration(
        color: const Color(0xFFE0F7F0),
        borderRadius: BorderRadius.circular(4.r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 2, offset: const Offset(0, 1))],
      ),
    );
  }

  /// 메모지 라벤더
  Widget _previewNoteLavender() {
    return Container(
      width: 52.w,
      height: 36.h,
      decoration: BoxDecoration(
        color: const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(4.r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 2, offset: const Offset(0, 1))],
      ),
    );
  }

  /// 테이프 노랑
  Widget _previewTapeYellow() {
    return Container(
      width: 60.w,
      height: 28.h,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9C4),
        borderRadius: BorderRadius.circular(4.r),
      ),
    );
  }

  /// 테이프 핑크
  Widget _previewTapePink() {
    return Container(
      width: 60.w,
      height: 28.h,
      decoration: BoxDecoration(
        color: const Color(0xFFFFE4EC),
        borderRadius: BorderRadius.circular(4.r),
      ),
    );
  }

  /// 말풍선 – 꼬리 왼쪽 하단 (가장자리에서 살짝 안쪽)
  Widget _previewBubbleTailLeft() {
    return SizedBox(
      width: 48.w,
      height: 32.h,
      child: CustomPaint(
        painter: _SpeechBubblePreviewPainter(tailPosition: 0.28),
      ),
    );
  }

  /// 말풍선 – 꼬리 하단 중앙
  Widget _previewBubbleTailCenter() {
    return SizedBox(
      width: 48.w,
      height: 32.h,
      child: CustomPaint(
        painter: _SpeechBubblePreviewPainter(tailPosition: 0.5),
      ),
    );
  }

  /// 말풍선 – 꼬리 하단 오른쪽 (가장자리에서 살짝 안쪽)
  Widget _previewBubbleTailRight() {
    return SizedBox(
      width: 48.w,
      height: 32.h,
      child: CustomPaint(
        painter: _SpeechBubblePreviewPainter(tailPosition: 0.72),
      ),
    );
  }

  /// 말풍선 – 사각형, 꼬리 왼쪽
  Widget _previewBubbleSquareLeft() {
    return SizedBox(
      width: 48.w,
      height: 32.h,
      child: CustomPaint(
        painter: _SquareBubblePreviewPainter(tailPosition: 0.0),
      ),
    );
  }

  /// 말풍선 – 사각형, 꼬리 가운데
  Widget _previewBubbleSquareCenter() {
    return SizedBox(
      width: 48.w,
      height: 32.h,
      child: CustomPaint(
        painter: _SquareBubblePreviewPainter(tailPosition: 0.5),
      ),
    );
  }

  /// 말풍선 – 사각형, 꼬리 오른쪽
  Widget _previewBubbleSquareRight() {
    return SizedBox(
      width: 48.w,
      height: 32.h,
      child: CustomPaint(
        painter: _SquareBubblePreviewPainter(tailPosition: 1.0),
      ),
    );
  }

  /// 라벨 – 타원형 하늘색
  Widget _previewLabelOval() {
    return Container(
      width: 56.w,
      height: 24.h,
      decoration: BoxDecoration(
        color: SnapFitColors.accent.withOpacity(0.25),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(
              color: SnapFitColors.accent,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 6.w),
          Container(
            width: 12.w,
            height: 2.h,
            color: SnapFitColors.accent,
          ),
        ],
      ),
    );
  }

  /// 라벨 – 점선 테두리 #TAG
  Widget _previewTagDashed() {
    return SizedBox(
      width: 64.w,
      height: 26.h,
      child: Stack(
        children: [
          Container(
            width: 64.w,
            height: 26.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Center(
              child: Text(
                '#TAG_HERE',
                style: TextStyle(
                  color: const Color(0xFF9E9E9E),
                  fontSize: 10.sp,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _DashedRectPainter(
                color: const Color(0xFFB0B0B0),
                strokeWidth: 1.5,
                borderRadius: 8.r,
                dashWidth: 4,
                dashSpace: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 메모지 – 연한 노랑 + 접힌 모서리
  Widget _previewNoteYellow() {
    return Container(
      width: 52.w,
      height: 36.h,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCE7),
        borderRadius: BorderRadius.circular(4.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: CustomPaint(
              size: Size(16.w, 16.h),
              painter: _FoldedCornerPainter(color: const Color(0xFFE8E0C0)),
            ),
          ),
        ],
      ),
    );
  }

  /// 메모지 – 연한 파랑
  Widget _previewNoteBlue() {
    return Container(
      width: 52.w,
      height: 36.h,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FF),
        borderRadius: BorderRadius.circular(4.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }

  /// 메모지 – 연한 분홍 + 핀
  Widget _previewNotePink() {
    return Container(
      width: 52.w,
      height: 36.h,
      decoration: BoxDecoration(
        color: const Color(0xFFFFEFF4),
        borderRadius: BorderRadius.circular(4.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.push_pin_outlined,
          size: 18.r,
          color: const Color(0xFFE0A0B0),
        ),
      ),
    );
  }

  /// 마스킹 테이프 – 사선 스트라이프
  Widget _previewTapeStripe() {
    return Container(
      width: 60.w,
      height: 28.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4.r),
        child: CustomPaint(
          painter: _StripeTapePainter(),
        ),
      ),
    );
  }
}

/// 말풍선 프리뷰 (꼬리 위치 0~1, 가장자리에서 살짝 안쪽으로)
class _SpeechBubblePreviewPainter extends CustomPainter {
  final double tailPosition;

  _SpeechBubblePreviewPainter({this.tailPosition = 0.5});

  static const double _previewTailMargin = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height * 0.4;
    final tailW = size.width * 0.18;
    final tailH = size.height * 0.35;
    final minX = _previewTailMargin + tailW / 2;
    final maxX = size.width - _previewTailMargin - tailW / 2;
    final tailX = (size.width * tailPosition).clamp(minX, maxX);

    final path = Path();
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height - tailH),
      Radius.circular(r),
    ));
    path.moveTo(tailX - tailW / 2, size.height - tailH);
    path.lineTo(tailX, size.height);
    path.lineTo(tailX + tailW / 2, size.height - tailH);
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 사각형 말풍선 프리뷰 – 꼬리 왼/가운데/오른, 가장자리에서 살짝 안쪽
class _SquareBubblePreviewPainter extends CustomPainter {
  final double tailPosition;

  _SquareBubblePreviewPainter({this.tailPosition = 0.5});

  static const double _tailW = 7.0;
  static const double _tailH = 5.0;
  static const double _margin = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyH = h - _tailH;
    final tailCenterX = tailPosition <= 0.25
        ? _margin + _tailW / 2
        : tailPosition >= 0.75
            ? w - _margin - _tailW / 2
            : w / 2;
    final tailLeft = tailCenterX - _tailW / 2;
    final tailRight = tailCenterX + _tailW / 2;

    final path = Path();
    path.moveTo(tailLeft, bodyH);
    path.lineTo(0, bodyH);
    path.lineTo(0, 0);
    path.lineTo(w, 0);
    path.lineTo(w, bodyH);
    path.lineTo(tailRight, bodyH);
    path.lineTo(tailCenterX, h);
    path.lineTo(tailLeft, bodyH);
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 접힌 모서리
class _FoldedCornerPainter extends CustomPainter {
  final Color color;

  _FoldedCornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = color,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, 0),
      Paint()
        ..color = const Color(0xFFD0D0C0)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 테이프 사선 스트라이프 (하늘색/흰색)
class _StripeTapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final teal = SnapFitColors.accent;
    final white = Colors.white;
    const stripeWidth = 6.0;
    var x = -size.height * 2;
    var index = 0;
    while (x < size.width + size.height * 2) {
      final paint = Paint()
        ..color = index.isEven ? teal : white
        ..style = PaintingStyle.fill;
      final path = Path();
      path.moveTo(x, 0);
      path.lineTo(x + stripeWidth, 0);
      path.lineTo(x + stripeWidth + size.height, size.height);
      path.lineTo(x + size.height, size.height);
      path.close();
      canvas.drawPath(path, paint);
      x += stripeWidth;
      index++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 점선 테두리 (라벨/태그 프리뷰)
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
    _drawDashedPath(canvas, path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final segment = metric.extractPath(
          distance,
          distance + dashWidth,
        );
        canvas.drawPath(segment, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
