import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../web/web_design.dart';
import '../../features/album/data/api/album_provider.dart';
import '../../features/album/data/gallery/browser_gallery_repository.dart';
import '../../features/album/data/gallery/browser_photo_asset.dart';
import '../../features/album/data/gallery/browser_photo_picker.dart';
import '../../features/profile/domain/order_visibility_owner.dart';
import 'experience_form_style.dart';

Future<List<AssetEntity>?> showBrowserPhotosSelectionSheet(
  BuildContext context, {
  required int maxSelection,
}) => showDialog<List<AssetEntity>>(
  context: context,
  barrierDismissible: false,
  builder: (dialogContext) => Dialog(
    backgroundColor: WebPalette.of(dialogContext).surface,
    insetPadding: const EdgeInsets.all(24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 820),
      child: BrowserPhotoSelectionSheet(maxSelection: maxSelection),
    ),
  ),
);

class BrowserPhotoSelectionSheet extends ConsumerStatefulWidget {
  const BrowserPhotoSelectionSheet({
    super.key,
    required this.maxSelection,
    this.selectFiles,
  });
  final int maxSelection;
  final Future<List<BrowserPhotoFile>> Function()? selectFiles;
  @override
  ConsumerState<BrowserPhotoSelectionSheet> createState() =>
      _BrowserPhotoSelectionSheetState();
}

class _BrowserPhotoSelectionSheetState
    extends ConsumerState<BrowserPhotoSelectionSheet> {
  final _dropKey = GlobalKey();
  final _selected = <String>{};
  BrowserPhotoDropSubscription? _drop;
  BrowserGalleryRepository? _repository;
  String? _owner;
  bool _busy = false;
  bool _hovering = false;
  String? _notice;
  List<BrowserPhotoAsset> _photos = const [];

  bool get _ownerCurrent =>
      _owner != null && ref.read(visibleOrderOwnerProvider) == _owner;

  @override
  void initState() {
    super.initState();
    final repository = ref.read(galleryRepositoryProvider);
    if (repository is BrowserGalleryRepository) {
      _repository = repository;
      _owner = repository.currentOwner();
      _photos = repository.photos;
    }
    _drop = listenBrowserPhotoDrop(
      hitTest: (x, y) {
        if (!mounted || !_ownerCurrent || _busy) return false;
        final box = _dropKey.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.hasSize) return false;
        final position = box.globalToLocal(Offset(x, y));
        return (Offset.zero & box.size).contains(position);
      },
      onFiles: (files) => unawaited(_import(files)),
      onHover: (value) {
        if (mounted && value != _hovering) setState(() => _hovering = value);
      },
    );
  }

  @override
  void dispose() {
    _drop?.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    if (_busy || !_ownerCurrent) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final files =
          await (widget.selectFiles?.call() ??
              pickBrowserPhotoFiles(multiple: widget.maxSelection > 1));
      if (!mounted || !_ownerCurrent) return;
      if (files.isEmpty) {
        setState(() => _notice = '파일 선택을 취소했어요. 선택한 사진은 그대로 유지됩니다.');
      } else {
        await _import(files, alreadyBusy: true);
      }
    } catch (_) {
      if (mounted && _ownerCurrent)
        setState(() => _notice = '파일 선택창을 열지 못했어요. 다시 선택하거나 사진을 여기로 끌어놓아 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import(
    List<BrowserPhotoFile> files, {
    bool alreadyBusy = false,
  }) async {
    if ((!alreadyBusy && _busy) || !_ownerCurrent || _repository == null)
      return;
    if (files.isEmpty) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final result = await _repository!.importFiles(files);
      if (!mounted || !_ownerCurrent) return;
      setState(() {
        _photos = _repository!.photos;
        for (final photo in result.added) {
          if (_selected.length >= widget.maxSelection) break;
          _selected.add(photo.id);
        }
        _notice = result.messages.isNotEmpty
            ? result.messages.take(4).join('\n')
            : result.added.isEmpty
            ? '이미 선택 목록에 있는 사진이에요.'
            : '${result.added.length}장의 사진을 가져왔어요. 사용할 사진을 확인해주세요.';
      });
    } on BrowserPhotoException catch (error) {
      if (mounted && _ownerCurrent) setState(() => _notice = error.message);
    } catch (_) {
      if (mounted && _ownerCurrent)
        setState(() => _notice = '사진을 읽지 못했어요. 파일을 다시 선택해주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggle(BrowserPhotoAsset photo) {
    if (_busy || !_ownerCurrent) return;
    setState(() {
      if (!_selected.remove(photo.id)) {
        if (widget.maxSelection == 1) _selected.clear();
        if (_selected.length >= widget.maxSelection) {
          _notice = '한 번에 최대 ${widget.maxSelection}장을 선택할 수 있어요.';
        } else {
          _selected.add(photo.id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(visibleOrderOwnerProvider);
    if (!_ownerCurrent || _repository == null) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text('로그인한 계정이 변경됐어요. 사진 선택창을 닫고 다시 열어주세요.')),
      );
    }
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .88,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '앨범에 사용할 사진',
                    style: ExperienceFormStyle.text(
                      context,
                      20,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  tooltip: '사진 선택 닫기',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  key: const ValueKey('browser-photo-pick-files'),
                  onPressed: _busy ? null : _pick,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(_busy ? '사진 읽는 중' : '사진 파일 선택'),
                ),
                Text(
                  '${_selected.length} / ${widget.maxSelection}장 선택',
                  style: ExperienceFormStyle.text(context, 14),
                ),
                TextButton(
                  onPressed: _busy || _photos.isEmpty
                      ? null
                      : () => setState(() {
                          _repository!.clearSelectionLibrary();
                          _photos = const [];
                          _selected.clear();
                          _notice = '선택 목록을 비웠어요. 이미 앨범에 넣은 사진은 유지됩니다.';
                        }),
                  child: const Text('선택 목록 비우기'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
            child: Text(
              'JPG·PNG·WebP · 한 장 50MB · 최대 100장, 총 250MB\n원본 화질을 보존합니다. 사진을 넣은 후 앨범을 저장해 주세요.',
              style: ExperienceFormStyle.text(context, 12, secondary: true),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _notice!,
                  style: ExperienceFormStyle.text(context, 13),
                ),
              ),
            ),
          Expanded(
            child: Container(
              key: _dropKey,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _hovering
                      ? WebPalette.of(context).brandInk
                      : ExperienceFormStyle.line(context),
                  width: _hovering ? 2 : 1,
                ),
                color: _hovering ? WebPalette.of(context).softBrand.withValues(alpha: .4) : WebPalette.of(context).background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _photos.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.file_upload_outlined, size: 42),
                            const SizedBox(height: 12),
                            Text(
                              _hovering
                                  ? '여기에 사진을 놓아주세요'
                                  : '사진을 여기로 끌어놓거나\n위의 사진 파일 선택을 눌러주세요.',
                              textAlign: TextAlign.center,
                              style: ExperienceFormStyle.text(context, 15),
                            ),
                          ],
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 170,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: _photos.length,
                      itemBuilder: (context, index) {
                        final photo = _photos[index],
                            selected = _selected.contains(_photos[index].id);
                        return Semantics(
                          label:
                              '${photo.title ?? '사진'} ${photo.width}×${photo.height}',
                          selected: selected,
                          button: true,
                          child: InkWell(
                            key: ValueKey('browser-photo-${photo.id}'),
                            onTap: _busy ? null : () => _toggle(photo),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.memory(
                                    photo.previewBytes,
                                    fit: BoxFit.cover,
                                    cacheWidth: 320,
                                  ),
                                ),
                                if (selected)
                                  Container(
                                    color: Colors.black26,
                                    alignment: Alignment.topRight,
                                    padding: const EdgeInsets.all(8),
                                    child: const Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 24),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: WebPalette.of(context).line))),
            child: Row(children: [
              Expanded(child: Text('선택한 사진을 앨범에 추가합니다.', style: TextStyle(fontSize: 12, color: WebPalette.of(context).muted))),
              const SizedBox(width: 16),
              FilledButton(
                key: const ValueKey('confirm-browser-photo-selection'),
                onPressed: _busy || _selected.isEmpty
                    ? null
                    : () {
                        if (!_ownerCurrent) return;
                        Navigator.pop(context, <AssetEntity>[
                          for (final photo in _photos)
                            if (_selected.contains(photo.id)) photo,
                        ]);
                      },
                child: Text('${_selected.length}장 선택 완료'),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
