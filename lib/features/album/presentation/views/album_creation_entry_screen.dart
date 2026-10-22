import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/album_creation_draft.dart';
import '../utils/album_creation_entry.dart';
import 'album_create_flow_screen.dart';

/// Keeps legacy named routes behind the same draft check as visible actions.
class AlbumCreationEntryScreen extends ConsumerStatefulWidget {
  const AlbumCreationEntryScreen({super.key});

  @override
  ConsumerState<AlbumCreationEntryScreen> createState() =>
      _AlbumCreationEntryScreenState();
}

class _AlbumCreationEntryScreenState
    extends ConsumerState<AlbumCreationEntryScreen> {
  bool _checking = true;
  bool _confirmed = false;
  AlbumCreationDraft? _draft;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (!mounted || _confirmed) return;
    if (!_checking) setState(() => _checking = true);
    final decision = await resolveAlbumCreationEntry(context, ref);
    if (!mounted) return;
    if (decision != null) {
      setState(() {
        _draft = decision.draft;
        _confirmed = true;
        _checking = false;
      });
      return;
    }
    if (ModalRoute.of(context)?.isCurrent == true &&
        Navigator.canPop(context)) {
      await Navigator.maybePop(context);
    }
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) => _confirmed
      ? AlbumCreateFlowScreen(initialDraft: _draft)
      : Scaffold(
          appBar: AppBar(title: const Text('앨범 만들기')),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_checking) ...[
                      const Icon(Icons.history_rounded, size: 32),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      _checking
                          ? '임시 저장한 앨범을 확인하고 있어요.'
                          : '저장한 앨범을 확인한 뒤 시작할 수 있어요.',
                      textAlign: TextAlign.center,
                    ),
                    if (!_checking) ...[
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _check,
                        child: const Text('다시 확인'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
}
