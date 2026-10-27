import 'package:flutter/material.dart';

/// Paint the surrounding screen and its placeholder before mounting content.
/// This only splits initial mounting; expensive CPU work still belongs off the
/// UI isolate. Inactive destinations wait until they are actually shown.
class DeferredContent extends StatefulWidget {
  const DeferredContent({
    super.key,
    required this.builder,
    required this.placeholder,
    this.active = true,
  });

  final WidgetBuilder builder;
  final Widget placeholder;
  final bool active;

  @override
  State<DeferredContent> createState() => _DeferredContentState();
}

class _DeferredContentState extends State<DeferredContent> {
  bool _ready = false;
  bool _scheduled = false;
  Widget? _content;

  @override
  void initState() {
    super.initState();
    _scheduleMount();
  }

  @override
  void didUpdateWidget(DeferredContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleMount();
  }

  void _scheduleMount() {
    if (_ready || _scheduled || !widget.active) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted && widget.active && !_ready) {
        setState(() => _ready = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_ready && widget.active && TickerMode.of(context)) {
      _content = widget.builder(context);
    }
    return _content ?? widget.placeholder;
  }
}

/// Keep a visited destination mounted without reconstructing its widget tree
/// when another root tab updates. Tickers stop while that destination is hidden.
class RetainedDestination extends StatefulWidget {
  const RetainedDestination({
    super.key,
    required this.active,
    required this.builder,
  });

  final bool active;
  final WidgetBuilder builder;

  @override
  State<RetainedDestination> createState() => _RetainedDestinationState();
}

class _RetainedDestinationState extends State<RetainedDestination> {
  Widget? _child;

  @override
  Widget build(BuildContext context) {
    final active = widget.active && TickerMode.of(context);
    if (active) _child = widget.builder(context);
    return Offstage(
      offstage: !active,
      child: ExcludeFocus(
        excluding: !active,
        child: HeroMode(
          enabled: active,
          child: TickerMode(
            enabled: active,
            child: _child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
