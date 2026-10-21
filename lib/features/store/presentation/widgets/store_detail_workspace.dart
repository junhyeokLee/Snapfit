import 'package:flutter/material.dart';

import '../../../../shared/widgets/experience_form_style.dart';

/// Shopping previews keep their full height beside the purchase column.
class StoreDetailWorkspace extends StatefulWidget {
  const StoreDetailWorkspace({
    super.key,
    required this.stage,
    required this.fields,
    required this.actions,
    this.portraitStageHeight,
    this.freezeLayout = false,
  });

  final Widget stage, fields, actions;
  final double? portraitStageHeight;
  final bool freezeLayout;

  @override
  State<StoreDetailWorkspace> createState() => _StoreDetailWorkspaceState();
}

class _StoreDetailWorkspaceState extends State<StoreDetailWorkspace> {
  final _stageKey = GlobalKey(),
      _fieldsKey = GlobalKey(),
      _actionsKey = GlobalKey();
  final _portraitScroll = ScrollController(),
      _landscapeScroll = ScrollController();
  bool? _wideLayout;

  @override
  void dispose() {
    _portraitScroll.dispose();
    _landscapeScroll.dispose();
    super.dispose();
  }

  Widget _purchase(Widget actions, {required bool wide}) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: ExperienceFormStyle.line(context))),
    ),
    child: Padding(
      padding: EdgeInsets.fromLTRB(wide ? 16 : 20, 12, wide ? 16 : 20, 12),
      child: actions,
    ),
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: LayoutBuilder(
      builder: (context, bounds) {
        final requestedWide =
            bounds.maxWidth >= 560 &&
            MediaQuery.orientationOf(context) == Orientation.landscape;
        final wide = widget.freezeLayout
            ? _wideLayout ?? requestedWide
            : requestedWide;
        _wideLayout = wide;
        // Each moved section keeps its own semantics ancestor across layouts.
        final stage = Semantics(
          key: _stageKey,
          container: true,
          child: widget.stage,
        );
        final fields = Semantics(
          key: _fieldsKey,
          container: true,
          child: widget.fields,
        );
        final actions = Semantics(
          key: _actionsKey,
          container: true,
          child: widget.actions,
        );
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: wide
                ? Row(
                    key: const ValueKey('store-detail-workspace-landscape'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 7, child: stage),
                      VerticalDivider(
                        width: 1,
                        color: ExperienceFormStyle.line(context),
                      ),
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                controller: _landscapeScroll,
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  18,
                                  20,
                                  24,
                                ),
                                child: fields,
                              ),
                            ),
                            _purchase(actions, wide: true),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    key: const ValueKey('store-detail-workspace-portrait'),
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _portraitScroll,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height:
                                    widget.portraitStageHeight ??
                                    (MediaQuery.sizeOf(context).height * .53)
                                        .clamp(280.0, 460.0),
                                child: stage,
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  22,
                                  24,
                                  28,
                                ),
                                child: fields,
                              ),
                            ],
                          ),
                        ),
                      ),
                      _purchase(actions, wide: false),
                    ],
                  ),
          ),
        );
      },
    ),
  );
}
