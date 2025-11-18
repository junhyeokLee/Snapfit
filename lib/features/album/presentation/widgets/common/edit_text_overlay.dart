import 'dart:core';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:snap_fit/features/album/presentation/widgets/common/triangle_slider.dart';
import '../../../domain/entities/layer.dart';
import 'color_palette_list.dart';
import 'font_picker_list.dart';
import 'no_glow.dart';
import '../editor/tool_button.dart';
import '../editor/top_bar.dart';

/// 인스타그램 스타일 텍스트 편집 오버레이 (C. 전체 리팩토링)
/// ----------------------------------------------------------------
/// - MVVM 친화: 상태는 상위(에디터)에서만 관리, 하위 툴바는 콜백 기반
/// - 레이아웃 안정성: 어떤 해상도/키보드 높이에서도 overflow/ParentData 오류 방지
/// - 구조 분리: 상단바 / 중앙 편집 / 하단 패널(섹션 컴포넌트)로 모듈화
/// - 접근성: 탭영역, 스크롤 가로/세로, 키보드 안전영역, Material ancestor 보장
/// ----------------------------------------------------------------
enum EditPanelMode { none, font, color, align, background }

class EditTextOverlay extends StatefulWidget {
  final String initialText;
  final TextStyle initialStyle;
  // Updated onSubmit signature to accept BackgroundMode and Color? bubbleColor
  final void Function(String newText, TextStyle newStyle, TextStyleType textStyleType, Color? bubbleColor, TextAlign align) onSubmit;
  final VoidCallback onCancel;
  final TextStyleType? initialMode;
  final Color? initialBubbleColor;

  const EditTextOverlay({
    super.key,
    required this.initialText,
    required this.initialStyle,
    required this.onSubmit,
    required this.onCancel,
    this.initialMode,
    this.initialBubbleColor,
  });

  @override
  State<EditTextOverlay> createState() => _EditTextOverlayState();
}

class _EditTextOverlayState extends State<EditTextOverlay> with WidgetsBindingObserver {
  bool _keyboardWasVisible = true;
  bool _initialOpenHandled = false;
  late final TextEditingController _controller;
  late final FocusNode _focus;

  // 편집 상태 (폰트/색/정렬/배경)
  late TextStyle _style;
  late TextAlign _align;

  // 배경 모드
  late TextStyleType _textStyleType;

  // Separate bubble color (for fullBoxSolid mode)
  Color? _bubbleColor;

  // 폰트 패밀리 (pubspec.yaml 등록 필요)
  final List<String> _fontFamilies = const [
    'NotoSans',
    'Aggravo',
    'Eulyoo',
    'Tenada',
    'Arirang',
    'Arirang2',
    'Arirang3',
    'Raleway',
    'Roboto',
    'Yeongwol',
    'Cormorant',
    'Samlip',
    'Run',
    'Poppins',
    'Recipekorea',
    'SeoulNamsan',
  ];
  late String _currentFont;

  // 편집 패널 모드
  EditPanelMode _panelMode = EditPanelMode.font;

  // 폰트 크기 스케일 (0.8 ~ 2.5)
  final double _fontScale = 1.0;
  final GlobalKey repaintKey = GlobalKey();
  final GlobalKey<EditableTextState> _editableKey = GlobalKey<EditableTextState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focus = FocusNode();

    _align = TextAlign.center;

    _style = widget.initialStyle;
    _currentFont = widget.initialStyle.fontFamily ?? _fontFamilies.first;

    _textStyleType = widget.initialMode ?? TextStyleType.none;
    _bubbleColor = widget.initialBubbleColor;

    _controller.addListener(() {
      if (!mounted) return;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bottomInset = MediaQuery.of(context).viewInsets.bottom;
      final keyboardVisibleNow = bottomInset > 0;

      // 첫 키보드 오픈 감지: 오버레이가 뜨고 처음으로 키보드가 열릴 때만 실행
      if (!_initialOpenHandled && keyboardVisibleNow) {
        _keyboardWasVisible = true;
        _initialOpenHandled = true;
        return;
      }

      // 열림 -> 닫힘 감지 (디바운스 적용: 일시적인 insets 변동에 닫히지 않게)
      if (_keyboardWasVisible && !keyboardVisibleNow && _initialOpenHandled) {
            _keyboardWasVisible = false;
            Navigator.of(context, rootNavigator: true).pop();
      }

      if (keyboardVisibleNow) {
        _keyboardWasVisible = true;
      }
    });
  }

  // ---------- 콜백 (툴바 → 상위 상태 갱신) ----------
  void _changeTextColor(Color c) {
    setState(() {
      _style = _style.copyWith(color: c);
    });
  }

  void _changeFont(String family) => setState(() {
    _currentFont = family;
    _style = _style.copyWith(fontFamily: family);
  });

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      widget.onCancel();
      return;
    }
    final newStyle = _style.copyWith(
      fontFamily: _currentFont,
      fontSize: _style.fontSize,
      color: _style.color,
      shadows: () {
        if (_textStyleType == TextStyleType.textOuter) {
          final base = _style.color ?? Colors.black;
          final contrast = (base.computeLuminance() > 0.5) ? Colors.black : Colors.white;
          return _outline(contrast);
        } else if (_textStyleType == TextStyleType.textInner) {
          final base = _style.color ?? Colors.white;
          final contrast = (base.computeLuminance() > 0.5) ? Colors.black : Colors.white;
          return _innerOutline(contrast);
        }
        return null;
      }(),
    );

    Color? bubbleColor;
    bubbleColor = null;
    widget.onSubmit(
      text,
      newStyle,
      _textStyleType,
      bubbleColor,
      _align,
    );
  }

  void _togglePanel(EditPanelMode mode) {
    if (mode == EditPanelMode.align) {
      setState(() {
        if (_align == TextAlign.left) {
          _align = TextAlign.center;
        } else if (_align == TextAlign.center) {
          _align = TextAlign.right;
        } else {
          _align = TextAlign.left;
        }
        _panelMode = EditPanelMode.none;
      });

      // 포커스를 새로 요청해 텍스트 정렬이 즉시 반영되도록 함
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focus.requestFocus();
        }
      });
    } else if (mode == EditPanelMode.background) {
      _toggleBackground();
    } else {
      setState(() {
        _panelMode = (_panelMode == mode ? EditPanelMode.none : mode);
      });
    }
  }

  void _toggleBackground() {
    setState(() {
      // Cycle: none -> textOuter -> textInner -> fullBoxSolid -> none
      switch (_textStyleType) {
        case TextStyleType.none:
          _textStyleType = TextStyleType.textOuter;
          break;
        case TextStyleType.textOuter:
          _textStyleType = TextStyleType.textInner;
          break;
        case TextStyleType.textInner:
          default:
        _textStyleType = TextStyleType.none;
          break;
      }
      _panelMode = EditPanelMode.none;
    });

    // 토글 직후에도 키보드/포커스가 절대 내려가지 않도록 즉시 & 다음 프레임 모두 요청
    _focus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  // 외곽선(스트로크 모사) Shadow 8방향
  List<Shadow> _outline(Color oc) => const [
    Shadow(offset: Offset(0, 0), blurRadius: 0),
    Shadow(offset: Offset(1, 0), blurRadius: 0),
    Shadow(offset: Offset(-1, 0), blurRadius: 0),
    Shadow(offset: Offset(0, 1), blurRadius: 0),
    Shadow(offset: Offset(0, -1), blurRadius: 0),
    Shadow(offset: Offset(1, 1), blurRadius: 0),
    Shadow(offset: Offset(1, -1), blurRadius: 0),
    Shadow(offset: Offset(-1, 1), blurRadius: 0),
    Shadow(offset: Offset(-1, -1), blurRadius: 0),
  ].map((s) => Shadow(offset: s.offset, blurRadius: s.blurRadius, color: oc)).toList();

  // 내부 인버스 스트로크 (offset 반전, 더 미묘한 내부 효과, 대비색 사용)
  List<Shadow> _innerOutline(Color ic) {
    Color base = ic;
    Color contrastColor = (base.computeLuminance() > 0.5) ? Colors.black : Colors.white;
    return [
      Shadow(offset: Offset(0, 0), blurRadius: 0),
      Shadow(offset: Offset(0.5, 0), blurRadius: 0),
      Shadow(offset: Offset(-0.5, 0), blurRadius: 0),
      Shadow(offset: Offset(0, 0.5), blurRadius: 0),
      Shadow(offset: Offset(0, -0.5), blurRadius: 0),
      Shadow(offset: Offset(0.5, 0.5), blurRadius: 0),
      Shadow(offset: Offset(0.5, -0.5), blurRadius: 0),
      Shadow(offset: Offset(-0.5, 0.5), blurRadius: 0),
      Shadow(offset: Offset(-0.5, -0.5), blurRadius: 0),
    ].map((s) => Shadow(offset: s.offset, blurRadius: s.blurRadius, color: contrastColor)).toList();
  }

  Widget _buildOptionList() {
    switch (_panelMode) {
      case EditPanelMode.font:
        return FontPickerList(
          families: _fontFamilies,
          current: _currentFont,
          onPick: (fam) {
            _changeFont(fam);
          },
        );
      case EditPanelMode.color:
        return ColorPaletteList(
          colors: const [
            // 기본 머티리얼 + 파스텔/인스타 감성 컬러 확장
            Colors.white, Colors.grey, Colors.black, Colors.red, Colors.pink, Colors.purple,
            Colors.deepPurple, Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan,
            Colors.teal, Colors.green, Colors.lightGreen, Colors.lime, Colors.yellow,
            Colors.amber, Colors.orange, Colors.deepOrange, Colors.brown, Colors.blueGrey,
            Color(0xFFFF5722), Color(0xFFE91E63), Color(0xFF9C27B0),
            Color(0xFF3F51B5), Color(0xFF03A9F4), Color(0xFF00BCD4),
            Color(0xFF4CAF50), Color(0xFFFFEB3B), Color(0xFFFF9800),
            Color(0xFF795548), Color(0xFF607D8B), Color(0xFFB2FF59),
            Color(0xFFFF8A80), Color(0xFFEA80FC), Color(0xFF8C9EFF),
            Color(0xFF80D8FF), Color(0xFF84FFFF), Color(0xFFA7FFEB),
            Color(0xFFCCFF90), Color(0xFFFFFF8D), Color(0xFFFFE57F),
            Color(0xFFD7CCC8), Color(0xFFBCAAA4),
            // 파스텔/네온 추가
            Color(0xFFFFC1CC), Color(0xFFB5EAEA), Color(0xFFEDF6E5), Color(0xFFFCECDD),
            Color(0xFFF9F3DF), Color(0xFFFFABAB), Color(0xFFB5FFD9), Color(0xFFC3FBD8),
            Color(0xFFDEFCFC), Color(0xFFFFD6E8), Color(0xFFCAFFD0), Color(0xFFE3EFFF),
            Color(0xFFFFF3B0), Color(0xFFFFD4A1), Color(0xFFA9DAFF), Color(0xFFE0BBE4),
            Color(0xFF957DAD), Color(0xFFD291BC),
          ],
          current: _style.color ?? Colors.white,
          onPick: (color) {
            _changeTextColor(color);
          },
        );
      case EditPanelMode.none:
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildToolButtons() {
    IconData alignIcon() {
      switch (_align) {
        case TextAlign.left:
          return Icons.format_align_left;
        case TextAlign.center:
          return Icons.format_align_center;
        case TextAlign.right:
          return Icons.format_align_right;
        default:
          return Icons.format_align_center;
      }
    }
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.black.withOpacity(0.28),
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: SizedBox(
          height: 48.h,
          child: ScrollConfiguration(
            behavior: const NoGlow(),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ToolButton(
                    label: Icons.text_fields,
                    selected: _panelMode == EditPanelMode.font,
                    onTap: () => _togglePanel(EditPanelMode.font),
                  ),
                  SizedBox(width: 12.w),
                  ToolButton(
                    label: Icons.color_lens,
                    selected: _panelMode == EditPanelMode.color,
                    onTap: () => _togglePanel(EditPanelMode.color),
                  ),
                  SizedBox(width: 12.w),
                  ToolButton(
                    label: alignIcon(),
                    selected: false,
                    onTap: () => _togglePanel(EditPanelMode.align),
                  ),
                  SizedBox(width: 12.w),
                  ToolButton(
                    label: Icons.auto_awesome, // sparkle icon
                    selected: _textStyleType != TextStyleType.none,
                    onTap: () => _toggleBackground(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets; // 키보드 높이
    final keyboardVisible = viewInsets.bottom > 0;
    return Stack(
      children: [
        /// 1) 뒤배경 Blur + Dim + 외부 탭 시 취소
        Positioned.fill(
          child: IgnorePointer(
            ignoring: false,
            child: GestureDetector(
              behavior: HitTestBehavior.deferToChild,
              onTap: () {
                // 배경을 눌렀을 때만 동작
                final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
                if (!isKeyboardOpen) _submit();
              },
            ),
          ),
        ),

        /// 2) 상단 바 (완료)
        SafeArea(
          bottom: false,
          child: TopBar(
            onCancel: widget.onCancel,
            onDone: _submit,
          ),
        ),

        /// 3) 중앙 에디터 (TextField)
        KeyboardVisibilityBuilder(
          builder: (context, isKeyboardVisible) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

                // 1) 원본 EditableText + 모드별 스타일링
                final baseTextColor = _style.color ?? Colors.white;
                // final bgColor = baseTextColor;

                // 외곽선(스트로크 모사)
                List<Shadow>? outlineShadows;
                if (_textStyleType == TextStyleType.textOuter) {
                  outlineShadows = _outline(_style.color ?? Colors.black);
                }

                // 모드별 텍스트 스타일
                TextStyle effectiveStyle = _style.copyWith(
                  fontSize: ((_style.fontSize ?? 20) * _fontScale).sp.clamp(18.sp, 80.sp),
                  fontFamily: _currentFont,
                  // shadows only for textOuter or textInner, set below
                  shadows: outlineShadows,
                );

                if (_textStyleType == TextStyleType.textInner) {
                  effectiveStyle = effectiveStyle.copyWith(
                    color: _style.color,
                    backgroundColor: null,
                    shadows: _innerOutline(
                      (_style.color ?? Colors.black).computeLuminance() > 0.5 ? Colors.black : Colors.white,
                    ),
                  );
                }
                else if (_textStyleType == TextStyleType.textOuter) {
                  effectiveStyle = effectiveStyle.copyWith(
                    color: _style.color,
                    backgroundColor: null,
                    shadows: _outline(
                      (_style.color ?? Colors.black).computeLuminance() > 0.5 ? Colors.black : Colors.white,
                    ),
                  );
                }
                else {
                  effectiveStyle = effectiveStyle.copyWith(
                    color: _style.color,
                    backgroundColor: null,
                  );
                }
                Widget boxedEditable;
                boxedEditable = Align(
                  alignment: Alignment.center,
                  child: IntrinsicWidth(
                    child: IntrinsicHeight(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          key: repaintKey,
                          painter: null,
                          child: EditableText(
                            key: _editableKey,
                            controller: _controller,
                            focusNode: _focus,
                            autofocus: true,
                            maxLines: null,
                            textAlign: _align,
                            keyboardType: TextInputType.multiline,
                            style: effectiveStyle,
                            cursorColor: Colors.white,
                            backgroundCursorColor: Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                  ),
                );

                return Stack(
                  children: [
                    Align(
                      alignment: const Alignment(0, -0.55), // 화면 중앙보다 위로 고정
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top + 20, // SafeArea + offset
                          bottom: MediaQuery.of(context).viewInsets.bottom + 20, // 키보드 대응
                          left: 24.w,
                          right: 24.w,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: 0.8 * constraints.maxWidth, // 화면 폭 대비 80%
                            minHeight: 60.h,
                            maxHeight: 200.h,
                          ),
                          child: SingleChildScrollView(
                            child: boxedEditable,
                          ),
                        ),
                      ),
                    ),

                    /// Bottom Panel (always above keyboard)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_panelMode != EditPanelMode.none)
                              Container(
                                margin: EdgeInsets.only(bottom: 8.h),
                                decoration: const BoxDecoration(
                                  borderRadius: BorderRadius.vertical(),
                                ),
                                child: _buildOptionList(),
                              ),
                            _buildToolButtons(),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),

        /// 4) 좌측 폰트 크기 슬라이더 (키보드 표시 시에만)
        if (keyboardVisible)
          Positioned(
            left: 8.w,
            top: 0.h,
            bottom: viewInsets.bottom + 0.25 * MediaQuery.of(context).size.height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SafeArea(
                  child: Material(
                    type: MaterialType.transparency,
                    child: RotatedBox(
                      quarterTurns: 0,
                      child: TriangleSlider(
                        min: 10.0,        // 최소 글자 크기
                        max: 80.0,        // 최대 글자 크기
                        value: _style.fontSize ?? 20.0,
                        onChanged: (val) {
                          setState(() {
                            _style = _style.copyWith(
                              fontSize: val.sp,
                            );
                          });
                        },
                        height: 250.h,
                        trackColor: Colors.white,
                        triangleColor: Colors.white,
                        thumbColor: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
