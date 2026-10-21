import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../core/constants/cover_size.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../shared/widgets/album_stage_style.dart';
import '../../../../../shared/web/web_design.dart';
import '../../../../store/presentation/widgets/template_book_artwork.dart';

bool creationKeyboardIsOpen(BuildContext context) =>
    MediaQuery.of(context).viewInsets.bottom > 0 ||
    View.of(context).viewInsets.bottom > 0;

/// Creation actions use the same primary control as settings and the store.
abstract final class CreationStyle {
  static ButtonStyle primary(BuildContext context) =>
      ExperienceFormStyle.primary(context);
}

/// Keep the same book and input subtrees as the workspace changes orientation.
class CreationWorkspace extends StatefulWidget {
  const CreationWorkspace({
    super.key,
    required this.stage,
    required this.fields,
    required this.actions,
    this.keyboardOpen = false,
    this.portraitStageHeight,
  });
  final Widget stage, fields, actions;
  final bool keyboardOpen;
  final double? portraitStageHeight;
  @override
  State<CreationWorkspace> createState() => _CreationWorkspaceState();
}

class _CreationWorkspaceState extends State<CreationWorkspace> {
  final _stageKey = GlobalKey(), _fieldsKey = GlobalKey();
  final _portraitScroll = ScrollController(),
      _fieldsScroll = ScrollController();
  Size? _extent;
  bool _queued = false;
  void _focusAfterLayout() {
    if (_queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
      final input = FocusManager.instance.primaryFocus?.context;
      final fields = _fieldsKey.currentContext;
      if (input == null || !input.mounted || fields == null) return;
      var belongsToFields = false;
      input.visitAncestorElements((ancestor) {
        if (identical(ancestor, fields)) {
          belongsToFields = true;
          return false;
        }
        return true;
      });
      final object = input.findRenderObject();
      final position = Scrollable.maybeOf(fields)?.position;
      // Resolve the current outer scroll after the focused input is reparented.
      if (belongsToFields &&
          object != null &&
          object.attached &&
          position != null &&
          position.hasContentDimensions) {
        position.ensureVisible(object, alignment: .25);
      }
    });
  }

  @override
  void didUpdateWidget(CreationWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keyboardOpen != widget.keyboardOpen) _focusAfterLayout();
  }

  @override
  void dispose() {
    _portraitScroll.dispose();
    _fieldsScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: LayoutBuilder(
      builder: (context, box) {
        final extent = Size(box.maxWidth, box.maxHeight);
        if (_extent != extent) {
          _extent = extent;
          _focusAfterLayout();
        }
        final wide =
            box.maxWidth >= 520 &&
            MediaQuery.orientationOf(context) == Orientation.landscape;
        final keyboardOpen =
            widget.keyboardOpen || creationKeyboardIsOpen(context);
        final inputOnly = keyboardOpen && wide && box.maxHeight < 180;
        final stage = KeyedSubtree(key: _stageKey, child: widget.stage);
        final fields = KeyedSubtree(key: _fieldsKey, child: widget.fields);
        if (kIsWeb) {
          return _webWorkspace(box, stage: stage, fields: fields);
        }
        final actions = DecoratedBox(
          decoration: BoxDecoration(
            color: AlbumStageStyle.bottom(context),
            border: Border(
              top: BorderSide(color: ExperienceFormStyle.line(context)),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: widget.actions,
          ),
        );
        if (wide) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Row(
                key: const ValueKey('creation-workspace-wide'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (inputOnly)
                    Offstage(
                      child: SizedBox(width: 240, height: 160, child: stage),
                    )
                  else
                    Expanded(
                      flex: 6,
                      child: KeyedSubtree(
                        key: const ValueKey('creation-workspace-preview'),
                        child: stage,
                      ),
                    ),
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _fieldsScroll,
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.fromLTRB(
                              20,
                              inputOnly ? 8 : 16,
                              20,
                              20,
                            ),
                            child: fields,
                          ),
                        ),
                        if (!inputOnly) actions,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: SingleChildScrollView(
                    controller: _portraitScroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: keyboardOpen
                              ? math.min(140, box.maxHeight * .35)
                              : widget.portraitStageHeight ??
                                    math.min(
                                      320,
                                      math.max(200, box.maxHeight * .46),
                                    ),
                          child: stage,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                          child: fields,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions,
          ],
        );
      },
    ),
  );

  Widget _webWorkspace(
    BoxConstraints bounds, {
    required Widget stage,
    required Widget fields,
  }) {
    final wide = bounds.maxWidth >= 840;
    final form = SingleChildScrollView(
      controller: wide ? _fieldsScroll : _portraitScroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!wide) ...[
            SizedBox(
              height: 260,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: stage,
              ),
            ),
            const SizedBox(height: 28),
          ],
          fields,
          const SizedBox(height: 28),
          Divider(color: WebPalette.of(context).line),
          const SizedBox(height: 20),
          widget.actions,
          const SizedBox(height: 12),
          Text(
            '선택한 규격과 현재 내용을 확인하는 미리보기입니다. 사진과 글은 편집 단계에서 배치할 수 있습니다.',
            style: TextStyle(
              fontSize: 12,
              height: 1.7,
              color: WebPalette.of(context).muted,
            ),
          ),
        ],
      ),
    );
    if (!wide) return form;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 6, child: form),
        VerticalDivider(width: 1, color: WebPalette.of(context).line),
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '앨범 미리보기',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: WebPalette.of(context).ink,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: stage,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class CreationPaperStage extends StatelessWidget {
  const CreationPaperStage({
    super.key,
    required this.child,
    this.title,
    this.detail,
    this.inset = 22,
  });
  final Widget child;
  final String? title, detail;
  final double inset;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: kIsWeb ? WebPalette.of(context).canvas : null,
      gradient: kIsWeb ? null : AlbumStageStyle.gradient(context),
    ),
    child: LayoutBuilder(
      builder: (context, box) {
        // Low landscape workspaces reserve their height for the actual book.
        final compact = box.maxHeight < 260;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!compact && title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Text(
                  title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ExperienceFormStyle.text(context, 12, secondary: true),
                ),
              ),
            Expanded(
              key: const ValueKey('creation-paper-content'),
              child: Padding(
                padding: EdgeInsets.all(compact ? math.min(10, inset) : inset),
                child: child,
              ),
            ),
            if (!compact && detail != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Text(
                  detail!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: ExperienceFormStyle.text(context, 12, secondary: true),
                ),
              ),
          ],
        );
      },
    ),
  );
}

/// This is an empty physical book, not a sample photograph or an AI result.
class CreationBlankBook extends StatelessWidget {
  const CreationBlankBook({
    super.key,
    required this.cover,
    this.title = '새 앨범',
    this.spread = false,
  });
  final CoverSize cover;
  final String title;
  final bool spread;
  @override
  Widget build(BuildContext context) => Center(
    child: AspectRatio(
      aspectRatio: cover.ratio * (spread ? 2 : 1),
      child: TemplateBookArtwork(
        canvas: coverCanvasBaseSize(cover),
        firstPage: spread ? 1 : 0,
        paired: spread,
        // Print artwork uses a fixed page coordinate system, not UI text scaling.
        pageBuilder: (index, wrap) => FittedBox(
          child: SizedBox(
            width: kCoverReferenceWidth,
            height: kCoverReferenceWidth / cover.ratio,
            child: ColoredBox(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(38),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    spread ? '$index' : title,
                    textScaler: TextScaler.noScaling,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: ExperienceFormStyle.text(
                      context,
                      32,
                      weight: FontWeight.w500,
                      color: const Color(0xFF253331),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
