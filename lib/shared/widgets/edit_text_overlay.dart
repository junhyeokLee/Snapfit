import 'dart:core';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../web/web_design.dart';
import 'dart:math' as math;
import '../../core/constants/snapfit_colors.dart';
import '../../features/album/domain/entities/layer.dart';
import '../../features/album/presentation/widgets/editor/tool_button.dart';
import 'color_palette_list.dart';
import 'font_picker_list.dart';
import 'experience_form_style.dart';
import 'no_glow.dart';
import 'studio_phrase_picker.dart';

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
  final void Function(
    String newText,
    TextStyle newStyle,
    TextStyleType textStyleType,
    Color? bubbleColor,
    TextAlign align,
  )
  onSubmit;
  final VoidCallback onCancel;
  final TextStyleType? initialMode;
  final Color? initialBubbleColor;
  final TextAlign initialAlign;

  const EditTextOverlay({
    super.key,
    required this.initialText,
    required this.initialStyle,
    required this.onSubmit,
    required this.onCancel,
    this.initialMode,
    this.initialBubbleColor,
    this.initialAlign = TextAlign.center,
  });

  @override
  State<EditTextOverlay> createState() => _EditTextOverlayState();
}

class _EditTextOverlayState extends State<EditTextOverlay> {
  // ScrollControllers for font and color pickers
  final ScrollController _fontScroll = ScrollController();
  final ScrollController _colorScroll = ScrollController();
  bool _choosingPhrase = false;
  bool _finishing = false;
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
  // 인쇄용으로 많이 쓰는 기본 서체들을 앞쪽에 배치
  final List<String> _fontFamilies = const [
    // 인쇄/본문용 기본 세트
    'NotoSans', // 기본 고딕 본문
    'Eulyoo', // 명조/에세이 느낌 본문
    'SeoulNamsan', // 모던 고딕 본문
    'Book', // 책 느낌 타이틀/본문
    'BookMyungjo', // 책 명조 스타일
    'Cormorant Garamond', // 영문 타이틀/본문
    'Figma Hand', // 손글씨 느낌 보조 카피
    'NanumPen',
    'Roboto',
    'Raleway',
    'Poppins',

    // 나머지 감성/장식 서체들
    'Doldam',
    'Maker',
    'Arita',
    'Peace',
    'RiaSans',
    'Aggravo',
    'Tenada',
    'Arirang',
    'Arirang2',
    'Arirang3',
    'Yeongwol',
    'Samlip',
    'Run',
    'Recipekorea',
  ];
  late String _currentFont;

  // 편집 패널 모드
  EditPanelMode _panelMode = EditPanelMode.font;

  final GlobalKey repaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focus = FocusNode();

    _align = widget.initialAlign;

    _style = widget.initialStyle;
    _currentFont = widget.initialStyle.fontFamily ?? _fontFamilies.first;

    _textStyleType = widget.initialMode ?? TextStyleType.none;
    _bubbleColor = widget.initialBubbleColor;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      // Scroll font list to current font
      final idx = _fontFamilies.indexOf(_currentFont);
      if (idx >= 0 && _fontScroll.hasClients) {
        _fontScroll.jumpTo(
          (idx * (kIsWeb ? 64.0 : 200.0)).clamp(0, _fontScroll.position.maxScrollExtent),
        );
      }
      // Scroll color list to current color
      // ColorPaletteList colors (must match below)
      final List<Color> colorList = const [
        Colors.white,
        Colors.grey,
        Colors.black,
        Colors.red,
        Colors.pink,
        Colors.purple,
        Colors.deepPurple,
        Colors.indigo,
        Colors.blue,
        Colors.lightBlue,
        Colors.cyan,
        Colors.teal,
        Colors.green,
        Colors.lightGreen,
        Colors.lime,
        Colors.yellow,
        Colors.amber,
        Colors.orange,
        Colors.deepOrange,
        Colors.brown,
        Colors.blueGrey,
        Color(0xFFFF5722),
        Color(0xFFE91E63),
        Color(0xFF9C27B0),
        Color(0xFF3F51B5),
        Color(0xFF03A9F4),
        Color(0xFF00BCD4),
        Color(0xFF4CAF50),
        Color(0xFFFFEB3B),
        Color(0xFFFF9800),
        Color(0xFF795548),
        Color(0xFF607D8B),
        Color(0xFFB2FF59),
        Color(0xFFFF8A80),
        Color(0xFFEA80FC),
        Color(0xFF8C9EFF),
        Color(0xFF80D8FF),
        Color(0xFF84FFFF),
        Color(0xFFA7FFEB),
        Color(0xFFCCFF90),
        Color(0xFFFFFF8D),
        Color(0xFFFFE57F),
        Color(0xFFD7CCC8),
        Color(0xFFBCAAA4),
        Color(0xFFFFC1CC),
        Color(0xFFB5EAEA),
        Color(0xFFEDF6E5),
        Color(0xFFFCECDD),
        Color(0xFFF9F3DF),
        Color(0xFFFFABAB),
        Color(0xFFB5FFD9),
        Color(0xFFC3FBD8),
        Color(0xFFDEFCFC),
        Color(0xFFFFD6E8),
        Color(0xFFCAFFD0),
        Color(0xFFE3EFFF),
        Color(0xFFFFF3B0),
        Color(0xFFFFD4A1),
        Color(0xFFA9DAFF),
        Color(0xFFE0BBE4),
        Color(0xFF957DAD),
        Color(0xFFD291BC),
      ];
      final color = _style.color ?? Colors.white;
      final cidx = colorList.indexWhere(
        (c) => c.toARGB32() == color.toARGB32(),
      );
      if (cidx >= 0 && _colorScroll.hasClients) {
        _colorScroll.jumpTo(
          (cidx * 50.0).clamp(0, _colorScroll.position.maxScrollExtent),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _fontScroll.dispose();
    _colorScroll.dispose();
    super.dispose();
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

  Future<void> _choosePhrase() async {
    if (!mounted || _choosingPhrase || _finishing) return;
    _choosingPhrase = true;
    _focus.unfocus();
    final phrase = await StudioPhrasePicker.show(context);
    if (!mounted) return;
    _choosingPhrase = false;
    if (phrase != null) {
      setState(() {
        _controller.value = TextEditingValue(
          text: phrase.text,
          selection: TextSelection.collapsed(offset: phrase.text.length),
        );
        _style = phrase.lettering.style;
        _currentFont = phrase.lettering.font;
        _align = phrase.alignment;
        _textStyleType = TextStyleType.none;
        _bubbleColor = null;
      });
    }
    _focus.requestFocus();
  }

  void _submit() {
    if (!_canFinish) return;
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _cancel();
      return;
    }
    final newStyle = _style.copyWith(
      fontFamily: _currentFont,
      fontSize: _style.fontSize,
      color: _style.color,
      shadows: () {
        if (_textStyleType == TextStyleType.textOuter) {
          final base = _style.color ?? Colors.black;
          final contrast = (base.computeLuminance() > 0.5)
              ? Colors.black
              : Colors.white;
          return _outline(contrast);
        } else if (_textStyleType == TextStyleType.textInner) {
          final base = _style.color ?? Colors.white;
          final contrast = (base.computeLuminance() > 0.5)
              ? Colors.black
              : Colors.white;
          return _innerOutline(contrast);
        }
        return null;
      }(),
    );

    setState(() => _finishing = true);
    widget.onSubmit(text, newStyle, _textStyleType, _bubbleColor, _align);
  }

  bool get _canFinish =>
      mounted &&
      !_finishing &&
      !_choosingPhrase &&
      ModalRoute.of(context)?.isCurrent != false;

  void _cancel() {
    if (!_canFinish) return;
    setState(() => _finishing = true);
    widget.onCancel();
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
      final opening = _panelMode != mode || _focus.hasFocus;
      setState(() {
        _panelMode = opening ? mode : EditPanelMode.none;
      });
      if (opening) {
        _focus.unfocus();
      } else {
        _focus.requestFocus();
      }
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
  List<Shadow> _outline(Color oc) =>
      const [
            Shadow(offset: Offset(0, 0), blurRadius: 0),
            Shadow(offset: Offset(1, 0), blurRadius: 0),
            Shadow(offset: Offset(-1, 0), blurRadius: 0),
            Shadow(offset: Offset(0, 1), blurRadius: 0),
            Shadow(offset: Offset(0, -1), blurRadius: 0),
            Shadow(offset: Offset(1, 1), blurRadius: 0),
            Shadow(offset: Offset(1, -1), blurRadius: 0),
            Shadow(offset: Offset(-1, 1), blurRadius: 0),
            Shadow(offset: Offset(-1, -1), blurRadius: 0),
          ]
          .map(
            (s) =>
                Shadow(offset: s.offset, blurRadius: s.blurRadius, color: oc),
          )
          .toList();

  // 내부 인버스 스트로크 (offset 반전, 더 미묘한 내부 효과, 대비색 사용)
  List<Shadow> _innerOutline(Color ic) {
    Color base = ic;
    Color contrastColor = (base.computeLuminance() > 0.5)
        ? Colors.black
        : Colors.white;
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
        ]
        .map(
          (s) => Shadow(
            offset: s.offset,
            blurRadius: s.blurRadius,
            color: contrastColor,
          ),
        )
        .toList();
  }

  Widget _buildOptionList() {
    switch (_panelMode) {
      case EditPanelMode.font:
        return FontPickerList(
          families: _fontFamilies,
          current: _currentFont,
          controller: _fontScroll,
          onPick: (fam) {
            _changeFont(fam);
          },
        );
      case EditPanelMode.color:
        return ColorPaletteList(
          colors: const [
            // 기본 머티리얼 + 파스텔/인스타 감성 컬러 확장
            Colors.white,
            Colors.grey,
            Colors.black,
            Colors.red,
            Colors.pink,
            Colors.purple,
            Colors.deepPurple,
            Colors.indigo,
            Colors.blue,
            Colors.lightBlue,
            Colors.cyan,
            Colors.teal,
            Colors.green,
            Colors.lightGreen,
            Colors.lime,
            Colors.yellow,
            Colors.amber,
            Colors.orange,
            Colors.deepOrange,
            Colors.brown,
            Colors.blueGrey,
            Color(0xFFFF5722), Color(0xFFE91E63), Color(0xFF9C27B0),
            Color(0xFF3F51B5), Color(0xFF03A9F4), Color(0xFF00BCD4),
            Color(0xFF4CAF50), Color(0xFFFFEB3B), Color(0xFFFF9800),
            Color(0xFF795548), Color(0xFF607D8B), Color(0xFFB2FF59),
            Color(0xFFFF8A80), Color(0xFFEA80FC), Color(0xFF8C9EFF),
            Color(0xFF80D8FF), Color(0xFF84FFFF), Color(0xFFA7FFEB),
            Color(0xFFCCFF90), Color(0xFFFFFF8D), Color(0xFFFFE57F),
            Color(0xFFD7CCC8), Color(0xFFBCAAA4),
            // 파스텔/네온 추가
            Color(0xFFFFC1CC),
            Color(0xFFB5EAEA),
            Color(0xFFEDF6E5),
            Color(0xFFFCECDD),
            Color(0xFFF9F3DF),
            Color(0xFFFFABAB),
            Color(0xFFB5FFD9),
            Color(0xFFC3FBD8),
            Color(0xFFDEFCFC),
            Color(0xFFFFD6E8),
            Color(0xFFCAFFD0),
            Color(0xFFE3EFFF),
            Color(0xFFFFF3B0),
            Color(0xFFFFD4A1),
            Color(0xFFA9DAFF),
            Color(0xFFE0BBE4),
            Color(0xFF957DAD), Color(0xFFD291BC),
          ],
          current: _style.color ?? Colors.white,
          controller: _colorScroll,
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

    return Container(
      color: const Color(0xFF252A2B),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        height: 48,
        child: ScrollConfiguration(
          behavior: const NoGlow(),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: '문구',
                  child: ToolButton(
                    key: const ValueKey('studio-phrase-tool'),
                    label: Icons.format_quote_rounded,
                    selected: false,
                    onTap: _choosePhrase,
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: '폰트와 글자 크기',
                  child: ToolButton(
                    key: const ValueKey('text-edit-font-tool'),
                    label: Icons.text_fields,
                    selected: _panelMode == EditPanelMode.font,
                    onTap: () => _togglePanel(EditPanelMode.font),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: '글자 색',
                  child: ToolButton(
                    key: const ValueKey('text-edit-color-tool'),
                    label: Icons.color_lens,
                    selected: _panelMode == EditPanelMode.color,
                    onTap: () => _togglePanel(EditPanelMode.color),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: '문구 정렬',
                  child: ToolButton(
                    key: const ValueKey('text-edit-align-tool'),
                    label: alignIcon(),
                    selected: false,
                    onTap: () => _togglePanel(EditPanelMode.align),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: '글자 윤곽선',
                  child: ToolButton(
                    key: const ValueKey('text-edit-outline-tool'),
                    label: Icons.auto_awesome,
                    selected: _textStyleType != TextStyleType.none,
                    onTap: () => _toggleBackground(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return _webEditor();
    final media = MediaQuery.of(context);
    final scaffold = Scaffold.maybeOf(context);
    final resized =
        scaffold != null && scaffold.widget.resizeToAvoidBottomInset != false;
    return Padding(
      padding: EdgeInsets.only(bottom: resized ? 0 : media.viewInsets.bottom),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SizedBox(
            height: box.maxHeight * .96,
            child: Material(
              color: SnapFitColors.backgroundOf(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: AbsorbPointer(
                absorbing: _finishing,
                child: Column(
                  children: [
                    _header(),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, content) {
                          final wide =
                              content.maxWidth >= 540 &&
                              media.orientation == Orientation.landscape;
                          final options = _settings();
                          if (wide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: _editor()),
                                SizedBox(
                                  width: (content.maxWidth * .42).clamp(
                                    224,
                                    300,
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: SingleChildScrollView(
                                          key: const PageStorageKey(
                                            'text-edit-settings',
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: options,
                                        ),
                                      ),
                                      _buildToolButtons(),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              Expanded(child: _editor()),
                              if (_panelMode != EditPanelMode.none &&
                                  (media.viewInsets.bottom == 0 ||
                                      content.maxHeight >= 340))
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: math.min(
                                      180,
                                      content.maxHeight * .45,
                                    ),
                                  ),
                                  child: SingleChildScrollView(
                                    key: const PageStorageKey(
                                      'text-edit-settings',
                                    ),
                                    child: options,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    if (!(box.maxWidth >= 540 &&
                        media.orientation == Orientation.landscape))
                      _buildToolButtons(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _webEditor() => Material(
    color: WebPalette.of(context).surface,
    child: AbsorbPointer(
      absorbing: _finishing,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('문구 편집', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: WebPalette.of(context).ink)),
              SizedBox(height: 5),
              Text('내용과 스타일을 확인한 뒤 적용하세요.', style: TextStyle(fontSize: 13, color: WebPalette.of(context).muted)),
            ])),
            OutlinedButton(key: const ValueKey('text-edit-cancel'), onPressed: _finishing ? null : _cancel, child: const Text('취소')),
            const SizedBox(width: 10),
            FilledButton(key: const ValueKey('text-edit-done'), onPressed: _finishing ? null : _submit, child: const Text('문구 적용')),
          ]),
        ),
        Divider(height: 1, color: WebPalette.of(context).line),
        Expanded(child: LayoutBuilder(builder: (context, bounds) {
          final settings = SingleChildScrollView(
            key: const PageStorageKey('text-edit-settings'),
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('글자 스타일', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ChoiceChip(key: const ValueKey('text-edit-font-tool'), selected: _panelMode == EditPanelMode.font, label: const Text('글꼴'), onSelected: (_) => _togglePanel(EditPanelMode.font)),
                ChoiceChip(key: const ValueKey('text-edit-color-tool'), selected: _panelMode == EditPanelMode.color, label: const Text('글자 색'), onSelected: (_) => _togglePanel(EditPanelMode.color)),
              ]),
              const SizedBox(height: 16),
              _settings(),
              const SizedBox(height: 20),
              Divider(color: WebPalette.of(context).line),
              const SizedBox(height: 14),
              TextButton.icon(key: const ValueKey('text-edit-align-tool'), onPressed: () => _togglePanel(EditPanelMode.align), icon: Icon(_align == TextAlign.left ? Icons.format_align_left : _align == TextAlign.right ? Icons.format_align_right : Icons.format_align_center, size: 18), label: Text(_align == TextAlign.left ? '왼쪽 정렬' : _align == TextAlign.right ? '오른쪽 정렬' : '가운데 정렬')),
              TextButton.icon(key: const ValueKey('text-edit-outline-tool'), onPressed: _toggleBackground, icon: const Icon(Icons.auto_awesome_outlined, size: 18), label: Text(_textStyleType == TextStyleType.none ? '글자 윤곽선 없음' : _textStyleType == TextStyleType.textOuter ? '바깥 윤곽선' : '안쪽 윤곽선')),
              const SizedBox(height: 16),
              OutlinedButton.icon(key: const ValueKey('studio-phrase-tool'), onPressed: _choosePhrase, icon: const Icon(Icons.format_quote_outlined, size: 18), label: const Text('문구 찾아보기')),
            ]),
          );
          final editor = Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('입력 · 미리보기', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: WebPalette.of(context).muted)),
              const SizedBox(height: 14),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: _editor())),
            ]),
          );
          if (bounds.maxWidth < 760) return Column(children: [Expanded(child: editor), SizedBox(height: 250, child: settings)]);
          return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: editor),
            VerticalDivider(width: 1, color: WebPalette.of(context).line),
            SizedBox(width: 340, child: settings),
          ]);
        })),
      ]),
    ),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
    child: Row(
      children: [
        IconButton(
          key: const ValueKey('text-edit-cancel'),
          tooltip: '문구 편집 취소',
          onPressed: _finishing ? null : _cancel,
          icon: const Icon(Icons.close, size: 20),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '문구 편집',
            style: ExperienceFormStyle.text(
              context,
              16,
              weight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          tooltip: '문구 입력',
          onPressed: () => _focus.requestFocus(),
          icon: const Icon(Icons.keyboard_outlined, size: 21),
        ),
        TextButton(
          key: const ValueKey('text-edit-done'),
          onPressed: _finishing ? null : _submit,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            textStyle: ExperienceFormStyle.text(
              context,
              14,
              weight: FontWeight.w600,
            ),
          ),
          child: const Text('완료'),
        ),
      ],
    ),
  );

  Widget _settings() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_panelMode != EditPanelMode.none) _buildOptionList(),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            IconButton(
              tooltip: '글자 작게',
              onPressed: () => setState(
                () => _style = _style.copyWith(
                  fontSize: ((_style.fontSize ?? 20) - 1).clamp(10, 80),
                ),
              ),
              icon: const Icon(Icons.text_decrease, size: 20),
            ),
            Expanded(
              child: Slider(
                key: const ValueKey('text-edit-size'),
                min: 10,
                max: 80,
                value: (_style.fontSize ?? 20).clamp(10, 80),
                label: '${(_style.fontSize ?? 20).round()}',
                onChanged: (value) =>
                    setState(() => _style = _style.copyWith(fontSize: value)),
              ),
            ),
            Text(
              '${(_style.fontSize ?? 20).round()}',
              style: ExperienceFormStyle.text(context, 12),
            ),
            IconButton(
              tooltip: '글자 크게',
              onPressed: () => setState(
                () => _style = _style.copyWith(
                  fontSize: ((_style.fontSize ?? 20) + 1).clamp(10, 80),
                ),
              ),
              icon: const Icon(Icons.text_increase, size: 20),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _editor() {
    final ink = _style.color ?? ExperienceFormStyle.ink(context);
    final previewBackground = ink.computeLuminance() > .4
        ? const Color(0xFF252A2B)
        : const Color(0xFFF3F6F5);
    final style = _style.copyWith(
      fontSize: (_style.fontSize ?? 20).clamp(10, 80),
      fontFamily: _currentFont,
      color: ink,
      backgroundColor: Colors.transparent,
      shadows: _textStyleType == TextStyleType.textOuter
          ? _outline(ink.computeLuminance() > .5 ? Colors.black : Colors.white)
          : _textStyleType == TextStyleType.textInner
          ? _innerOutline(
              ink.computeLuminance() > .5 ? Colors.black : Colors.white,
            )
          : null,
    );
    return LayoutBuilder(
      builder: (context, box) {
        final padding = box.maxHeight < 140 ? 4.0 : 12.0;
        return Padding(
          padding: EdgeInsets.all(padding),
          child: ColoredBox(
            key: const ValueKey('text-edit-preview'),
            color: previewBackground,
            child: RepaintBoundary(
              key: repaintKey,
              child: TextField(
                key: const ValueKey('text-edit-input'),
                controller: _controller,
                focusNode: _focus,
                maxLines: null,
                expands: true,
                textAlign: _align,
                textAlignVertical: TextAlignVertical.center,
                keyboardType: TextInputType.multiline,
                style: style,
                cursorColor: ink,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: padding,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
