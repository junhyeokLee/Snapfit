import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../../album/presentation/viewmodels/home_view_model.dart';
import 'personal_collection_shelf.dart';

/// Keeps the form subtree alive when its order summary moves beside it.
class OrderRequestWorkspace extends StatefulWidget {
  const OrderRequestWorkspace({
    super.key,
    required this.albumId,
    required this.albumTitle,
    required this.orderId,
    required this.child,
    required this.controller,
  });

  final int? albumId;
  final String? albumTitle, orderId;
  final Widget child;
  final ScrollController controller;

  @override
  State<OrderRequestWorkspace> createState() => _OrderRequestWorkspaceState();
}

class _OrderRequestWorkspaceState extends State<OrderRequestWorkspace> {
  final _summaryKey = GlobalKey();
  final _formKey = GlobalKey();
  final _scrollKey = GlobalKey();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final wide =
          bounds.maxWidth >= 540 &&
          MediaQuery.orientationOf(context) == Orientation.landscape;
      final summary = KeyedSubtree(
        key: _summaryKey,
        child: _OrderRequestSummary(
          key: const ValueKey('print-order-request-summary'),
          albumId: widget.albumId,
          albumTitle: widget.albumTitle,
          orderId: widget.orderId,
          wide: wide,
        ),
      );
      final form = KeyedSubtree(key: _formKey, child: widget.child);
      final content = SingleChildScrollView(
        key: _scrollKey,
        controller: widget.controller,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!wide) ...[
              summary,
              const SizedBox(height: 24),
              Divider(height: 1, color: ExperienceFormStyle.line(context)),
              const SizedBox(height: 24),
            ],
            form,
          ],
        ),
      );
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 1040 : 680),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: (bounds.maxWidth * .36).clamp(180.0, 320.0),
                      child: SingleChildScrollView(
                        key: const PageStorageKey(
                          'order-request-summary-scroll',
                        ),
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                        child: summary,
                      ),
                    ),
                    VerticalDivider(
                      width: 1,
                      color: ExperienceFormStyle.line(context),
                    ),
                    Expanded(child: content),
                  ],
                )
              : content,
        ),
      );
    },
  );
}

class _OrderRequestSummary extends ConsumerWidget {
  const _OrderRequestSummary({
    super.key,
    required this.albumId,
    required this.albumTitle,
    required this.orderId,
    required this.wide,
  });
  final int? albumId;
  final String? albumTitle, orderId;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final album = albumId == null
        ? null
        : ref
              .watch(homeViewModelProvider)
              .asData
              ?.value
              .where((album) => album.id == albumId)
              .firstOrNull;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          orderId == null ? '주문 준비 건' : '문의할 주문',
          style: ExperienceFormStyle.text(context, 12, secondary: true),
        ),
        if (albumTitle?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(
            albumTitle!,
            style: ExperienceFormStyle.text(
              context,
              20,
              weight: FontWeight.w700,
            ),
          ),
        ],
        if (orderId != null) ...[
          const SizedBox(height: 12),
          SelectableText(
            '주문 $orderId',
            style: ExperienceFormStyle.text(context, 11, secondary: true),
          ),
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (album != null && wide) ...[
          SizedBox(height: 172, child: SavedAlbumArtwork(album: album)),
          const SizedBox(height: 16),
        ],
        if (album != null && !wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 88,
                height: 112,
                child: SavedAlbumArtwork(album: album),
              ),
              const SizedBox(width: 16),
              Expanded(child: details),
            ],
          )
        else
          details,
        if (album != null) ...[
          const SizedBox(height: 12),
          Text(
            '현재 저장된 표지 미리보기\n주문 당시 인쇄본과 다를 수 있어요.',
            style: ExperienceFormStyle.text(context, 11, secondary: true),
          ),
        ],
      ],
    );
  }
}
