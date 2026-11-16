import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/fonts/document_fonts.dart';
import '../../domain/monthly_album_builder.dart';
import '../providers/moments_providers.dart';

final monthlyMomentFontPreparationProvider = Provider<Future<void> Function()>(
  (ref) =>
      () => DocumentFonts.ensure(monthlyMomentFontFamilies),
);

/// Capture the owner before waiting for fonts. A sign-out or A → B → A change
/// cannot mount a previous account's record preview under the new session.
class MomentDocumentFontEntry extends ConsumerStatefulWidget {
  const MomentDocumentFontEntry({super.key, required this.builder});
  final WidgetBuilder builder;

  @override
  ConsumerState<MomentDocumentFontEntry> createState() =>
      _MomentDocumentFontEntryState();
}

class _MomentDocumentFontEntryState
    extends ConsumerState<MomentDocumentFontEntry> {
  late final String? _owner;
  late final StreamSubscription<String?> _authChanges;
  late Future<void> _preparation;
  bool _sessionChanged = false;

  @override
  void initState() {
    super.initState();
    final repository = ref.read(momentsRepositoryProvider);
    _owner = repository.currentUserId;
    _authChanges = repository.authChanges.listen((owner) {
      if (owner != _owner) _invalidateSession();
    }, onError: (Object _, StackTrace __) => _invalidateSession());
    _prepare();
  }

  void _prepare() {
    _preparation = Future<void>.sync(
      ref.read(monthlyMomentFontPreparationProvider),
    );
  }

  void _invalidateSession() {
    if (!mounted || _sessionChanged) return;
    setState(() => _sessionChanged = true);
  }

  bool get _current =>
      !_sessionChanged &&
      _owner != null &&
      ref.read(momentsRepositoryProvider).currentUserId == _owner;

  @override
  void dispose() {
    unawaited(_authChanges.cancel());
    super.dispose();
  }

  Widget _frame(Widget content) => Scaffold(
    appBar: AppBar(title: const Text('나의 기록')),
    body: SafeArea(child: Center(child: content)),
  );

  Widget _locked() => _frame(const Text('계정이 변경되었어요. 나의 기록으로 돌아가 다시 시작해 주세요.'));

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(momentsCurrentUserIdProvider);
    if (actor != _owner) _sessionChanged = true;
    if (!_current) return _locked();
    return FutureBuilder<void>(
      future: _preparation,
      builder: (context, snapshot) {
        if (!_current) return _locked();
        if (snapshot.connectionState == ConnectionState.done) {
          if (!snapshot.hasError) return widget.builder(context);
          return _frame(
            TextButton(
              onPressed: () => setState(_prepare),
              child: const Text('앨범 글꼴 다시 불러오기'),
            ),
          );
        }
        return _frame(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('앨범의 글꼴을 준비하고 있어요.'),
            ],
          ),
        );
      },
    );
  }
}

class MomentDocumentFontEntryState<T extends ConsumerStatefulWidget>
    extends ConsumerState<T> {
  MomentDocumentFontEntryState(this.readyScreen);
  final Widget Function(T widget) readyScreen;

  @override
  Widget build(BuildContext context) =>
      MomentDocumentFontEntry(builder: (_) => readyScreen(widget));
}
