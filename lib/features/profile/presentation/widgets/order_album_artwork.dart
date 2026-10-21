import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../../album/presentation/viewmodels/home_view_model.dart';
import 'personal_collection_shelf.dart';

class OrderAlbumArtwork extends ConsumerWidget {
  const OrderAlbumArtwork({super.key, required this.albumId});
  final int? albumId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final album = ref
        .watch(homeViewModelProvider)
        .asData
        ?.value
        .where((album) => album.id == albumId)
        .firstOrNull;
    return Semantics(
      label: album == null ? '앨범 표지 미리보기 없음' : '현재 저장된 앨범 표지',
      child: SavedAlbumArtwork(album: album),
    );
  }
}

class OrderDetailWorkspace extends ConsumerStatefulWidget {
  const OrderDetailWorkspace({
    super.key,
    required this.albumId,
    required this.children,
  });
  final int? albumId;
  final List<Widget> children;
  @override
  ConsumerState<OrderDetailWorkspace> createState() =>
      _OrderDetailWorkspaceState();
}

class _OrderDetailWorkspaceState extends ConsumerState<OrderDetailWorkspace> {
  final _informationKey = GlobalKey();
  final _previewKey = GlobalKey();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final hasCover =
          ref
              .watch(homeViewModelProvider)
              .asData
              ?.value
              .any((album) => album.id == widget.albumId) ==
          true;
      final wide =
          box.maxWidth >= 520 &&
          MediaQuery.orientationOf(context) == Orientation.landscape;
      final preview = Column(
        key: _previewKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: OrderAlbumArtwork(albumId: widget.albumId)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Text(
              hasCover
                  ? '현재 저장된 표지 미리보기\n주문 당시 인쇄본과 다를 수 있어요.'
                  : '앨범 표지를 확인할 수 없어요.\n주문 정보의 인쇄 규격을 확인해 주세요.',
              textAlign: TextAlign.center,
              style: ExperienceFormStyle.text(context, 11, secondary: true),
            ),
          ),
        ],
      );
      final information = ListView(
        key: _informationKey,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        children: [
          if (!wide) ...[
            SizedBox(height: 260, child: preview),
            const SizedBox(height: 20),
          ],
          ...widget.children,
        ],
      );
      return wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 4, child: preview),
                VerticalDivider(
                  width: 1,
                  color: ExperienceFormStyle.line(context),
                ),
                Expanded(flex: 6, child: information),
              ],
            )
          : information;
    },
  );
}
