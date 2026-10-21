import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/cover_size.dart';
import '../../../../core/navigation/web_app_location.dart';
import '../../../profile/data/order_repository.dart';
import '../../../profile/domain/order_visibility_owner.dart';
import '../../../profile/domain/print_checkout.dart';
import '../../data/api/album_provider.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/layer.dart';
import '../../domain/repositories/album_repository.dart';
import '../../printing/print_album_document.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../viewmodels/cover_view_model.dart';
import '../viewmodels/home_view_model.dart';
import '../views/page_editor_screen.dart';
import 'print_photo_issue.dart';

class PrintPhotoEditUnavailable implements Exception {
  const PrintPhotoEditUnavailable(this.message);
  final String message;
}

/// Keeps a correction tied to the reviewed document and the current account.
/// The same path is used by reader, library, order-history and direct links.
class PrintPhotoEditSession {
  PrintPhotoEditSession({
    required this.repository,
    required this.fetchSnapshot,
    required this.currentOwner,
    required this.isActive,
    required this.hasUnsavedChanges,
  });

  final AlbumRepository repository;
  final Future<Map<String, dynamic>> Function(int) fetchSnapshot;
  final String? Function() currentOwner;
  final bool Function() isActive;
  final bool Function() hasUnsavedChanges;

  Future<bool> run(
    int albumId,
    PrintPhotoEditTarget target, {
    required Future<bool> Function(Album, Map<String, dynamic>) edit,
  }) async {
    final owner = currentOwner();
    if (owner == null || owner.isEmpty || albumId <= 0) {
      throw const PrintPhotoEditUnavailable('로그인 상태를 확인한 뒤 다시 시도해 주세요.');
    }
    void ensureCurrent() {
      if (!isActive() || currentOwner() != owner) {
        throw const PrintPhotoEditUnavailable('로그인 상태가 바뀌었어요. 다시 앨범을 열어 주세요.');
      }
    }

    void checkAlbum(Album album) {
      if (album.id != albumId ||
          !album.allowsEditing ||
          (album.memberRole == null && album.userId != owner)) {
        throw const PrintPhotoEditUnavailable('이 앨범의 사진 수정 권한을 확인할 수 없어요.');
      }
      final lockedBy = album.lockedById;
      if (lockedBy != null && lockedBy.isNotEmpty && lockedBy != owner) {
        throw const PrintPhotoEditUnavailable(
          '앨범이 다른 사용자에게 잠겨 있어요. 잠시 후 다시 시도해 주세요.',
        );
      }
    }

    void checkSnapshot(Map<String, dynamic> snapshot) {
      final row = snapshot['album'];
      if (row is! Map ||
          row['id'] != albumId ||
          printCheckoutRevision(snapshot) != target.reviewedRevision ||
          !printPhotoTargetMatchesDocument(
            target,
            PrintAlbumDocument.fromSnapshot(snapshot),
          )) {
        throw const PrintPhotoEditUnavailable(
          '앨범 내용이 바뀌었어요. 새 인쇄 검토에서 사진을 다시 선택해 주세요.',
        );
      }
    }

    void checkUnsaved() {
      if (hasUnsavedChanges()) {
        throw const PrintPhotoEditUnavailable(
          '저장하지 않은 편집이 있어요. 먼저 저장하거나 편집을 마쳐 주세요.',
        );
      }
    }

    ensureCurrent();
    checkUnsaved();
    var album = await repository.fetchAlbum('$albumId');
    ensureCurrent();
    checkAlbum(album);
    var snapshot = await fetchSnapshot(albumId);
    ensureCurrent();
    checkSnapshot(snapshot);
    var acquired = false;
    try {
      // A reader can already hold this account's lock. Do not release that
      // outer route's lock when this nested correction finishes.
      if (album.lockedById != owner) {
        await repository.lockAlbum(albumId);
        acquired = true;
        ensureCurrent();
        album = await repository.fetchAlbum('$albumId');
        ensureCurrent();
        checkAlbum(album);
        if (album.lockedById != owner) {
          throw const PrintPhotoEditUnavailable(
            '앨범 편집 준비를 확인하지 못했어요. 잠시 후 다시 시도해 주세요.',
          );
        }
        snapshot = await fetchSnapshot(albumId);
        ensureCurrent();
        checkSnapshot(snapshot);
      }
      checkUnsaved();
      final result = await edit(album, snapshot);
      ensureCurrent();
      return result;
    } finally {
      if (acquired && currentOwner() == owner) {
        try {
          await repository.unlockAlbum(albumId);
        } catch (_) {
          debugPrint('Print photo correction: could not release album lock.');
        }
      }
    }
  }
}

/// The editor needs a single page document. Older print snapshots have a
/// separate cover and page rows; combine the raw rows without remapping layers.
/// This changes only the in-memory editing input, never the reviewed snapshot.
Album printPhotoEditableAlbum(Album album, Map<String, dynamic> snapshot) {
  final row = Map<String, dynamic>.from(snapshot['album'] as Map);
  dynamic decode(dynamic value) => value is String ? jsonDecode(value) : value;
  final full = Map<String, dynamic>.from(
    decode(row['cover_layers_json']) as Map,
  );
  if (full['pages'] is! List) {
    final rows =
        ((snapshot['pages'] as List?) ?? const [])
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList()
          ..sort(
            (a, b) => ((a['page_number'] ?? a['page_index']) as num).compareTo(
              (b['page_number'] ?? b['page_index']) as num,
            ),
          );
    full['pages'] = [
      {...full, 'index': 0, 'isCover': true},
      for (final entry in rows.indexed)
        {
          ...Map<String, dynamic>.from(decode(entry.$2['layers_json']) as Map),
          'index': entry.$1 + 1,
          'isCover': false,
        },
    ];
  }
  return album.copyWith(
    title: row['title'] as String? ?? album.title,
    ratio: '${row['ratio']}',
    coverTheme: row['cover_theme'] as String? ?? album.coverTheme,
    coverLayersJson: jsonEncode(full),
  );
}

Future<bool> openPrintPhotoEditor(
  BuildContext context,
  WidgetRef ref, {
  required int albumId,
  required PrintPhotoEditTarget target,
}) async {
  // A lock request may finish after the review route has been popped. Keep the
  // account check independent of that route's disposed WidgetRef for cleanup.
  final container = ProviderScope.containerOf(context, listen: false);
  String? owner() {
    try {
      return container.read(visibleOrderOwnerProvider);
    } catch (_) {
      return null;
    }
  }

  final startingOwner = owner();
  bool active() => context.mounted && owner() == startingOwner;
  try {
    final repository = ref.read(albumRepositoryProvider);
    final orders = ref.read(orderRepositoryProvider);
    final session = PrintPhotoEditSession(
      repository: repository,
      fetchSnapshot: (id) => orders.fetchPrintPreviewSnapshot(albumId: id),
      currentOwner: owner,
      isActive: () => context.mounted,
      hasUnsavedChanges: () =>
          ref.read(albumEditorViewModelProvider.notifier).hasUnsavedChanges,
    );
    return await session.run(
      albumId,
      target,
      edit: (album, snapshot) async {
        if (!active()) return false;
        final saved = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            settings: WebAppRouteSettings(
              WebAppLocation(WebAppPage.editor, '$albumId'),
            ),
            builder: (_) => PrintPhotoCorrectionEditor(
              album: printPhotoEditableAlbum(album, snapshot),
              target: target,
              expectedOwner: startingOwner!,
            ),
          ),
        );
        if (active()) {
          ref.invalidate(homeViewModelProvider);
          final parentVm = ref.read(albumEditorViewModelProvider.notifier);
          // Refresh a reader of this same album after saving. A reader of a
          // different album keeps its own model, cover and navigation state.
          if (saved == true &&
              parentVm.editingAlbumId == albumId &&
              !parentVm.hasUnsavedChanges) {
            try {
              final updated = await repository.fetchAlbum('$albumId');
              if (active() &&
                  parentVm.editingAlbumId == albumId &&
                  !parentVm.hasUnsavedChanges) {
                final page = parentVm.currentPageIndex;
                await parentVm.prepareAlbumForEdit(updated);
                if (active()) {
                  parentVm.loadPendingEditAlbumIfNeeded(
                    Size(
                      kCoverReferenceWidth,
                      kCoverReferenceWidth / parentVm.selectedCover.ratio,
                    ),
                  );
                  parentVm.goToPage(page.clamp(0, parentVm.pages.length - 1));
                }
              }
            } catch (_) {
              debugPrint('Print photo correction: reader refresh deferred.');
            }
          }
        }
        return saved == true;
      },
    );
  } on PrintPhotoEditUnavailable catch (error) {
    if (active())
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
  } catch (_) {
    if (active())
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 수정할 화면을 열지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
  }
  return false;
}

/// Correction owns its editing models so another album behind the print route
/// cannot be replaced by the document being corrected.
class PrintPhotoCorrectionEditor extends StatelessWidget {
  const PrintPhotoCorrectionEditor({
    super.key,
    required this.album,
    required this.target,
    required this.expectedOwner,
  });
  final Album album;
  final PrintPhotoEditTarget target;
  final String expectedOwner;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      albumEditorViewModelProvider.overrideWith(AlbumEditorViewModel.new),
      coverViewModelProvider.overrideWith(CoverViewModel.new),
    ],
    child: _CorrectionNavigator(
      album: album,
      target: target,
      expectedOwner: expectedOwner,
    ),
  );
}

class _CorrectionNavigator extends StatefulWidget {
  const _CorrectionNavigator({
    required this.album,
    required this.target,
    required this.expectedOwner,
  });
  final Album album;
  final PrintPhotoEditTarget target;
  final String expectedOwner;
  @override
  State<_CorrectionNavigator> createState() => _CorrectionNavigatorState();
}

class _CorrectionNavigatorState extends State<_CorrectionNavigator> {
  final _navigator = GlobalKey<NavigatorState>();
  bool _handlingBack = false;

  Future<void> _requestBack() async {
    if (_handlingBack) return;
    _handlingBack = true;
    try {
      final handled =
          await (_navigator.currentState?.maybePop() ??
              Future<bool>.value(false));
      // A clean inner root bubbles after consulting the editor's exit guard.
      if (!handled && mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(false);
      }
    } finally {
      _handlingBack = false;
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _requestBack();
    },
    child: Navigator(
      key: _navigator,
      pages: [
        MaterialPage<Object?>(
          key: const ValueKey('print-photo-correction-root'),
          child: _PreparedPhotoEditor(
            album: widget.album,
            target: widget.target,
            expectedOwner: widget.expectedOwner,
          ),
        ),
      ],
      // The root editor's existing save/discard guard has already run. Forward
      // its result to the print route; keep the inner root until disposal.
      onPopPage: (route, result) {
        Navigator.of(context).pop(result == true);
        return false;
      },
    ),
  );
}

class _PreparedPhotoEditor extends ConsumerStatefulWidget {
  const _PreparedPhotoEditor({
    required this.album,
    required this.target,
    required this.expectedOwner,
  });
  final Album album;
  final PrintPhotoEditTarget target;
  final String expectedOwner;
  @override
  ConsumerState<_PreparedPhotoEditor> createState() =>
      _PreparedPhotoEditorState();
}

class _PreparedPhotoEditorState extends ConsumerState<_PreparedPhotoEditor> {
  late final Future<void> _ready;
  bool _closingOwnerModals = false;
  @override
  void initState() {
    super.initState();
    _ready = _prepare();
  }

  bool get _sameOwner =>
      mounted && ref.read(visibleOrderOwnerProvider) == widget.expectedOwner;

  Future<void> _prepare() async {
    await ref.read(coverViewModelProvider.future);
    await ref.read(albumEditorViewModelProvider.future);
    if (!_sameOwner) throw StateError('print_correction_owner_changed');
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    await vm.prepareAlbumForEdit(widget.album);
    if (!_sameOwner) throw StateError('print_correction_owner_changed');
    vm.loadPendingEditAlbumIfNeeded(
      Size(kCoverReferenceWidth, kCoverReferenceWidth / vm.selectedCover.ratio),
    );
    final target = widget.target;
    if (target.pageIndex < 0 ||
        target.pageIndex >= vm.pages.length ||
        vm.pages[target.pageIndex].layers
                .where(
                  (layer) =>
                      layer.id == target.layerId &&
                      layer.type == LayerType.image,
                )
                .length !=
            1) {
      throw StateError('print_correction_photo_missing');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sameOwner =
        ref.watch(visibleOrderOwnerProvider) == widget.expectedOwner;
    if (sameOwner) {
      _closingOwnerModals = false;
    } else if (!_closingOwnerModals) {
      _closingOwnerModals = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _sameOwner) return;
        // This navigator belongs only to this correction, including nested
        // crop/selection routes. Login and the outer print route stay intact.
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, ready) {
        if (!sameOwner || ready.hasError)
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        !sameOwner
                            ? '로그인 상태가 바뀌었어요. 다시 앨범을 열어 주세요.'
                            : '수정할 사진을 열지 못했어요. 인쇄 검토를 다시 확인해 주세요.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('인쇄 검토로 돌아가기'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        if (ready.connectionState != ConnectionState.done)
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        return PageEditorScreen(
          initialPageIndex: widget.target.pageIndex,
          initialSelectedLayerId: widget.target.layerId,
          returnToPreviousOnSave: true,
        );
      },
    );
  }
}
