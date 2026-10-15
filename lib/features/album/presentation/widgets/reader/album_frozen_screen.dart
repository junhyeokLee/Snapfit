import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../shared/widgets/experience_style.dart';
import '../../../../../shared/web/web_design.dart';
import '../../../domain/entities/album.dart';
import '../home/home_album_cover_thumbnail.dart';
import '../web/web_saved_album_artwork.dart';

class AlbumFrozenScreen extends StatelessWidget {
  final Album? album;
  final VoidCallback onClose;
  final VoidCallback onOrder;

  const AlbumFrozenScreen({
    super.key,
    required this.album,
    required this.onClose,
    required this.onOrder,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return _buildWeb(context);
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: ExperienceHeader(
        title: '앨범 완성',
        themeAware: true,
        onBack: onClose,
        showNotifications: false,
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, bounds) {
            final wide =
                bounds.maxWidth >= 520 && bounds.maxWidth > bounds.maxHeight;
            final details = _details(context);
            if (wide) {
              return Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: LayoutBuilder(
                        builder: (context, stage) =>
                            _cover(stage.maxHeight, stage.maxWidth),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 24, 32, 24),
                      child: details,
                    ),
                  ),
                ],
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                children: [
                  SizedBox(
                    height: math.min(320, bounds.maxHeight * .44),
                    child: Center(
                      child: _cover(
                        math.min(300, bounds.maxHeight * .42),
                        bounds.maxWidth - 64,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: details,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWeb(BuildContext context) => SnapFitWebShell(
    title: '앨범 완성',
    showNavigation: false,
    actions: [TextButton.icon(
      onPressed: onClose,
      icon: const Icon(Icons.close, size: 17),
      label: const Text('닫기'),
    )],
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WebPageHeading(
            eyebrow: 'ALBUM COMPLETE',
            title: '완성된 앨범을 확인하세요',
            description: '앨범은 보관하고 계속 수정할 수 있습니다. 책 주문은 다음 단계에서 준비합니다.',
          ),
          const SizedBox(height: 30),
          LayoutBuilder(builder: (context, box) {
            final preview = WebSurface(
              child: SizedBox(
                height: 380,
                child: album == null
                    ? Center(child: Icon(Icons.auto_stories_outlined,
                        size: 42, color: WebPalette.of(context).muted))
                    : Center(child: WebSavedAlbumArtwork(album: album!)),
              ),
            );
            final details = WebSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Icon(Icons.check_circle_outline, size: 20, color: WebPalette.of(context).brandInk),
                    SizedBox(width: 10), Text('앨범 완성', style: TextStyle(
                      fontSize: 13, color: WebPalette.of(context).brandInk, fontWeight: FontWeight.w600,
                    )),
                  ]),
                  const SizedBox(height: 22),
                  Text(album?.title.isNotEmpty == true ? album!.title : '스냅핏 앨범',
                    style: TextStyle(color: WebPalette.of(context).ink,
                      fontSize: 25, fontWeight: FontWeight.w700)),
                  if (album != null) ...[
                    const SizedBox(height: 12),
                    Text(album!.physicalCoverSize.displayName,
                      style: TextStyle(color: WebPalette.of(context).muted, fontSize: 13)),
                  ],
                  const SizedBox(height: 24),
                  Divider(height: 1, color: WebPalette.of(context).line),
                  const SizedBox(height: 24),
                  Text('책으로 간직하기', style: TextStyle(
                    color: WebPalette.of(context).ink, fontSize: 17, fontWeight: FontWeight.w700,
                  )),
                  const SizedBox(height: 10),
                  Text('책의 전체 배치와 제작 금액을 확인한 뒤 배송지를 입력할 수 있습니다.',
                    style: TextStyle(color: WebPalette.of(context).muted, fontSize: 14, height: 1.7)),
                  const SizedBox(height: 26),
                  FilledButton.icon(
                    onPressed: onOrder,
                    icon: const Icon(Icons.auto_stories_outlined, size: 18),
                    label: const Text('책 주문 준비하기'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(onPressed: onClose, child: const Text('완료')),
                ],
              ),
            );
            if (box.maxWidth < 900) return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [preview, const SizedBox(height: 22), details],
            );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Expanded(child: preview), const SizedBox(width: 28),
                Expanded(child: details)],
            );
          }),
          const SizedBox(height: 32),
        ],
      ),
    ),
  );

  Widget _cover(double height, double width) {
    final value = album;
    if (value == null) {
      return const Center(child: Icon(Icons.auto_stories_outlined, size: 48));
    }
    return Center(
      child: HomeAlbumCoverThumbnail(
        key: const ValueKey('completed-album-cover'),
        album: value,
        height: math.max(1, height),
        maxWidth: math.max(1, width),
        showBookDepth: true,
        shadowScaleMultiplier: .6,
      ),
    );
  }

  Widget _details(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 20,
            color: ExperienceFormStyle.selectionInk(context),
          ),
          const SizedBox(width: 8),
          Text(
            '완성된 앨범',
            style: ExperienceFormStyle.text(context, 13, secondary: true),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        '앨범이 완성되었습니다!',
        style: ExperienceFormStyle.text(context, 26, weight: FontWeight.w600),
      ),
      if (album?.title.isNotEmpty == true) ...[
        const SizedBox(height: 8),
        Text(album!.title, style: ExperienceFormStyle.text(context, 16)),
      ],
      const SizedBox(height: 12),
      Text(
        '소중한 기록을 앨범에 담았어요.\n앨범은 보관하고 계속 수정할 수 있습니다.',
        style: ExperienceFormStyle.text(context, 14, secondary: true),
      ),
      const SizedBox(height: 28),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onOrder,
          style: ExperienceFormStyle.primary(context),
          icon: const Icon(Icons.auto_stories_outlined, size: 19),
          label: const Text('책으로 주문 준비하기'),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        '책의 배치와 제작 금액을 확인한 뒤 배송지를 입력해요.',
        style: ExperienceFormStyle.text(context, 12, secondary: true),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: onClose,
          style: TextButton.styleFrom(
            foregroundColor: ExperienceFormStyle.ink(context),
            minimumSize: const Size(0, 48),
          ),
          child: const Text('완료'),
        ),
      ),
    ],
  );
}
