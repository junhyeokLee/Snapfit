import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../web/web_design.dart';
import '../../core/constants/image_templates.dart';
import '../../core/constants/snapfit_colors.dart';
import 'experience_form_style.dart';

class ImageTemplatePicker extends StatefulWidget {
  final String? selectedKey;
  final ValueChanged<String> onSelect;

  const ImageTemplatePicker({
    super.key,
    required this.selectedKey,
    required this.onSelect,
  });

  static Future<String?> show(
    BuildContext context, {
    required String? currentKey,
  }) {
    FocusScope.of(context).unfocus();
    if (kIsWeb) {
      return showWebAwareDialog<String>(
        context: context,
        maxWidth: 840,
        maxHeight: 720,
        builder: (dialogContext) => ImageTemplatePicker(
          selectedKey: currentKey,
          onSelect: (key) => Navigator.pop(dialogContext, key),
        ),
      );
    }
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      backgroundColor: Colors.transparent,
      builder: (ctx) => ImageTemplatePicker(
        selectedKey: currentKey,
        onSelect: (key) => Navigator.pop(ctx, key),
      ),
    );
  }

  @override
  State<ImageTemplatePicker> createState() => _ImageTemplatePickerState();
}

class _ImageTemplatePickerState extends State<ImageTemplatePicker> {
  bool _finishing = false;

  void _finish([String? key]) {
    if (!mounted || _finishing || ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    _finishing = true;
    if (key == null) {
      Navigator.pop(context);
    } else {
      widget.onSelect(key);
      if (mounted && ModalRoute.of(context)?.isCurrent != false)
        _finishing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    const subtitles = {
      'free': '사진 비율 그대로',
      '1:1': '정사각형 앨범컷',
      '4:3': '일반 카메라 비율',
      '3:4': '세로형 인화 비율',
      '16:9': '와이드 스냅샷',
      '9:16': '스토리/릴스 비율',
      '3:2': '필름 카메라 느낌',
      '2:3': '클래식 인화 비율',
    };
    return LayoutBuilder(
      builder: (context, available) => Container(
        constraints: BoxConstraints(
          maxHeight: math.min(
            available.maxHeight,
            math.min(640, MediaQuery.sizeOf(context).height * .90),
          ),
        ),
        decoration: BoxDecoration(
          color: kIsWeb ? WebPalette.of(context).surface : SnapFitColors.backgroundOf(context),
          borderRadius: kIsWeb ? BorderRadius.circular(12) : const BorderRadius.vertical(top: Radius.circular(8)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '사진 크기',
                        style: ExperienceFormStyle.text(
                          context,
                          18,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('photo-ratio-close'),
                      tooltip: '닫기',
                      onPressed: () => _finish(),
                      icon: const Icon(Icons.close, size: 22),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: ExperienceFormStyle.line(context)),
              Flexible(
                child: LayoutBuilder(
                  builder: (context, bounds) => GridView.builder(
                    shrinkWrap: true,
                    key: const ValueKey('photo-ratio-list'),
                    padding: const EdgeInsets.all(20),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: math
                          .max(
                            1,
                            (bounds.maxWidth /
                                    (MediaQuery.textScalerOf(
                                              context,
                                            ).scale(14) >
                                            22
                                        ? 160
                                        : 145))
                                .floor(),
                          )
                          .clamp(1, 4),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent:
                          132 +
                          (MediaQuery.textScalerOf(context).scale(14) / 14 - 1)
                                  .clamp(0, 2) *
                              70,
                    ),
                    itemCount: imageTemplates.length,
                    itemBuilder: (context, index) {
                      final template = imageTemplates[index];
                      final selected =
                          (widget.selectedKey ?? 'free') == template.key;
                      final color = selected
                          ? ExperienceFormStyle.selectionInk(context)
                          : ExperienceFormStyle.muted(context);
                      final ratio = template.aspect ?? 4 / 3;
                      return Semantics(
                        key: ValueKey('photo-ratio-${template.key}'),
                        selected: selected,
                        button: true,
                        label: '${template.label} · ${subtitles[template.key]}',
                        child: Material(
                          color: selected
                              ? ExperienceFormStyle.selection(context)
                              : ExperienceFormStyle.surface(context),
                          borderRadius: BorderRadius.circular(kIsWeb ? 12 : 6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(kIsWeb ? 12 : 6),
                            onTap: () => _finish(template.key),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    height: 34,
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 42,
                                          height: 32,
                                          child: Center(
                                            child: Container(
                                              width: math.min(40, 30 * ratio),
                                              height: math.min(30, 40 / ratio),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: color,
                                                  width: 1.5,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        if (selected)
                                          Icon(
                                            Icons.check,
                                            size: 18,
                                            color: color,
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    template.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: ExperienceFormStyle.text(
                                      context,
                                      14,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    subtitles[template.key] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: ExperienceFormStyle.text(
                                      context,
                                      12,
                                      secondary: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
