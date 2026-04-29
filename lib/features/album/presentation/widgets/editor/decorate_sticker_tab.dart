import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../controllers/layer_builder.dart';

class DecorateStickerTab extends ConsumerStatefulWidget {
  final Color surfaceColor;
  final void Function(String sticker)? onStickerTap;

  const DecorateStickerTab({
    super.key,
    required this.surfaceColor,
    this.onStickerTap,
  });

  @override
  ConsumerState<DecorateStickerTab> createState() => _DecorateStickerTabState();
}

class _DecorateStickerTabState extends ConsumerState<DecorateStickerTab> {
  int? _selectedStickerIndex;

  static const List<_StickerItem> _stickersAll = [
    _StickerItem.deco("stickerBlueStar", scale: 1.0),
    _StickerItem.deco("stickerBlueStarSmall", scale: 0.74),
    _StickerItem.deco("stickerRibbonBlue", scale: 1.0),
    _StickerItem.deco("stickerPaperClip", scale: 0.92),
    _StickerItem.deco("stickerFlowerPink", scale: 1.0),
    _StickerItem.deco("stickerFlowerCoral", scale: 0.9),
    _StickerItem.deco("stickerDaisyWhite", scale: 1.0),
    _StickerItem.deco("stickerHeartRed", scale: 0.9),
    _StickerItem.deco("stickerLeafGreen", scale: 0.9),
    _StickerItem.deco("stickerSparkleBlue", scale: 0.9),
    _StickerItem.deco("stickerBowPink", scale: 0.95),
    _StickerItem.deco("stickerScribbleBlue", scale: 0.95),
    _StickerItem.deco("stickerBrushPink", scale: 0.95),
    _StickerItem.deco("stickerBlobGreen", scale: 0.95),
    _StickerItem.deco("stickerArrowCoral", scale: 0.95),
    _StickerItem.deco("stickerLeafCornerLeft", scale: 0.85),
    _StickerItem.deco("stickerLeafCornerRight", scale: 0.85),
    _StickerItem.deco("stickerCloudSoft", scale: 1.05),
    _StickerItem.deco("stickerCherryBlossom", scale: 1.0),
    _StickerItem.deco("stickerEnvelopeBlue", scale: 1.0),
    _StickerItem.deco("stickerCloverGreen", scale: 0.95),
    _StickerItem.deco("stickerInstantCamera", scale: 1.0),
    _StickerItem.deco("stickerTicketPaper", scale: 1.0),
    _StickerItem.deco("stickerTapeBeige", scale: 1.1),
    _StickerItem.deco("stickerTornNoteBeige", scale: 1.0),
    _StickerItem.deco("stickerCatDoodle", scale: 1.15),
    // expanded premium deco set
    _StickerItem.deco("stickerTapeDotsBlue", scale: 1.05),
    _StickerItem.deco("stickerTapeStripePink", scale: 1.05),
    _StickerItem.deco("stickerSparkleGold", scale: 0.95),
    _StickerItem.deco("stickerStarGold", scale: 0.95),
    _StickerItem.deco("stickerHeartPink", scale: 0.95),
    _StickerItem.asset("assets/sticker/scrap1.png"),
    _StickerItem.asset("assets/sticker/scrap2.png"),
    _StickerItem.asset("assets/sticker/scrap3.png"),
    _StickerItem.emoji("🎀"),
    _StickerItem.emoji("✿"),
    _StickerItem.emoji("❀"),
    _StickerItem.emoji("✾"),
    _StickerItem.emoji("✶"),
    _StickerItem.emoji("ฅ^•ﻌ•^ฅ"),
    _StickerItem.emoji("⌇"),
    _StickerItem.emoji("◈"),
    // hearts / sparkle
    _StickerItem.emoji("❤️"),
    _StickerItem.emoji("🧡"),
    _StickerItem.emoji("💛"),
    _StickerItem.emoji("💚"),
    _StickerItem.emoji("💙"),
    _StickerItem.emoji("💜"),
    _StickerItem.emoji("🖤"),
    _StickerItem.emoji("🤍"),
    _StickerItem.emoji("🩷"),
    _StickerItem.emoji("💖"),
    _StickerItem.emoji("💘"),
    _StickerItem.emoji("💝"),
    _StickerItem.emoji("💞"),
    _StickerItem.emoji("💟"),
    _StickerItem.emoji("✨"),
    _StickerItem.emoji("⭐"),
    _StickerItem.emoji("🌟"),
    _StickerItem.emoji("💫"),
    _StickerItem.emoji("🔥"),
    _StickerItem.emoji("🌈"),
    _StickerItem.emoji("☀️"),
    _StickerItem.emoji("🌤️"),
    _StickerItem.emoji("🌙"),
    _StickerItem.emoji("⚡"),
    // faces / hands
    _StickerItem.emoji("😊"),
    _StickerItem.emoji("😍"),
    _StickerItem.emoji("🥰"),
    _StickerItem.emoji("😎"),
    _StickerItem.emoji("🤩"),
    _StickerItem.emoji("🥳"),
    _StickerItem.emoji("😭"),
    _StickerItem.emoji("😆"),
    _StickerItem.emoji("🤝"),
    _StickerItem.emoji("👏"),
    _StickerItem.emoji("🙌"),
    _StickerItem.emoji("👍"),
    _StickerItem.emoji("🫶"),
    _StickerItem.emoji("🙏"),
    // pets / nature
    _StickerItem.emoji("🐶"),
    _StickerItem.emoji("🐱"),
    _StickerItem.emoji("🐰"),
    _StickerItem.emoji("🐻"),
    _StickerItem.emoji("🐼"),
    _StickerItem.emoji("🦊"),
    _StickerItem.emoji("🐾"),
    _StickerItem.emoji("🌸"),
    _StickerItem.emoji("🌷"),
    _StickerItem.emoji("🌼"),
    _StickerItem.emoji("🍀"),
    _StickerItem.emoji("🌿"),
    _StickerItem.emoji("🌵"),
    _StickerItem.emoji("🍃"),
    // party / deco
    _StickerItem.emoji("🎈"),
    _StickerItem.emoji("🎉"),
    _StickerItem.emoji("🎊"),
    _StickerItem.emoji("🎁"),
    _StickerItem.emoji("🎨"),
    _StickerItem.emoji("🖍️"),
    _StickerItem.emoji("📸"),
    _StickerItem.emoji("🧸"),
    _StickerItem.emoji("🍰"),
    _StickerItem.emoji("🧁"),
    _StickerItem.emoji("🍭"),
    _StickerItem.emoji("🍓"),
    _StickerItem.emoji("🍒"),
    // travel / daily
    _StickerItem.emoji("✈️"),
    _StickerItem.emoji("🚗"),
    _StickerItem.emoji("🏠"),
    _StickerItem.emoji("🛍️"),
    _StickerItem.emoji("☕"),
    _StickerItem.emoji("🍿"),
    _StickerItem.emoji("🎧"),
    _StickerItem.emoji("📚"),
    _StickerItem.emoji("🕶️"),
    _StickerItem.emoji("⌚"),
    _StickerItem.emoji("🧩"),
    _StickerItem.emoji("📎"),
    _StickerItem.emoji("✎"),
    _StickerItem.emoji("❧"),
    _StickerItem.emoji("✧"),
    _StickerItem.emoji("❦"),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 20.h),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _stickersAll.length,
      itemBuilder: (context, index) {
        final sticker = _stickersAll[index];
        final isSelected = _selectedStickerIndex == index;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedStickerIndex = index;
            });
            widget.onStickerTap?.call(sticker.valueForInsert);
          },
          child: Container(
            decoration: BoxDecoration(
              color: widget.surfaceColor,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: isSelected
                    ? SnapFitColors.accent
                    : SnapFitColors.overlayLightOf(context),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                Center(child: _buildStickerVisual(sticker)),
                if (isSelected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(
                      Icons.check_circle,
                      color: SnapFitColors.accent,
                      size: 16.sp,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStickerVisual(_StickerItem sticker) {
    if (sticker.isAsset) {
      return Image.asset(
        sticker.value,
        fit: BoxFit.contain,
        width: 42.w,
        height: 42.w,
      );
    }
    if (sticker.isDeco) {
      return _DecoStickerPreview(style: sticker.value);
    }
    return Text(sticker.value, style: TextStyle(fontSize: 28.sp));
  }
}

class _StickerItem {
  final String value;
  final bool isAsset;
  final bool isDeco;
  final double scale;

  const _StickerItem.emoji(this.value)
    : isAsset = false,
      isDeco = false,
      scale = 1.0;
  const _StickerItem.asset(this.value)
    : isAsset = true,
      isDeco = false,
      scale = 1.0;
  const _StickerItem.deco(this.value, {this.scale = 1.0})
    : isAsset = false,
      isDeco = true;

  String get valueForInsert {
    if (isAsset) return 'asset:$value';
    if (isDeco) return 'deco:$value@$scale';
    return value;
  }
}

class _DecoStickerPreview extends StatelessWidget {
  final String style;

  const _DecoStickerPreview({required this.style});

  @override
  Widget build(BuildContext context) {
    // 실제 캔버스 적용과 동일한 렌더 결과로 미리보기 표시
    return DecoStickerVisual(style: style, width: 40.w, height: 40.w);
  }
}

/// 레이아웃(찢김 스크랩) 전용 탭
class DecorateLayoutTab extends StatelessWidget {
  final Color surfaceColor;
  final void Function(String layoutKey)? onLayoutTap;

  const DecorateLayoutTab({
    super.key,
    required this.surfaceColor,
    this.onLayoutTap,
  });

  static const List<String> _layoutKeys = ['scrap1', 'scrap2', 'scrap3'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      child: GridView.builder(
        itemCount: _layoutKeys.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemBuilder: (context, index) {
          final key = _layoutKeys[index];
          return GestureDetector(
            onTap: () => onLayoutTap?.call(key),
            child: Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: SnapFitColors.overlayLightOf(context),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(8.w),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12.r),
                        child: Image.asset(
                          'assets/sticker/$key.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      key,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: SnapFitColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
