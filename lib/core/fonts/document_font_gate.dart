import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'document_fonts.dart';

/// Mount a document screen's original State only after its fonts are ready.
/// This protects measurements and draft/template work performed in initState,
/// and keeps Riverpod listeners inside their original Consumer build boundary.
class DocumentFontEntryState<T extends ConsumerStatefulWidget>
    extends ConsumerState<T> {
  DocumentFontEntryState(this.readyScreen);
  final Widget Function(T widget) readyScreen;

  @override
  Widget build(BuildContext context) =>
      DocumentFontGate(fullScreen: true, builder: (_) => readyScreen(widget));
}

/// Defers mounting and measuring artwork until its original fonts are ready.
/// The builder is deliberately lazy: constructing a child in the caller could
/// already cache text dimensions measured with a fallback font.
class DocumentFontGate extends StatefulWidget {
  const DocumentFontGate({
    super.key,
    required this.builder,
    this.families,
    this.placeholder,
    this.fullScreen = false,
  });

  /// Null prepares the complete set for editing/template document generation.
  final Iterable<String>? families;
  final WidgetBuilder builder;
  final Widget? placeholder;
  final bool fullScreen;

  @override
  State<DocumentFontGate> createState() => _DocumentFontGateState();
}

class _DocumentFontGateState extends State<DocumentFontGate> {
  Future<void>? _future;
  String? _key;

  bool get _ready => widget.families == null
      ? DocumentFonts.allReady
      : DocumentFonts.areReady(widget.families!);

  void _prepare() {
    final names = widget.families?.toSet().toList();
    names?.sort();
    final key = names?.join('\u0000') ?? '*';
    if (_key == key && _future != null) return;
    _key = key;
    _future = names == null
        ? DocumentFonts.ensureAll()
        : DocumentFonts.ensure(names);
  }

  Widget _waiting({bool failed = false}) {
    final content = failed
        ? TextButton(
            onPressed: () => setState(() {
              _future = null;
              _prepare();
            }),
            child: const Text('글꼴 다시 불러오기'),
          )
        : widget.placeholder ??
              (widget.fullScreen
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('앨범의 글꼴을 준비하고 있어요.'),
                        ],
                      ),
                    )
                  : const SizedBox.shrink());
    return widget.fullScreen
        ? Scaffold(
            appBar: AppBar(),
            body: SafeArea(child: Center(child: content)),
          )
        : content;
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.builder(context);
    _prepare();
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) =>
          snapshot.connectionState == ConnectionState.done
          ? snapshot.hasError
                ? _waiting(failed: true)
                : widget.builder(context)
          : _waiting(),
    );
  }
}
