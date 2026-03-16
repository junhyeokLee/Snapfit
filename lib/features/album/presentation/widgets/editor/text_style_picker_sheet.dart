import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';

/// 텍스트 스타일 선택용 바텀시트 (이미지 레퍼런스: 탭·섹션·카드 구조)
class TextStylePickerSheet extends StatefulWidget {
  final String? selectedKey;
  final ValueChanged<String> onSelect;

  const TextStylePickerSheet({
    super.key,
    required this.selectedKey,
    required this.onSelect,
  });

  static Future<String?> show(
    BuildContext context, {
    required String? currentKey,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TextStylePickerSheet(
        selectedKey: currentKey,
        onSelect: (key) => Navigator.pop(ctx, key),
      ),
    );
  }

  @override
  State<TextStylePickerSheet> createState() => _TextStylePickerSheetState();
}

/// 카테고리별 스타일 아이템 (키, 라벨, 프리뷰용 타입)
class _TextStyleItem {
  final String key;
  final String previewType;

  const _TextStyleItem({required this.key, required this.previewType});
}

/// 기본: 없음 + (라운드/사각/소프트 필 = 디자인별 10색 통일)
const List<_TextStyleItem> _basicStyles = [
  _TextStyleItem(key: '', previewType: 'none'),
  _TextStyleItem(key: 'round', previewType: 'round'),
  _TextStyleItem(key: 'roundGray', previewType: 'roundGray'),
  _TextStyleItem(key: 'roundPink', previewType: 'roundPink'),
  _TextStyleItem(key: 'roundBlue', previewType: 'roundBlue'),
  _TextStyleItem(key: 'roundMint', previewType: 'roundMint'),
  _TextStyleItem(key: 'roundLavender', previewType: 'roundLavender'),
  _TextStyleItem(key: 'roundOrange', previewType: 'roundOrange'),
  _TextStyleItem(key: 'roundGreen', previewType: 'roundGreen'),
  _TextStyleItem(key: 'roundCream', previewType: 'roundCream'),
  _TextStyleItem(key: 'roundNavy', previewType: 'roundNavy'),
  _TextStyleItem(key: 'roundRose', previewType: 'roundRose'),
  _TextStyleItem(key: 'roundCoral', previewType: 'roundCoral'),
  _TextStyleItem(key: 'roundBeige', previewType: 'roundBeige'),
  _TextStyleItem(key: 'roundTeal', previewType: 'roundTeal'),
  _TextStyleItem(key: 'roundLemon', previewType: 'roundLemon'),
  _TextStyleItem(key: 'square', previewType: 'square'),
  _TextStyleItem(key: 'squareGray', previewType: 'squareGray'),
  _TextStyleItem(key: 'squarePink', previewType: 'squarePink'),
  _TextStyleItem(key: 'squareBlue', previewType: 'squareBlue'),
  _TextStyleItem(key: 'squareMint', previewType: 'squareMint'),
  _TextStyleItem(key: 'squareLavender', previewType: 'squareLavender'),
  _TextStyleItem(key: 'squareOrange', previewType: 'squareOrange'),
  _TextStyleItem(key: 'squareGreen', previewType: 'squareGreen'),
  _TextStyleItem(key: 'squareCream', previewType: 'squareCream'),
  _TextStyleItem(key: 'squareNavy', previewType: 'squareNavy'),
  _TextStyleItem(key: 'squareRose', previewType: 'squareRose'),
  _TextStyleItem(key: 'squareCoral', previewType: 'squareCoral'),
  _TextStyleItem(key: 'squareBeige', previewType: 'squareBeige'),
  _TextStyleItem(key: 'squareTeal', previewType: 'squareTeal'),
  _TextStyleItem(key: 'squareLemon', previewType: 'squareLemon'),
  _TextStyleItem(key: 'roundSoft', previewType: 'roundSoft'),
  _TextStyleItem(key: 'roundSoftGray', previewType: 'roundSoftGray'),
  _TextStyleItem(key: 'roundSoftPink', previewType: 'roundSoftPink'),
  _TextStyleItem(key: 'roundSoftBlue', previewType: 'roundSoftBlue'),
  _TextStyleItem(key: 'roundSoftMint', previewType: 'roundSoftMint'),
  _TextStyleItem(key: 'roundSoftLavender', previewType: 'roundSoftLavender'),
  _TextStyleItem(key: 'roundSoftOrange', previewType: 'roundSoftOrange'),
  _TextStyleItem(key: 'roundSoftGreen', previewType: 'roundSoftGreen'),
  _TextStyleItem(key: 'roundSoftCream', previewType: 'roundSoftCream'),
  _TextStyleItem(key: 'roundSoftNavy', previewType: 'roundSoftNavy'),
  _TextStyleItem(key: 'roundSoftRose', previewType: 'roundSoftRose'),
  _TextStyleItem(key: 'roundSoftCoral', previewType: 'roundSoftCoral'),
  _TextStyleItem(key: 'roundSoftBeige', previewType: 'roundSoftBeige'),
  _TextStyleItem(key: 'roundSoftTeal', previewType: 'roundSoftTeal'),
  _TextStyleItem(key: 'roundSoftLemon', previewType: 'roundSoftLemon'),
  _TextStyleItem(key: 'softPill2', previewType: 'softPill2'),
  _TextStyleItem(key: 'softPill2Gray', previewType: 'softPill2Gray'),
  _TextStyleItem(key: 'softPill2Pink', previewType: 'softPill2Pink'),
  _TextStyleItem(key: 'softPill2Blue', previewType: 'softPill2Blue'),
  _TextStyleItem(key: 'softPill2Mint', previewType: 'softPill2Mint'),
  _TextStyleItem(key: 'softPill2Lavender', previewType: 'softPill2Lavender'),
  _TextStyleItem(key: 'softPill2Orange', previewType: 'softPill2Orange'),
  _TextStyleItem(key: 'softPill2Green', previewType: 'softPill2Green'),
  _TextStyleItem(key: 'softPill2Cream', previewType: 'softPill2Cream'),
  _TextStyleItem(key: 'softPill2Navy', previewType: 'softPill2Navy'),
  _TextStyleItem(key: 'softPill2Rose', previewType: 'softPill2Rose'),
  _TextStyleItem(key: 'softPill2Coral', previewType: 'softPill2Coral'),
  _TextStyleItem(key: 'softPill2Beige', previewType: 'softPill2Beige'),
  _TextStyleItem(key: 'softPill2Teal', previewType: 'softPill2Teal'),
  _TextStyleItem(key: 'softPill2Lemon', previewType: 'softPill2Lemon'),
];

const List<_DesignGroup> _basicDesignGroups = [
  _DesignGroup(id: 'none', labelKo: '없음', items: [_TextStyleItem(key: '', previewType: 'none')]),
  _DesignGroup(
    id: 'round',
    labelKo: '라운드',
    items: [
      _TextStyleItem(key: 'round', previewType: 'round'),
      _TextStyleItem(key: 'roundGray', previewType: 'roundGray'),
      _TextStyleItem(key: 'roundPink', previewType: 'roundPink'),
      _TextStyleItem(key: 'roundBlue', previewType: 'roundBlue'),
      _TextStyleItem(key: 'roundMint', previewType: 'roundMint'),
      _TextStyleItem(key: 'roundLavender', previewType: 'roundLavender'),
      _TextStyleItem(key: 'roundOrange', previewType: 'roundOrange'),
      _TextStyleItem(key: 'roundGreen', previewType: 'roundGreen'),
      _TextStyleItem(key: 'roundCream', previewType: 'roundCream'),
      _TextStyleItem(key: 'roundNavy', previewType: 'roundNavy'),
      _TextStyleItem(key: 'roundRose', previewType: 'roundRose'),
      _TextStyleItem(key: 'roundCoral', previewType: 'roundCoral'),
      _TextStyleItem(key: 'roundBeige', previewType: 'roundBeige'),
      _TextStyleItem(key: 'roundTeal', previewType: 'roundTeal'),
      _TextStyleItem(key: 'roundLemon', previewType: 'roundLemon'),
    ],
  ),
  _DesignGroup(
    id: 'square',
    labelKo: '사각',
    items: [
      _TextStyleItem(key: 'square', previewType: 'square'),
      _TextStyleItem(key: 'squareGray', previewType: 'squareGray'),
      _TextStyleItem(key: 'squarePink', previewType: 'squarePink'),
      _TextStyleItem(key: 'squareBlue', previewType: 'squareBlue'),
      _TextStyleItem(key: 'squareMint', previewType: 'squareMint'),
      _TextStyleItem(key: 'squareLavender', previewType: 'squareLavender'),
      _TextStyleItem(key: 'squareOrange', previewType: 'squareOrange'),
      _TextStyleItem(key: 'squareGreen', previewType: 'squareGreen'),
      _TextStyleItem(key: 'squareCream', previewType: 'squareCream'),
      _TextStyleItem(key: 'squareNavy', previewType: 'squareNavy'),
      _TextStyleItem(key: 'squareRose', previewType: 'squareRose'),
      _TextStyleItem(key: 'squareCoral', previewType: 'squareCoral'),
      _TextStyleItem(key: 'squareBeige', previewType: 'squareBeige'),
      _TextStyleItem(key: 'squareTeal', previewType: 'squareTeal'),
      _TextStyleItem(key: 'squareLemon', previewType: 'squareLemon'),
    ],
  ),
  _DesignGroup(
    id: 'roundSoft',
    labelKo: '소프트 필',
    items: [
      _TextStyleItem(key: 'roundSoft', previewType: 'roundSoft'),
      _TextStyleItem(key: 'roundSoftGray', previewType: 'roundSoftGray'),
      _TextStyleItem(key: 'roundSoftPink', previewType: 'roundSoftPink'),
      _TextStyleItem(key: 'roundSoftBlue', previewType: 'roundSoftBlue'),
      _TextStyleItem(key: 'roundSoftMint', previewType: 'roundSoftMint'),
      _TextStyleItem(key: 'roundSoftLavender', previewType: 'roundSoftLavender'),
      _TextStyleItem(key: 'roundSoftOrange', previewType: 'roundSoftOrange'),
      _TextStyleItem(key: 'roundSoftGreen', previewType: 'roundSoftGreen'),
      _TextStyleItem(key: 'roundSoftCream', previewType: 'roundSoftCream'),
      _TextStyleItem(key: 'roundSoftNavy', previewType: 'roundSoftNavy'),
      _TextStyleItem(key: 'roundSoftRose', previewType: 'roundSoftRose'),
      _TextStyleItem(key: 'roundSoftCoral', previewType: 'roundSoftCoral'),
      _TextStyleItem(key: 'roundSoftBeige', previewType: 'roundSoftBeige'),
      _TextStyleItem(key: 'roundSoftTeal', previewType: 'roundSoftTeal'),
      _TextStyleItem(key: 'roundSoftLemon', previewType: 'roundSoftLemon'),
    ],
  ),
  _DesignGroup(
    id: 'softPill2',
    labelKo: '소프트 필2',
    items: [
      _TextStyleItem(key: 'softPill2', previewType: 'softPill2'),
      _TextStyleItem(key: 'softPill2Gray', previewType: 'softPill2Gray'),
      _TextStyleItem(key: 'softPill2Pink', previewType: 'softPill2Pink'),
      _TextStyleItem(key: 'softPill2Blue', previewType: 'softPill2Blue'),
      _TextStyleItem(key: 'softPill2Mint', previewType: 'softPill2Mint'),
      _TextStyleItem(key: 'softPill2Lavender', previewType: 'softPill2Lavender'),
      _TextStyleItem(key: 'softPill2Orange', previewType: 'softPill2Orange'),
      _TextStyleItem(key: 'softPill2Green', previewType: 'softPill2Green'),
      _TextStyleItem(key: 'softPill2Cream', previewType: 'softPill2Cream'),
      _TextStyleItem(key: 'softPill2Navy', previewType: 'softPill2Navy'),
      _TextStyleItem(key: 'softPill2Rose', previewType: 'softPill2Rose'),
      _TextStyleItem(key: 'softPill2Coral', previewType: 'softPill2Coral'),
      _TextStyleItem(key: 'softPill2Beige', previewType: 'softPill2Beige'),
      _TextStyleItem(key: 'softPill2Teal', previewType: 'softPill2Teal'),
      _TextStyleItem(key: 'softPill2Lemon', previewType: 'softPill2Lemon'),
    ],
  ),
];
/// 말풍선 – 디자인별(6종) + 색상 10종 통일
const List<_TextStyleItem> _speechBubbles = [
  _TextStyleItem(key: 'bubble', previewType: 'tailLeft'),
  _TextStyleItem(key: 'bubbleGray', previewType: 'bubbleGray'),
  _TextStyleItem(key: 'bubblePink', previewType: 'bubblePink'),
  _TextStyleItem(key: 'bubbleBlue', previewType: 'bubbleBlue'),
  _TextStyleItem(key: 'bubbleMint', previewType: 'bubbleMint'),
  _TextStyleItem(key: 'bubbleLavender', previewType: 'bubbleLavender'),
  _TextStyleItem(key: 'bubbleOrange', previewType: 'bubbleOrange'),
  _TextStyleItem(key: 'bubbleGreen', previewType: 'bubbleGreen'),
  _TextStyleItem(key: 'bubbleCream', previewType: 'bubbleCream'),
  _TextStyleItem(key: 'bubbleNavy', previewType: 'bubbleNavy'),
  _TextStyleItem(key: 'bubbleRose', previewType: 'bubbleRose'),
  _TextStyleItem(key: 'bubbleCoral', previewType: 'bubbleCoral'),
  _TextStyleItem(key: 'bubbleBeige', previewType: 'bubbleBeige'),
  _TextStyleItem(key: 'bubbleTeal', previewType: 'bubbleTeal'),
  _TextStyleItem(key: 'bubbleLemon', previewType: 'bubbleLemon'),
  _TextStyleItem(key: 'bubbleCenter', previewType: 'tailCenter'),
  _TextStyleItem(key: 'bubbleCenterGray', previewType: 'bubbleGray'),
  _TextStyleItem(key: 'bubbleCenterPink', previewType: 'bubblePink'),
  _TextStyleItem(key: 'bubbleCenterBlue', previewType: 'bubbleBlue'),
  _TextStyleItem(key: 'bubbleCenterMint', previewType: 'bubbleMint'),
  _TextStyleItem(key: 'bubbleCenterLavender', previewType: 'bubbleLavender'),
  _TextStyleItem(key: 'bubbleCenterOrange', previewType: 'bubbleOrange'),
  _TextStyleItem(key: 'bubbleCenterGreen', previewType: 'bubbleGreen'),
  _TextStyleItem(key: 'bubbleCenterCream', previewType: 'bubbleCream'),
  _TextStyleItem(key: 'bubbleCenterNavy', previewType: 'bubbleNavy'),
  _TextStyleItem(key: 'bubbleCenterRose', previewType: 'bubbleRose'),
  _TextStyleItem(key: 'bubbleCenterCoral', previewType: 'bubbleCoral'),
  _TextStyleItem(key: 'bubbleCenterBeige', previewType: 'bubbleBeige'),
  _TextStyleItem(key: 'bubbleCenterTeal', previewType: 'bubbleTeal'),
  _TextStyleItem(key: 'bubbleCenterLemon', previewType: 'bubbleLemon'),
  _TextStyleItem(key: 'bubbleRight', previewType: 'tailRight'),
  _TextStyleItem(key: 'bubbleRightGray', previewType: 'bubbleGray'),
  _TextStyleItem(key: 'bubbleRightPink', previewType: 'bubblePink'),
  _TextStyleItem(key: 'bubbleRightBlue', previewType: 'bubbleBlue'),
  _TextStyleItem(key: 'bubbleRightMint', previewType: 'bubbleMint'),
  _TextStyleItem(key: 'bubbleRightLavender', previewType: 'bubbleLavender'),
  _TextStyleItem(key: 'bubbleRightOrange', previewType: 'bubbleOrange'),
  _TextStyleItem(key: 'bubbleRightGreen', previewType: 'bubbleGreen'),
  _TextStyleItem(key: 'bubbleRightCream', previewType: 'bubbleCream'),
  _TextStyleItem(key: 'bubbleRightNavy', previewType: 'bubbleNavy'),
  _TextStyleItem(key: 'bubbleRightRose', previewType: 'bubbleRose'),
  _TextStyleItem(key: 'bubbleRightCoral', previewType: 'bubbleCoral'),
  _TextStyleItem(key: 'bubbleRightBeige', previewType: 'bubbleBeige'),
  _TextStyleItem(key: 'bubbleRightTeal', previewType: 'bubbleTeal'),
  _TextStyleItem(key: 'bubbleRightLemon', previewType: 'bubbleLemon'),
  _TextStyleItem(key: 'bubbleSquare', previewType: 'tailSquareLeft'),
  _TextStyleItem(key: 'bubbleSquareGray', previewType: 'bubbleGray'),
  _TextStyleItem(key: 'bubbleSquarePink', previewType: 'bubblePink'),
  _TextStyleItem(key: 'bubbleSquareBlue', previewType: 'bubbleBlue'),
  _TextStyleItem(key: 'bubbleSquareMint', previewType: 'bubbleMint'),
  _TextStyleItem(key: 'bubbleSquareLavender', previewType: 'bubbleLavender'),
  _TextStyleItem(key: 'bubbleSquareOrange', previewType: 'bubbleOrange'),
  _TextStyleItem(key: 'bubbleSquareGreen', previewType: 'bubbleGreen'),
  _TextStyleItem(key: 'bubbleSquareCream', previewType: 'bubbleCream'),
  _TextStyleItem(key: 'bubbleSquareNavy', previewType: 'bubbleNavy'),
  _TextStyleItem(key: 'bubbleSquareRose', previewType: 'bubbleRose'),
  _TextStyleItem(key: 'bubbleSquareCoral', previewType: 'bubbleCoral'),
  _TextStyleItem(key: 'bubbleSquareBeige', previewType: 'bubbleBeige'),
  _TextStyleItem(key: 'bubbleSquareTeal', previewType: 'bubbleTeal'),
  _TextStyleItem(key: 'bubbleSquareLemon', previewType: 'bubbleLemon'),
  _TextStyleItem(key: 'bubbleSquareCenter', previewType: 'tailSquareCenter'),
  _TextStyleItem(key: 'bubbleSquareCenterGray', previewType: 'bubbleGray'),
  _TextStyleItem(key: 'bubbleSquareCenterPink', previewType: 'bubblePink'),
  _TextStyleItem(key: 'bubbleSquareCenterBlue', previewType: 'bubbleBlue'),
  _TextStyleItem(key: 'bubbleSquareCenterMint', previewType: 'bubbleMint'),
  _TextStyleItem(key: 'bubbleSquareCenterLavender', previewType: 'bubbleLavender'),
  _TextStyleItem(key: 'bubbleSquareCenterOrange', previewType: 'bubbleOrange'),
  _TextStyleItem(key: 'bubbleSquareCenterGreen', previewType: 'bubbleGreen'),
  _TextStyleItem(key: 'bubbleSquareCenterCream', previewType: 'bubbleCream'),
  _TextStyleItem(key: 'bubbleSquareCenterNavy', previewType: 'bubbleNavy'),
  _TextStyleItem(key: 'bubbleSquareCenterRose', previewType: 'bubbleRose'),
  _TextStyleItem(key: 'bubbleSquareCenterCoral', previewType: 'bubbleCoral'),
  _TextStyleItem(key: 'bubbleSquareCenterBeige', previewType: 'bubbleBeige'),
  _TextStyleItem(key: 'bubbleSquareCenterTeal', previewType: 'bubbleTeal'),
  _TextStyleItem(key: 'bubbleSquareCenterLemon', previewType: 'bubbleLemon'),
  _TextStyleItem(key: 'bubbleSquareRight', previewType: 'tailSquareRight'),
  _TextStyleItem(key: 'bubbleSquareRightGray', previewType: 'bubbleGray'),
  _TextStyleItem(key: 'bubbleSquareRightPink', previewType: 'bubblePink'),
  _TextStyleItem(key: 'bubbleSquareRightBlue', previewType: 'bubbleBlue'),
  _TextStyleItem(key: 'bubbleSquareRightMint', previewType: 'bubbleMint'),
  _TextStyleItem(key: 'bubbleSquareRightLavender', previewType: 'bubbleLavender'),
  _TextStyleItem(key: 'bubbleSquareRightOrange', previewType: 'bubbleOrange'),
  _TextStyleItem(key: 'bubbleSquareRightGreen', previewType: 'bubbleGreen'),
  _TextStyleItem(key: 'bubbleSquareRightCream', previewType: 'bubbleCream'),
  _TextStyleItem(key: 'bubbleSquareRightNavy', previewType: 'bubbleNavy'),
  _TextStyleItem(key: 'bubbleSquareRightRose', previewType: 'bubbleRose'),
  _TextStyleItem(key: 'bubbleSquareRightCoral', previewType: 'bubbleCoral'),
  _TextStyleItem(key: 'bubbleSquareRightBeige', previewType: 'bubbleBeige'),
  _TextStyleItem(key: 'bubbleSquareRightTeal', previewType: 'bubbleTeal'),
  _TextStyleItem(key: 'bubbleSquareRightLemon', previewType: 'bubbleLemon'),
];

const List<_DesignGroup> _speechBubbleDesignGroups = [
  _DesignGroup(id: 'bubble', labelKo: '라운드 왼쪽', items: [
    _TextStyleItem(key: 'bubble', previewType: 'tailLeft'),
    _TextStyleItem(key: 'bubbleGray', previewType: 'bubbleGray'),
    _TextStyleItem(key: 'bubblePink', previewType: 'bubblePink'),
    _TextStyleItem(key: 'bubbleBlue', previewType: 'bubbleBlue'),
    _TextStyleItem(key: 'bubbleMint', previewType: 'bubbleMint'),
    _TextStyleItem(key: 'bubbleLavender', previewType: 'bubbleLavender'),
    _TextStyleItem(key: 'bubbleOrange', previewType: 'bubbleOrange'),
    _TextStyleItem(key: 'bubbleGreen', previewType: 'bubbleGreen'),
    _TextStyleItem(key: 'bubbleCream', previewType: 'bubbleCream'),
    _TextStyleItem(key: 'bubbleNavy', previewType: 'bubbleNavy'),
    _TextStyleItem(key: 'bubbleRose', previewType: 'bubbleRose'),
    _TextStyleItem(key: 'bubbleCoral', previewType: 'bubbleCoral'),
    _TextStyleItem(key: 'bubbleBeige', previewType: 'bubbleBeige'),
    _TextStyleItem(key: 'bubbleTeal', previewType: 'bubbleTeal'),
    _TextStyleItem(key: 'bubbleLemon', previewType: 'bubbleLemon'),
  ]),
  _DesignGroup(id: 'bubbleCenter', labelKo: '라운드 가운데', items: [
    _TextStyleItem(key: 'bubbleCenter', previewType: 'tailCenter'),
    _TextStyleItem(key: 'bubbleCenterGray', previewType: 'bubbleGray'),
    _TextStyleItem(key: 'bubbleCenterPink', previewType: 'bubblePink'),
    _TextStyleItem(key: 'bubbleCenterBlue', previewType: 'bubbleBlue'),
    _TextStyleItem(key: 'bubbleCenterMint', previewType: 'bubbleMint'),
    _TextStyleItem(key: 'bubbleCenterLavender', previewType: 'bubbleLavender'),
    _TextStyleItem(key: 'bubbleCenterOrange', previewType: 'bubbleOrange'),
    _TextStyleItem(key: 'bubbleCenterGreen', previewType: 'bubbleGreen'),
    _TextStyleItem(key: 'bubbleCenterCream', previewType: 'bubbleCream'),
    _TextStyleItem(key: 'bubbleCenterNavy', previewType: 'bubbleNavy'),
    _TextStyleItem(key: 'bubbleCenterRose', previewType: 'bubbleRose'),
    _TextStyleItem(key: 'bubbleCenterCoral', previewType: 'bubbleCoral'),
    _TextStyleItem(key: 'bubbleCenterBeige', previewType: 'bubbleBeige'),
    _TextStyleItem(key: 'bubbleCenterTeal', previewType: 'bubbleTeal'),
    _TextStyleItem(key: 'bubbleCenterLemon', previewType: 'bubbleLemon'),
  ]),
  _DesignGroup(id: 'bubbleRight', labelKo: '라운드 오른쪽', items: [
    _TextStyleItem(key: 'bubbleRight', previewType: 'tailRight'),
    _TextStyleItem(key: 'bubbleRightGray', previewType: 'bubbleGray'),
    _TextStyleItem(key: 'bubbleRightPink', previewType: 'bubblePink'),
    _TextStyleItem(key: 'bubbleRightBlue', previewType: 'bubbleBlue'),
    _TextStyleItem(key: 'bubbleRightMint', previewType: 'bubbleMint'),
    _TextStyleItem(key: 'bubbleRightLavender', previewType: 'bubbleLavender'),
    _TextStyleItem(key: 'bubbleRightOrange', previewType: 'bubbleOrange'),
    _TextStyleItem(key: 'bubbleRightGreen', previewType: 'bubbleGreen'),
    _TextStyleItem(key: 'bubbleRightCream', previewType: 'bubbleCream'),
    _TextStyleItem(key: 'bubbleRightNavy', previewType: 'bubbleNavy'),
    _TextStyleItem(key: 'bubbleRightRose', previewType: 'bubbleRose'),
    _TextStyleItem(key: 'bubbleRightCoral', previewType: 'bubbleCoral'),
    _TextStyleItem(key: 'bubbleRightBeige', previewType: 'bubbleBeige'),
    _TextStyleItem(key: 'bubbleRightTeal', previewType: 'bubbleTeal'),
    _TextStyleItem(key: 'bubbleRightLemon', previewType: 'bubbleLemon'),
  ]),
  _DesignGroup(id: 'bubbleSquare', labelKo: '사각 왼쪽', items: [
    _TextStyleItem(key: 'bubbleSquare', previewType: 'tailSquareLeft'),
    _TextStyleItem(key: 'bubbleSquareGray', previewType: 'bubbleGray'),
    _TextStyleItem(key: 'bubbleSquarePink', previewType: 'bubblePink'),
    _TextStyleItem(key: 'bubbleSquareBlue', previewType: 'bubbleBlue'),
    _TextStyleItem(key: 'bubbleSquareMint', previewType: 'bubbleMint'),
    _TextStyleItem(key: 'bubbleSquareLavender', previewType: 'bubbleLavender'),
    _TextStyleItem(key: 'bubbleSquareOrange', previewType: 'bubbleOrange'),
    _TextStyleItem(key: 'bubbleSquareGreen', previewType: 'bubbleGreen'),
    _TextStyleItem(key: 'bubbleSquareCream', previewType: 'bubbleCream'),
    _TextStyleItem(key: 'bubbleSquareNavy', previewType: 'bubbleNavy'),
    _TextStyleItem(key: 'bubbleSquareRose', previewType: 'bubbleRose'),
    _TextStyleItem(key: 'bubbleSquareCoral', previewType: 'bubbleCoral'),
    _TextStyleItem(key: 'bubbleSquareBeige', previewType: 'bubbleBeige'),
    _TextStyleItem(key: 'bubbleSquareTeal', previewType: 'bubbleTeal'),
    _TextStyleItem(key: 'bubbleSquareLemon', previewType: 'bubbleLemon'),
  ]),
  _DesignGroup(id: 'bubbleSquareCenter', labelKo: '사각 가운데', items: [
    _TextStyleItem(key: 'bubbleSquareCenter', previewType: 'tailSquareCenter'),
    _TextStyleItem(key: 'bubbleSquareCenterGray', previewType: 'bubbleGray'),
    _TextStyleItem(key: 'bubbleSquareCenterPink', previewType: 'bubblePink'),
    _TextStyleItem(key: 'bubbleSquareCenterBlue', previewType: 'bubbleBlue'),
    _TextStyleItem(key: 'bubbleSquareCenterMint', previewType: 'bubbleMint'),
    _TextStyleItem(key: 'bubbleSquareCenterLavender', previewType: 'bubbleLavender'),
    _TextStyleItem(key: 'bubbleSquareCenterOrange', previewType: 'bubbleOrange'),
    _TextStyleItem(key: 'bubbleSquareCenterGreen', previewType: 'bubbleGreen'),
    _TextStyleItem(key: 'bubbleSquareCenterCream', previewType: 'bubbleCream'),
    _TextStyleItem(key: 'bubbleSquareCenterNavy', previewType: 'bubbleNavy'),
    _TextStyleItem(key: 'bubbleSquareCenterRose', previewType: 'bubbleRose'),
    _TextStyleItem(key: 'bubbleSquareCenterCoral', previewType: 'bubbleCoral'),
    _TextStyleItem(key: 'bubbleSquareCenterBeige', previewType: 'bubbleBeige'),
    _TextStyleItem(key: 'bubbleSquareCenterTeal', previewType: 'bubbleTeal'),
    _TextStyleItem(key: 'bubbleSquareCenterLemon', previewType: 'bubbleLemon'),
  ]),
  _DesignGroup(id: 'bubbleSquareRight', labelKo: '사각 오른쪽', items: [
    _TextStyleItem(key: 'bubbleSquareRight', previewType: 'tailSquareRight'),
    _TextStyleItem(key: 'bubbleSquareRightGray', previewType: 'bubbleGray'),
    _TextStyleItem(key: 'bubbleSquareRightPink', previewType: 'bubblePink'),
    _TextStyleItem(key: 'bubbleSquareRightBlue', previewType: 'bubbleBlue'),
    _TextStyleItem(key: 'bubbleSquareRightMint', previewType: 'bubbleMint'),
    _TextStyleItem(key: 'bubbleSquareRightLavender', previewType: 'bubbleLavender'),
    _TextStyleItem(key: 'bubbleSquareRightOrange', previewType: 'bubbleOrange'),
    _TextStyleItem(key: 'bubbleSquareRightGreen', previewType: 'bubbleGreen'),
    _TextStyleItem(key: 'bubbleSquareRightCream', previewType: 'bubbleCream'),
    _TextStyleItem(key: 'bubbleSquareRightNavy', previewType: 'bubbleNavy'),
    _TextStyleItem(key: 'bubbleSquareRightRose', previewType: 'bubbleRose'),
    _TextStyleItem(key: 'bubbleSquareRightCoral', previewType: 'bubbleCoral'),
    _TextStyleItem(key: 'bubbleSquareRightBeige', previewType: 'bubbleBeige'),
    _TextStyleItem(key: 'bubbleSquareRightTeal', previewType: 'bubbleTeal'),
    _TextStyleItem(key: 'bubbleSquareRightLemon', previewType: 'bubbleLemon'),
  ]),
];

/// 라벨 & 태그 – 기본/말풍선과 동일한 색상 순서
const List<_TextStyleItem> _labels = [
  _TextStyleItem(key: 'label', previewType: 'oval'),
  _TextStyleItem(key: 'labelGray', previewType: 'labelGray'),
  _TextStyleItem(key: 'labelPink', previewType: 'labelPink'),
  _TextStyleItem(key: 'labelBlue', previewType: 'labelBlue'),
  _TextStyleItem(key: 'labelMint', previewType: 'labelMint'),
  _TextStyleItem(key: 'labelLavender', previewType: 'labelLavender'),
  _TextStyleItem(key: 'labelOrange', previewType: 'labelOrange'),
  _TextStyleItem(key: 'labelGreen', previewType: 'labelGreen'),
  _TextStyleItem(key: 'labelWhite', previewType: 'labelWhite'),
  _TextStyleItem(key: 'labelCream', previewType: 'labelCream'),
  _TextStyleItem(key: 'labelSolid', previewType: 'labelSolid'),
  _TextStyleItem(key: 'labelSolidGray', previewType: 'labelSolidGray'),
  _TextStyleItem(key: 'labelSolidPink', previewType: 'labelSolidPink'),
  _TextStyleItem(key: 'labelSolidBlue', previewType: 'labelSolidBlue'),
  _TextStyleItem(key: 'labelSolidMint', previewType: 'labelSolidMint'),
  _TextStyleItem(key: 'labelSolidLavender', previewType: 'labelSolidLavender'),
  _TextStyleItem(key: 'labelSolidOrange', previewType: 'labelSolidOrange'),
  _TextStyleItem(key: 'labelSolidGreen', previewType: 'labelSolidGreen'),
  _TextStyleItem(key: 'labelSolidCream', previewType: 'labelSolidCream'),
  _TextStyleItem(key: 'labelSolidRed', previewType: 'labelSolidRed'),
  _TextStyleItem(key: 'tag', previewType: 'tag'),
  _TextStyleItem(key: 'tagGray', previewType: 'tagGray'),
  _TextStyleItem(key: 'tagPink', previewType: 'tagPink'),
  _TextStyleItem(key: 'tagBlue', previewType: 'tagBlue'),
  _TextStyleItem(key: 'tagMint', previewType: 'tagMint'),
  _TextStyleItem(key: 'tagLavender', previewType: 'tagLavender'),
  _TextStyleItem(key: 'tagOrange', previewType: 'tagOrange'),
  _TextStyleItem(key: 'tagGreen', previewType: 'tagGreen'),
  _TextStyleItem(key: 'tagRed', previewType: 'tagRed'),
  _TextStyleItem(key: 'labelOutline', previewType: 'labelOutline'),
  _TextStyleItem(key: 'labelNeon', previewType: 'labelNeon'),
  _TextStyleItem(key: 'labelGold', previewType: 'labelGold'),
  _TextStyleItem(key: 'labelRose', previewType: 'labelRose'),
];
/// 메모지 – 기본/말풍선과 동일한 색상 순서
const List<_TextStyleItem> _notes = [
  _TextStyleItem(key: 'noteGray', previewType: 'noteGray'),
  _TextStyleItem(key: 'notePink', previewType: 'notePink'),
  _TextStyleItem(key: 'noteBlue', previewType: 'noteBlue'),
  _TextStyleItem(key: 'noteMint', previewType: 'noteMint'),
  _TextStyleItem(key: 'noteLavender', previewType: 'noteLavender'),
  _TextStyleItem(key: 'noteOrange', previewType: 'noteOrange'),
  _TextStyleItem(key: 'noteCream', previewType: 'noteCream'),
  _TextStyleItem(key: 'noteBeige', previewType: 'noteBeige'),
  _TextStyleItem(key: 'noteYellow', previewType: 'noteYellow'),
  _TextStyleItem(key: 'noteGold', previewType: 'noteGold'),
  _TextStyleItem(key: 'noteGrid', previewType: 'noteGrid'),
  _TextStyleItem(key: 'noteGridGray', previewType: 'noteGridGray'),
  _TextStyleItem(key: 'noteGridPink', previewType: 'noteGridPink'),
  _TextStyleItem(key: 'noteGridBlue', previewType: 'noteGridBlue'),
  _TextStyleItem(key: 'noteGridMint', previewType: 'noteGridMint'),
  _TextStyleItem(key: 'noteGridLavender', previewType: 'noteGridLavender'),
  _TextStyleItem(key: 'noteGridOrange', previewType: 'noteGridOrange'),
  _TextStyleItem(key: 'noteTorn', previewType: 'noteYellow'),
  _TextStyleItem(key: 'noteTornGray', previewType: 'noteGray'),
  _TextStyleItem(key: 'noteTornPink', previewType: 'notePink'),
  _TextStyleItem(key: 'noteTornBlue', previewType: 'noteBlue'),
  _TextStyleItem(key: 'noteTornMint', previewType: 'noteMint'),
  _TextStyleItem(key: 'noteTornLavender', previewType: 'noteLavender'),
  _TextStyleItem(key: 'noteTornOrange', previewType: 'noteOrange'),
  _TextStyleItem(key: 'noteTornCream', previewType: 'noteCream'),
  _TextStyleItem(key: 'noteTornBeige', previewType: 'noteBeige'),
  _TextStyleItem(key: 'noteTornYellow', previewType: 'noteYellow'),
  _TextStyleItem(key: 'noteTornGold', previewType: 'noteGold'),
  _TextStyleItem(key: 'noteTornRough', previewType: 'noteTornRough'),
  _TextStyleItem(key: 'noteTornRoughGray', previewType: 'noteTornRoughGray'),
  _TextStyleItem(key: 'noteTornRoughPink', previewType: 'noteTornRoughPink'),
  _TextStyleItem(key: 'noteTornRoughBlue', previewType: 'noteTornRoughBlue'),
  _TextStyleItem(key: 'noteTornRoughMint', previewType: 'noteTornRoughMint'),
  _TextStyleItem(key: 'noteTornRoughLavender', previewType: 'noteTornRoughLavender'),
  _TextStyleItem(key: 'noteTornRoughOrange', previewType: 'noteTornRoughOrange'),
  _TextStyleItem(key: 'noteTornRoughCream', previewType: 'noteTornRoughCream'),
  _TextStyleItem(key: 'noteTornRoughBeige', previewType: 'noteTornRoughBeige'),
  _TextStyleItem(key: 'noteTornRoughYellow', previewType: 'noteTornRoughYellow'),
  _TextStyleItem(key: 'noteTornRoughGold', previewType: 'noteTornRoughGold'),
  _TextStyleItem(key: 'noteTornSoft', previewType: 'noteTornSoft'),
  _TextStyleItem(key: 'noteTornSoftGray', previewType: 'noteTornSoftGray'),
  _TextStyleItem(key: 'noteTornSoftPink', previewType: 'noteTornSoftPink'),
  _TextStyleItem(key: 'noteTornSoftBlue', previewType: 'noteTornSoftBlue'),
  _TextStyleItem(key: 'noteTornSoftMint', previewType: 'noteTornSoftMint'),
  _TextStyleItem(key: 'noteTornSoftLavender', previewType: 'noteTornSoftLavender'),
  _TextStyleItem(key: 'noteTornSoftOrange', previewType: 'noteTornSoftOrange'),
  _TextStyleItem(key: 'noteTornSoftCream', previewType: 'noteTornSoftCream'),
  _TextStyleItem(key: 'noteTornSoftBeige', previewType: 'noteTornSoftBeige'),
  _TextStyleItem(key: 'noteTornSoftYellow', previewType: 'noteTornSoftYellow'),
  _TextStyleItem(key: 'noteTornSoftGold', previewType: 'noteTornSoftGold'),
];
/// 테이프 – 기본/말풍선과 동일한 색상 순서
const List<_TextStyleItem> _tapes = [
  _TextStyleItem(key: 'tape', previewType: 'stripe'),
  _TextStyleItem(key: 'tapeGray', previewType: 'tapeGray'),
  _TextStyleItem(key: 'tapePink', previewType: 'tapePink'),
  _TextStyleItem(key: 'tapeMint', previewType: 'tapeMint'),
  _TextStyleItem(key: 'tapeLavender', previewType: 'tapeLavender'),
  _TextStyleItem(key: 'tapeYellow', previewType: 'tapeYellow'),
  _TextStyleItem(key: 'tapeTorn', previewType: 'stripe'),
  _TextStyleItem(key: 'tapeTornGray', previewType: 'tapeGray'),
  _TextStyleItem(key: 'tapeTornPink', previewType: 'tapePink'),
  _TextStyleItem(key: 'tapeTornMint', previewType: 'tapeMint'),
  _TextStyleItem(key: 'tapeTornLavender', previewType: 'tapeLavender'),
  _TextStyleItem(key: 'tapeTornYellow', previewType: 'tapeYellow'),
  _TextStyleItem(key: 'tapeTornRough', previewType: 'tapeTornRough'),
  _TextStyleItem(key: 'tapeTornRoughGray', previewType: 'tapeTornRoughGray'),
  _TextStyleItem(key: 'tapeTornRoughPink', previewType: 'tapeTornRoughPink'),
  _TextStyleItem(key: 'tapeTornRoughMint', previewType: 'tapeTornRoughMint'),
  _TextStyleItem(key: 'tapeTornRoughLavender', previewType: 'tapeTornRoughLavender'),
  _TextStyleItem(key: 'tapeTornRoughYellow', previewType: 'tapeTornRoughYellow'),
  _TextStyleItem(key: 'tapeTornSoft', previewType: 'tapeTornSoft'),
  _TextStyleItem(key: 'tapeTornSoftGray', previewType: 'tapeTornSoftGray'),
  _TextStyleItem(key: 'tapeTornSoftPink', previewType: 'tapeTornSoftPink'),
  _TextStyleItem(key: 'tapeTornSoftMint', previewType: 'tapeTornSoftMint'),
  _TextStyleItem(key: 'tapeTornSoftLavender', previewType: 'tapeTornSoftLavender'),
  _TextStyleItem(key: 'tapeTornSoftYellow', previewType: 'tapeTornSoftYellow'),
  _TextStyleItem(key: 'tapeTornSolid', previewType: 'tapeTornSolid'),
  _TextStyleItem(key: 'tapeTornSolidGray', previewType: 'tapeTornSolidGray'),
  _TextStyleItem(key: 'tapeTornSolidPink', previewType: 'tapeTornSolidPink'),
  _TextStyleItem(key: 'tapeTornSolidBlue', previewType: 'tapeTornSolidBlue'),
  _TextStyleItem(key: 'tapeTornSolidMint', previewType: 'tapeTornSolidMint'),
  _TextStyleItem(key: 'tapeTornSolidLavender', previewType: 'tapeTornSolidLavender'),
  _TextStyleItem(key: 'tapeTornSolidOrange', previewType: 'tapeTornSolidOrange'),
  _TextStyleItem(key: 'tapeTornSolidGreen', previewType: 'tapeTornSolidGreen'),
  _TextStyleItem(key: 'tapeDots', previewType: 'tapeDots'),
  _TextStyleItem(key: 'tapeDotsGray', previewType: 'tapeDotsGray'),
  _TextStyleItem(key: 'tapeDotsPink', previewType: 'tapeDotsPink'),
  _TextStyleItem(key: 'tapeDotsMint', previewType: 'tapeDotsMint'),
  _TextStyleItem(key: 'tapeDotsLavender', previewType: 'tapeDotsLavender'),
  _TextStyleItem(key: 'tapeDotsOrange', previewType: 'tapeDotsOrange'),
  _TextStyleItem(key: 'tapeSolidGray', previewType: 'tapeSolidGray'),
  _TextStyleItem(key: 'tapeSolidPink', previewType: 'tapeSolidPink'),
  _TextStyleItem(key: 'tapeSolidBlue', previewType: 'tapeSolidBlue'),
  _TextStyleItem(key: 'tapeSolidMint', previewType: 'tapeSolidMint'),
  _TextStyleItem(key: 'tapeSolidLavender', previewType: 'tapeSolidLavender'),
  _TextStyleItem(key: 'tapeSolidOrange', previewType: 'tapeSolidOrange'),
  _TextStyleItem(key: 'tapeSolidGreen', previewType: 'tapeSolidGreen'),
  _TextStyleItem(key: 'tapeSolidWhite', previewType: 'tapeSolidWhite'),
  _TextStyleItem(key: 'tapeKraft', previewType: 'tapeKraft'),
  _TextStyleItem(key: 'tapeGold', previewType: 'tapeGold'),
  _TextStyleItem(key: 'tapeDouble', previewType: 'tapeDouble'),
  _TextStyleItem(key: 'tapeDoubleGray', previewType: 'tapeDoubleGray'),
  _TextStyleItem(key: 'tapeDoublePink', previewType: 'tapeDoublePink'),
  _TextStyleItem(key: 'tapeDoubleBlue', previewType: 'tapeDoubleBlue'),
  _TextStyleItem(key: 'tapeDoubleMint', previewType: 'tapeDoubleMint'),
  _TextStyleItem(key: 'tapeDoubleLavender', previewType: 'tapeDoubleLavender'),
];

/// 디자인(형태) + 색상 선택용 그룹 — 같은 디자인에 색만 다른 항목을 묶음
class _DesignGroup {
  final String id;
  final String labelKo;
  final List<_TextStyleItem> items;

  const _DesignGroup({required this.id, required this.labelKo, required this.items});
}

/// 메모지: 디자인별 그룹 + 색상 선택 (기본/말풍선과 동일한 색상 순서: Gray→Pink→Blue→Mint→Lavender→Orange→…)
const List<_DesignGroup> _noteDesignGroups = [
  _DesignGroup(
    id: 'noteSolid',
    labelKo: '단색',
    items: [
      _TextStyleItem(key: 'noteGray', previewType: 'noteGray'),
      _TextStyleItem(key: 'notePink', previewType: 'notePink'),
      _TextStyleItem(key: 'noteBlue', previewType: 'noteBlue'),
      _TextStyleItem(key: 'noteMint', previewType: 'noteMint'),
      _TextStyleItem(key: 'noteLavender', previewType: 'noteLavender'),
      _TextStyleItem(key: 'noteOrange', previewType: 'noteOrange'),
      _TextStyleItem(key: 'noteCream', previewType: 'noteCream'),
      _TextStyleItem(key: 'noteBeige', previewType: 'noteBeige'),
      _TextStyleItem(key: 'noteYellow', previewType: 'noteYellow'),
      _TextStyleItem(key: 'noteGold', previewType: 'noteGold'),
    ],
  ),
  _DesignGroup(id: 'noteGrid', labelKo: '격자', items: [
    _TextStyleItem(key: 'noteGrid', previewType: 'noteGrid'),
    _TextStyleItem(key: 'noteGridGray', previewType: 'noteGridGray'),
    _TextStyleItem(key: 'noteGridPink', previewType: 'noteGridPink'),
    _TextStyleItem(key: 'noteGridBlue', previewType: 'noteGridBlue'),
    _TextStyleItem(key: 'noteGridMint', previewType: 'noteGridMint'),
    _TextStyleItem(key: 'noteGridLavender', previewType: 'noteGridLavender'),
    _TextStyleItem(key: 'noteGridOrange', previewType: 'noteGridOrange'),
  ]),
  _DesignGroup(id: 'noteTorn', labelKo: '찢어진', items: [
    _TextStyleItem(key: 'noteTorn', previewType: 'noteTorn'),
    _TextStyleItem(key: 'noteTornGray', previewType: 'noteTornGray'),
    _TextStyleItem(key: 'noteTornPink', previewType: 'noteTornPink'),
    _TextStyleItem(key: 'noteTornBlue', previewType: 'noteTornBlue'),
    _TextStyleItem(key: 'noteTornMint', previewType: 'noteTornMint'),
    _TextStyleItem(key: 'noteTornLavender', previewType: 'noteTornLavender'),
    _TextStyleItem(key: 'noteTornOrange', previewType: 'noteTornOrange'),
    _TextStyleItem(key: 'noteTornCream', previewType: 'noteTornCream'),
    _TextStyleItem(key: 'noteTornBeige', previewType: 'noteTornBeige'),
    _TextStyleItem(key: 'noteTornYellow', previewType: 'noteTornYellow'),
    _TextStyleItem(key: 'noteTornGold', previewType: 'noteTornGold'),
  ]),
  _DesignGroup(id: 'noteTornRough', labelKo: '찢어진(Hard)', items: [
    _TextStyleItem(key: 'noteTornRough', previewType: 'noteTornRough'),
    _TextStyleItem(key: 'noteTornRoughGray', previewType: 'noteTornRoughGray'),
    _TextStyleItem(key: 'noteTornRoughPink', previewType: 'noteTornRoughPink'),
    _TextStyleItem(key: 'noteTornRoughBlue', previewType: 'noteTornRoughBlue'),
    _TextStyleItem(key: 'noteTornRoughMint', previewType: 'noteTornRoughMint'),
    _TextStyleItem(key: 'noteTornRoughLavender', previewType: 'noteTornRoughLavender'),
    _TextStyleItem(key: 'noteTornRoughOrange', previewType: 'noteTornRoughOrange'),
    _TextStyleItem(key: 'noteTornRoughCream', previewType: 'noteTornRoughCream'),
    _TextStyleItem(key: 'noteTornRoughBeige', previewType: 'noteTornRoughBeige'),
    _TextStyleItem(key: 'noteTornRoughYellow', previewType: 'noteTornRoughYellow'),
    _TextStyleItem(key: 'noteTornRoughGold', previewType: 'noteTornRoughGold'),
  ]),
  _DesignGroup(id: 'noteTornSoft', labelKo: '찢어진(Soft)', items: [
    _TextStyleItem(key: 'noteTornSoft', previewType: 'noteTornSoft'),
    _TextStyleItem(key: 'noteTornSoftGray', previewType: 'noteTornSoftGray'),
    _TextStyleItem(key: 'noteTornSoftPink', previewType: 'noteTornSoftPink'),
    _TextStyleItem(key: 'noteTornSoftBlue', previewType: 'noteTornSoftBlue'),
    _TextStyleItem(key: 'noteTornSoftMint', previewType: 'noteTornSoftMint'),
    _TextStyleItem(key: 'noteTornSoftLavender', previewType: 'noteTornSoftLavender'),
    _TextStyleItem(key: 'noteTornSoftOrange', previewType: 'noteTornSoftOrange'),
    _TextStyleItem(key: 'noteTornSoftCream', previewType: 'noteTornSoftCream'),
    _TextStyleItem(key: 'noteTornSoftBeige', previewType: 'noteTornSoftBeige'),
    _TextStyleItem(key: 'noteTornSoftYellow', previewType: 'noteTornSoftYellow'),
    _TextStyleItem(key: 'noteTornSoftGold', previewType: 'noteTornSoftGold'),
  ]),
];

/// 라벨: 디자인별 그룹 + 기본/말풍선과 동일한 색상 순서, 그룹별 10색 통일
const List<_DesignGroup> _labelDesignGroups = [
  _DesignGroup(id: 'labelOval', labelKo: '타원', items: [
    _TextStyleItem(key: 'label', previewType: 'oval'),
    _TextStyleItem(key: 'labelGray', previewType: 'labelGray'),
    _TextStyleItem(key: 'labelPink', previewType: 'labelPink'),
    _TextStyleItem(key: 'labelBlue', previewType: 'labelBlue'),
    _TextStyleItem(key: 'labelMint', previewType: 'labelMint'),
    _TextStyleItem(key: 'labelLavender', previewType: 'labelLavender'),
    _TextStyleItem(key: 'labelOrange', previewType: 'labelOrange'),
    _TextStyleItem(key: 'labelGreen', previewType: 'labelGreen'),
    _TextStyleItem(key: 'labelWhite', previewType: 'labelWhite'),
    _TextStyleItem(key: 'labelCream', previewType: 'labelCream'),
  ]),
  _DesignGroup(id: 'labelSolid', labelKo: '채움', items: [
    _TextStyleItem(key: 'labelSolid', previewType: 'labelSolid'),
    _TextStyleItem(key: 'labelSolidGray', previewType: 'labelSolidGray'),
    _TextStyleItem(key: 'labelSolidPink', previewType: 'labelSolidPink'),
    _TextStyleItem(key: 'labelSolidBlue', previewType: 'labelSolidBlue'),
    _TextStyleItem(key: 'labelSolidMint', previewType: 'labelSolidMint'),
    _TextStyleItem(key: 'labelSolidLavender', previewType: 'labelSolidLavender'),
    _TextStyleItem(key: 'labelSolidOrange', previewType: 'labelSolidOrange'),
    _TextStyleItem(key: 'labelSolidGreen', previewType: 'labelSolidGreen'),
    _TextStyleItem(key: 'labelSolidCream', previewType: 'labelSolidCream'),
    _TextStyleItem(key: 'labelSolidRed', previewType: 'labelSolidRed'),
  ]),
  _DesignGroup(id: 'tag', labelKo: '태그', items: [
    _TextStyleItem(key: 'tag', previewType: 'tag'),
    _TextStyleItem(key: 'tagGray', previewType: 'tagGray'),
    _TextStyleItem(key: 'tagPink', previewType: 'tagPink'),
    _TextStyleItem(key: 'tagBlue', previewType: 'tagBlue'),
    _TextStyleItem(key: 'tagMint', previewType: 'tagMint'),
    _TextStyleItem(key: 'tagLavender', previewType: 'tagLavender'),
    _TextStyleItem(key: 'tagOrange', previewType: 'tagOrange'),
    _TextStyleItem(key: 'tagGreen', previewType: 'tagGreen'),
    _TextStyleItem(key: 'tagRed', previewType: 'tagRed'),
  ]),
  _DesignGroup(id: 'labelOutline', labelKo: '테두리', items: [
    _TextStyleItem(key: 'labelOutline', previewType: 'labelOutline'),
    _TextStyleItem(key: 'labelNeon', previewType: 'labelNeon'),
  ]),
  _DesignGroup(id: 'labelGradient', labelKo: '그라데이션', items: [
    _TextStyleItem(key: 'labelGold', previewType: 'labelGold'),
    _TextStyleItem(key: 'labelRose', previewType: 'labelRose'),
  ]),
];

/// 테이프: 단색 첫 번째, 그 다음 스트라이프·찢어진·도트 등
const List<_DesignGroup> _tapeDesignGroups = [
  _DesignGroup(id: 'tapeSolid', labelKo: '단색', items: [
    _TextStyleItem(key: 'tapeSolidGray', previewType: 'tapeSolidGray'),
    _TextStyleItem(key: 'tapeSolidPink', previewType: 'tapeSolidPink'),
    _TextStyleItem(key: 'tapeSolidBlue', previewType: 'tapeSolidBlue'),
    _TextStyleItem(key: 'tapeSolidMint', previewType: 'tapeSolidMint'),
    _TextStyleItem(key: 'tapeSolidLavender', previewType: 'tapeSolidLavender'),
    _TextStyleItem(key: 'tapeSolidOrange', previewType: 'tapeSolidOrange'),
    _TextStyleItem(key: 'tapeSolidGreen', previewType: 'tapeSolidGreen'),
    _TextStyleItem(key: 'tapeSolidWhite', previewType: 'tapeSolidWhite'),
    _TextStyleItem(key: 'tapeKraft', previewType: 'tapeKraft'),
    _TextStyleItem(key: 'tapeGold', previewType: 'tapeGold'),
  ]),
  _DesignGroup(
    id: 'tapeStripe',
    labelKo: '스트라이프',
    items: [
      _TextStyleItem(key: 'tape', previewType: 'stripe'),
      _TextStyleItem(key: 'tapeGray', previewType: 'tapeGray'),
      _TextStyleItem(key: 'tapePink', previewType: 'tapePink'),
      _TextStyleItem(key: 'tapeMint', previewType: 'tapeMint'),
      _TextStyleItem(key: 'tapeLavender', previewType: 'tapeLavender'),
      _TextStyleItem(key: 'tapeYellow', previewType: 'tapeYellow'),
    ],
  ),
  _DesignGroup(id: 'tapeTornSolid', labelKo: '찢어진', items: [
    _TextStyleItem(key: 'tapeTornSolid', previewType: 'tapeTornSolid'),
    _TextStyleItem(key: 'tapeTornSolidGray', previewType: 'tapeTornSolidGray'),
    _TextStyleItem(key: 'tapeTornSolidPink', previewType: 'tapeTornSolidPink'),
    _TextStyleItem(key: 'tapeTornSolidBlue', previewType: 'tapeTornSolidBlue'),
    _TextStyleItem(key: 'tapeTornSolidMint', previewType: 'tapeTornSolidMint'),
    _TextStyleItem(key: 'tapeTornSolidLavender', previewType: 'tapeTornSolidLavender'),
    _TextStyleItem(key: 'tapeTornSolidOrange', previewType: 'tapeTornSolidOrange'),
    _TextStyleItem(key: 'tapeTornSolidGreen', previewType: 'tapeTornSolidGreen'),
  ]),
  _DesignGroup(id: 'tapeTornRough', labelKo: '찢어진(Hard)', items: [
    _TextStyleItem(key: 'tapeTornRough', previewType: 'tapeTornRough'),
    _TextStyleItem(key: 'tapeTornRoughGray', previewType: 'tapeTornRoughGray'),
    _TextStyleItem(key: 'tapeTornRoughPink', previewType: 'tapeTornRoughPink'),
    _TextStyleItem(key: 'tapeTornRoughMint', previewType: 'tapeTornRoughMint'),
    _TextStyleItem(key: 'tapeTornRoughLavender', previewType: 'tapeTornRoughLavender'),
    _TextStyleItem(key: 'tapeTornRoughYellow', previewType: 'tapeTornRoughYellow'),
  ]),
  _DesignGroup(id: 'tapeTornSoft', labelKo: '찢어진(Soft)', items: [
    _TextStyleItem(key: 'tapeTornSoft', previewType: 'tapeTornSoft'),
    _TextStyleItem(key: 'tapeTornSoftGray', previewType: 'tapeTornSoftGray'),
    _TextStyleItem(key: 'tapeTornSoftPink', previewType: 'tapeTornSoftPink'),
    _TextStyleItem(key: 'tapeTornSoftMint', previewType: 'tapeTornSoftMint'),
    _TextStyleItem(key: 'tapeTornSoftLavender', previewType: 'tapeTornSoftLavender'),
    _TextStyleItem(key: 'tapeTornSoftYellow', previewType: 'tapeTornSoftYellow'),
  ]),
  _DesignGroup(id: 'tapeDots', labelKo: '도트', items: [
    _TextStyleItem(key: 'tapeDots', previewType: 'tapeDots'),
    _TextStyleItem(key: 'tapeDotsGray', previewType: 'tapeDotsGray'),
    _TextStyleItem(key: 'tapeDotsPink', previewType: 'tapeDotsPink'),
    _TextStyleItem(key: 'tapeDotsMint', previewType: 'tapeDotsMint'),
    _TextStyleItem(key: 'tapeDotsLavender', previewType: 'tapeDotsLavender'),
    _TextStyleItem(key: 'tapeDotsOrange', previewType: 'tapeDotsOrange'),
  ]),
  _DesignGroup(id: 'tapeDouble', labelKo: '이중 스트라이프', items: [
    _TextStyleItem(key: 'tapeDouble', previewType: 'tapeDouble'),
    _TextStyleItem(key: 'tapeDoubleGray', previewType: 'tapeDoubleGray'),
    _TextStyleItem(key: 'tapeDoublePink', previewType: 'tapeDoublePink'),
    _TextStyleItem(key: 'tapeDoubleBlue', previewType: 'tapeDoubleBlue'),
    _TextStyleItem(key: 'tapeDoubleMint', previewType: 'tapeDoubleMint'),
    _TextStyleItem(key: 'tapeDoubleLavender', previewType: 'tapeDoubleLavender'),
  ]),
];

class _TextStylePickerSheetState extends State<TextStylePickerSheet> {
  /// 색상 선택 펼침 상태 (id 일치 시 해당 그룹의 색상 목록 표시)
  String? _expandedColorGroupId;
  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    final surface = SnapFitColors.surfaceOf(context);
    // 텍스트/스티커 바텀시트는 배경이 밝기 때문에
    // 다크 모드에서도 항상 진한 글자색을 유지한다.
    final textPrimary = SnapFitColors.textPrimaryOf(context);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? SnapFitColors.accentLight.withOpacity(0.2)
                : Colors.black.withOpacity(0.12),
            blurRadius: 20.r,
            offset: Offset(0, -4.h),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 560.h,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 12.h),
              Center(
                child: Container(
                  width: 48.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: SnapFitColors.overlayMediumOf(context),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              // 헤더: 제목만
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Text(
                  '텍스트 및 스티커',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              // 섹션 리스트 (한 스크롤에 모두)
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: 24.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionWithColorPicker(
                        titleKo: '기본',
                        titleEn: 'Basic',
                        groups: _basicDesignGroups,
                        allItems: _basicStyles,
                        fullViewTitle: '기본',
                        showSeeAll: false,
                      ),
                      SizedBox(height: 24.h),
                      _buildSectionWithColorPicker(
                        titleKo: '말풍선',
                        titleEn: 'Speech Bubbles',
                        groups: _speechBubbleDesignGroups,
                        allItems: _speechBubbles,
                        fullViewTitle: '말풍선',
                      ),
                      SizedBox(height: 24.h),
                      _buildSectionWithColorPicker(
                        titleKo: '라벨 & 태그',
                        titleEn: 'Labels',
                        groups: _labelDesignGroups,
                        allItems: _labels,
                        fullViewTitle: '라벨 & 태그',
                      ),
                      SizedBox(height: 24.h),
                      _buildSectionWithColorPicker(
                        titleKo: '메모지',
                        titleEn: 'Sticky Notes',
                        groups: _noteDesignGroups,
                        allItems: _notes,
                        fullViewTitle: '메모지',
                      ),
                      SizedBox(height: 24.h),
                      _buildSectionWithColorPicker(
                        titleKo: '마스킹 테이프',
                        titleEn: 'Tapes',
                        groups: _tapeDesignGroups,
                        allItems: _tapes,
                        fullViewTitle: '마스킹 테이프',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFullView(BuildContext context, String title, List<_TextStyleItem> items) {
    Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (ctx) => _TextStyleFullViewScreen(
          title: title,
          items: items,
          selectedKey: widget.selectedKey,
          buildPreview: _buildStylePreview,
          onSelect: (key) {
            // 제스처 처리 중 pop 시 _debugLocked 오류 방지: 한 프레임 뒤에 전체 보기만 pop
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (ctx.mounted) Navigator.of(ctx).pop(key);
            });
          },
        ),
      ),
    ).then((key) {
      if (key != null && mounted) {
        widget.onSelect(key);
        // 바텀시트 pop은 그다음 프레임으로 미뤄 Navigator _debugLocked 오류 방지
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop(key);
        });
      }
    });
  }

  Widget _buildSection({
    required String titleKo,
    required String titleEn,
    required List<_TextStyleItem> items,
    bool showSeeAll = true,
    VoidCallback? onSeeAll,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$titleKo ($titleEn)',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (showSeeAll && onSeeAll != null)
                GestureDetector(
                  onTap: onSeeAll,
                  child: Text(
                    '모두 보기',
                    style: TextStyle(
                      color: SnapFitColors.accent,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 100.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => SizedBox(width: 12.w),
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = (widget.selectedKey ?? '') == item.key;
                return GestureDetector(
                  onTap: () => widget.onSelect(item.key),
                  child: Container(
                    width: 88.w,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: isSelected
                            ? SnapFitColors.accent
                            : SnapFitColors.overlayStrongOf(context),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _buildStylePreview(item.previewType),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 디자인 그룹별 카드 + 색상 선택 행 (그룹 탭 시 펼침)
  Widget _buildSectionWithColorPicker({
    required String titleKo,
    required String titleEn,
    required List<_DesignGroup> groups,
    required List<_TextStyleItem> allItems,
    required String fullViewTitle,
    bool showSeeAll = true,
  }) {
    final selectedKey = widget.selectedKey ?? '';
    _DesignGroup? expandedGroup;
    for (final g in groups) {
      if (g.id == _expandedColorGroupId) {
        expandedGroup = g;
        break;
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$titleKo ($titleEn)',
                style: TextStyle(
                  // 텍스트/스티커 바텀시트는 배경이 항상 밝으므로
                  // 라이트/다크 모드와 상관없이 진한 검정 글자색을 사용
                  color: SnapFitColors.textPrimaryOf(context),
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (showSeeAll)
                GestureDetector(
                  onTap: () => _openFullView(context, fullViewTitle, allItems),
                  child: Text(
                    '모두 보기',
                    style: TextStyle(
                      color: SnapFitColors.accent,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 100.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: groups.length,
              separatorBuilder: (_, __) => SizedBox(width: 12.w),
              itemBuilder: (context, index) {
                final group = groups[index];
                final isGroupSelected = group.items.any((e) => e.key == selectedKey);
                final isExpanded = _expandedColorGroupId == group.id;
                // 테두리는 하나만: 펼친 그룹이 있으면 펼친 그룹만 강조, 없으면 선택된 그룹만 강조
                final hasAccentBorder = _expandedColorGroupId == null
                    ? isGroupSelected
                    : isExpanded;
                final previewItem = group.items.any((e) => e.key == selectedKey)
                    ? group.items.firstWhere((e) => e.key == selectedKey)
                    : group.items.first;
                return GestureDetector(
                  onTap: () {
                    if (group.items.length == 1) {
                      widget.onSelect(group.items.first.key);
                      return;
                    }
                    setState(() {
                      _expandedColorGroupId =
                          isExpanded ? null : group.id;
                    });
                  },
                  child: Container(
                    width: 88.w,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: hasAccentBorder
                            ? SnapFitColors.accent
                            : SnapFitColors.overlayStrongOf(context),
                        width: hasAccentBorder ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Center(
                            child: _buildStylePreview(
                              previewItem.previewType,
                              colorGroupId: group.id,
                            ),
                          ),
                        ),
                        if (group.items.length > 1)
                          Padding(
                            padding: EdgeInsets.only(bottom: 6.h),
                            child: Text(
                              group.labelKo,
                              style: TextStyle(
                                fontSize: 10.sp,
                                // 항상 검정 계열 텍스트 색상 유지
                                color: Colors.black54,
                              ),
                            ),
                          )
                        else
                          SizedBox(height: 6.h),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (expandedGroup != null && expandedGroup!.items.length > 1) ...[
            SizedBox(height: 12.h),
            Padding(
              padding: EdgeInsets.only(left: 4.w),
              child: Text(
                '색상 선택',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Builder(
              builder: (context) {
                final group = expandedGroup!;
                final frame = _colorChipFrameForGroup(group.id);
                return SizedBox(
                  height: 72.h,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: group.items.length,
                    separatorBuilder: (_, __) => SizedBox(width: 10.w),
                    itemBuilder: (context, index) {
                      final item = group.items[index];
                      final isSelected = selectedKey == item.key;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _expandedColorGroupId = null);
                          widget.onSelect(item.key);
                        },
                        child: Container(
                          width: frame.width,
                          height: frame.height,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: frame.borderRadius,
                            border: Border.all(
                              color: isSelected
                                  ? SnapFitColors.accent
                                  : SnapFitColors.overlayStrongOf(context),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: SizedBox(
                              width: frame.width * 0.75,
                              height: frame.height * 0.85,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: _buildStylePreview(item.previewType, colorGroupId: group.id),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  /// 색상 선택 행에서 그룹별 칩 프레임 (모양·비율을 스타일에 맞춤)
  ({double width, double height, BorderRadius borderRadius}) _colorChipFrameForGroup(String groupId) {
    switch (groupId) {
      case 'round':
      case 'roundSoft':
        return (width: 54.w, height: 30.h, borderRadius: BorderRadius.circular(999));
      case 'square':
        return (width: 48.w, height: 32.h, borderRadius: BorderRadius.circular(4.r));
      case 'bubble':
      case 'bubbleCenter':
      case 'bubbleRight':
      case 'bubbleSquare':
      case 'bubbleSquareCenter':
      case 'bubbleSquareRight':
        return (width: 56.w, height: 36.h, borderRadius: BorderRadius.circular(14.r));
      case 'labelOval':
      case 'labelSolid':
        return (width: 52.w, height: 28.h, borderRadius: BorderRadius.circular(999));
      case 'tag':
        return (width: 46.w, height: 26.h, borderRadius: BorderRadius.circular(8.r));
      case 'noteSolid':
      case 'noteGrid':
        return (width: 50.w, height: 34.h, borderRadius: BorderRadius.circular(6.r));
      case 'tapeStripe':
      case 'tapeDots':
      case 'tapeSolid':
      case 'tapeDouble':
        return (width: 56.w, height: 28.h, borderRadius: BorderRadius.circular(6.r));
      default:
        return (width: 64.w, height: 48.h, borderRadius: BorderRadius.circular(12.r));
    }
  }

  /// 말풍선·라벨·메모지·테이프 시각 프리뷰 (바텀시트 디자인과 동일)
  /// [colorGroupId] 색상 선택 행일 때 전달하면 말풍선은 해당 그룹 꼬리 형태로 표시
  Widget _buildStylePreview(String previewType, {String? colorGroupId}) {
    final isBubbleColorStrip = colorGroupId != null &&
        (colorGroupId == 'bubble' ||
            colorGroupId == 'bubbleCenter' ||
            colorGroupId == 'bubbleRight' ||
            colorGroupId == 'bubbleSquare' ||
            colorGroupId == 'bubbleSquareCenter' ||
            colorGroupId == 'bubbleSquareRight');
    switch (previewType) {
      case 'none':
        return _previewNone();
      case 'round':
        return _previewRound();
      case 'square':
        return _previewSquare();
      case 'roundGray':
        return _previewRoundWithColor(SnapFitStylePalette.gray);
      case 'roundPink':
        return _previewRoundWithColor(SnapFitStylePalette.pink);
      case 'roundBlue':
        return _previewRoundWithColor(SnapFitStylePalette.blue);
      case 'roundMint':
        return _previewRoundWithColor(SnapFitStylePalette.mint);
      case 'roundLavender':
        return _previewRoundWithColor(SnapFitStylePalette.lavender);
      case 'roundOrange':
        return _previewRoundWithColor(SnapFitStylePalette.orange);
      case 'roundGreen':
        return _previewRoundWithColor(SnapFitStylePalette.green);
      case 'roundCream':
        return _previewRoundWithColor(SnapFitStylePalette.cream);
      case 'roundNavy':
        return _previewRoundWithColor(SnapFitStylePalette.navy);
      case 'roundRose':
        return _previewRoundWithColor(SnapFitStylePalette.rose);
      case 'roundCoral':
        return _previewRoundWithColor(SnapFitStylePalette.coral);
      case 'roundBeige':
        return _previewRoundWithColor(SnapFitStylePalette.beige);
      case 'roundTeal':
        return _previewRoundWithColor(SnapFitStylePalette.teal);
      case 'roundLemon':
        return _previewRoundWithColor(SnapFitStylePalette.lemon);
      case 'squareGray':
        return _previewSquareWithColor(SnapFitStylePalette.gray);
      case 'squarePink':
        return _previewSquareWithColor(SnapFitStylePalette.pink);
      case 'squareBlue':
        return _previewSquareWithColor(SnapFitStylePalette.blue);
      case 'squareMint':
        return _previewSquareWithColor(SnapFitStylePalette.mint);
      case 'squareLavender':
        return _previewSquareWithColor(SnapFitStylePalette.lavender);
      case 'squareOrange':
        return _previewSquareWithColor(SnapFitStylePalette.orange);
      case 'squareGreen':
        return _previewSquareWithColor(SnapFitStylePalette.green);
      case 'squareCream':
        return _previewSquareWithColor(SnapFitStylePalette.cream);
      case 'squareNavy':
        return _previewSquareWithColor(SnapFitStylePalette.navy);
      case 'squareRose':
        return _previewSquareWithColor(SnapFitStylePalette.rose);
      case 'squareCoral':
        return _previewSquareWithColor(SnapFitStylePalette.coral);
      case 'squareBeige':
        return _previewSquareWithColor(SnapFitStylePalette.beige);
      case 'squareTeal':
        return _previewSquareWithColor(SnapFitStylePalette.teal);
      case 'squareLemon':
        return _previewSquareWithColor(SnapFitStylePalette.lemon);
      case 'roundSoft':
        return _previewRoundSoft();
      case 'roundSoftGray':
        return _previewRoundSoftWithColor(SnapFitStylePalette.gray);
      case 'roundSoftPink':
        return _previewRoundSoftWithColor(SnapFitStylePalette.pink);
      case 'roundSoftBlue':
        return _previewRoundSoftWithColor(SnapFitStylePalette.blue);
      case 'roundSoftMint':
        return _previewRoundSoftWithColor(SnapFitStylePalette.mint);
      case 'roundSoftLavender':
        return _previewRoundSoftWithColor(SnapFitStylePalette.lavender);
      case 'roundSoftOrange':
        return _previewRoundSoftWithColor(SnapFitStylePalette.orange);
      case 'roundSoftGreen':
        return _previewRoundSoftWithColor(SnapFitStylePalette.green);
      case 'roundSoftCream':
        return _previewRoundSoftWithColor(SnapFitStylePalette.cream);
      case 'roundSoftNavy':
        return _previewRoundSoftWithColor(SnapFitStylePalette.navy);
      case 'roundSoftRose':
        return _previewRoundSoftWithColor(SnapFitStylePalette.rose);
      case 'roundSoftCoral':
        return _previewRoundSoftWithColor(SnapFitStylePalette.coral);
      case 'roundSoftBeige':
        return _previewRoundSoftWithColor(SnapFitStylePalette.beige);
      case 'roundSoftTeal':
        return _previewRoundSoftWithColor(SnapFitStylePalette.teal);
      case 'roundSoftLemon':
        return _previewRoundSoftWithColor(SnapFitStylePalette.lemon);
      case 'softPill2':
        return _previewSoftPill2();
      case 'softPill2Gray':
        return _previewSoftPill2WithColor(SnapFitStylePalette.gray);
      case 'softPill2Pink':
        return _previewSoftPill2WithColor(SnapFitStylePalette.pink);
      case 'softPill2Blue':
        return _previewSoftPill2WithColor(SnapFitStylePalette.blue);
      case 'softPill2Mint':
        return _previewSoftPill2WithColor(SnapFitStylePalette.mint);
      case 'softPill2Lavender':
        return _previewSoftPill2WithColor(SnapFitStylePalette.lavender);
      case 'softPill2Orange':
        return _previewSoftPill2WithColor(SnapFitStylePalette.orange);
      case 'softPill2Green':
        return _previewSoftPill2WithColor(SnapFitStylePalette.green);
      case 'softPill2Cream':
        return _previewSoftPill2WithColor(SnapFitStylePalette.cream);
      case 'softPill2Navy':
        return _previewSoftPill2WithColor(SnapFitStylePalette.navy);
      case 'softPill2Rose':
        return _previewSoftPill2WithColor(SnapFitStylePalette.rose);
      case 'softPill2Coral':
        return _previewSoftPill2WithColor(SnapFitStylePalette.coral);
      case 'softPill2Beige':
        return _previewSoftPill2WithColor(SnapFitStylePalette.beige);
      case 'softPill2Teal':
        return _previewSoftPill2WithColor(SnapFitStylePalette.teal);
      case 'softPill2Lemon':
        return _previewSoftPill2WithColor(SnapFitStylePalette.lemon);
      case 'tailLeft':
        return _previewBubbleTailLeft();
      case 'tailCenter':
        return _previewBubbleTailCenter();
      case 'tailRight':
        return _previewBubbleTailRight();
      case 'bubbleGray':
        return isBubbleColorStrip
            ? _previewBubbleWithColorAndShape(SnapFitStylePalette.gray, colorGroupId!)
            : _previewBubbleColor(SnapFitStylePalette.gray);
      case 'bubblePink':
        return isBubbleColorStrip
            ? _previewBubbleWithColorAndShape(SnapFitStylePalette.pink, colorGroupId!)
            : _previewBubbleColor(SnapFitStylePalette.pink);
      case 'bubbleBlue':
        return isBubbleColorStrip
            ? _previewBubbleWithColorAndShape(SnapFitStylePalette.blue, colorGroupId!)
            : _previewBubbleColor(SnapFitStylePalette.blue);
      case 'bubbleMint':
        return isBubbleColorStrip
            ? _previewBubbleWithColorAndShape(SnapFitStylePalette.mint, colorGroupId!)
            : _previewBubbleColor(SnapFitStylePalette.mint);
      case 'bubbleLavender':
        return isBubbleColorStrip
            ? _previewBubbleWithColorAndShape(SnapFitStylePalette.lavender, colorGroupId!)
            : _previewBubbleColor(SnapFitStylePalette.lavender);
      case 'bubbleOrange':
        return isBubbleColorStrip
            ? _previewBubbleWithColorAndShape(SnapFitStylePalette.orange, colorGroupId!)
            : _previewBubbleColor(SnapFitStylePalette.orange);
      case 'bubbleGreen':
        return isBubbleColorStrip
            ? _previewBubbleWithColorAndShape(SnapFitStylePalette.green, colorGroupId!)
            : _previewBubbleColor(SnapFitStylePalette.green);
      case 'bubbleCream':
        return isBubbleColorStrip
            ? _previewBubbleWithColorAndShape(SnapFitStylePalette.cream, colorGroupId!)
            : _previewBubbleColor(SnapFitStylePalette.cream);
      case 'bubbleNavy':
        return isBubbleColorStrip
            ? _previewBubbleWithColorAndShape(SnapFitStylePalette.navy, colorGroupId!)
            : _previewBubbleColor(SnapFitStylePalette.navy);
      case 'bubbleRose':
        return isBubbleColorStrip
            ? _previewBubbleWithColorAndShape(SnapFitStylePalette.rose, colorGroupId!)
            : _previewBubbleColor(SnapFitStylePalette.rose);
      case 'bubbleCoral':
        return isBubbleColorStrip
            ? _previewBubbleWithColorAndShape(SnapFitStylePalette.coral, colorGroupId!)
            : _previewBubbleColor(SnapFitStylePalette.coral);
      case 'bubbleBeige':
        return isBubbleColorStrip
            ? _previewBubbleWithColorAndShape(SnapFitStylePalette.beige, colorGroupId!)
            : _previewBubbleColor(SnapFitStylePalette.beige);
      case 'bubbleTeal':
        return isBubbleColorStrip
            ? _previewBubbleWithColorAndShape(SnapFitStylePalette.teal, colorGroupId!)
            : _previewBubbleColor(SnapFitStylePalette.teal);
      case 'bubbleLemon':
        return isBubbleColorStrip
            ? _previewBubbleWithColorAndShape(SnapFitStylePalette.lemon, colorGroupId!)
            : _previewBubbleColor(SnapFitStylePalette.lemon);
      case 'tailSquareLeft':
        return _previewBubbleSquareLeft();
      case 'tailSquareCenter':
        return _previewBubbleSquareCenter();
      case 'tailSquareRight':
        return _previewBubbleSquareRight();
      case 'oval':
        return _previewLabelOval();
      case 'labelGray':
        return _previewLabelOvalWithColor(const Color(0xFFEEEEEE), const Color(0xFF616161));
      case 'labelPink':
        return _previewLabelOvalWithColor(const Color(0xFFFFE4EC), const Color(0xFFAD1457));
      case 'labelBlue':
        return _previewLabelOvalWithColor(const Color(0xFFE3F2FD), const Color(0xFF1565C0));
      case 'labelMint':
        return _previewLabelOvalWithColor(const Color(0xFFE0F7F0), const Color(0xFF00695C));
      case 'labelLavender':
        return _previewLabelOvalWithColor(const Color(0xFFEDE7F6), const Color(0xFF5E35B1));
      case 'labelOrange':
        return _previewLabelOvalWithColor(const Color(0xFFFFF3E0), const Color(0xFFE65100));
      case 'labelGreen':
        return _previewLabelOvalWithColor(const Color(0xFFE8F5E9), const Color(0xFF2E7D32));
      case 'labelWhite':
        return _previewLabelOvalWithColor(const Color(0xFFFAFAFA), const Color(0xFF424242));
      case 'labelCream':
        return _previewLabelOvalWithColor(const Color(0xFFFFFBF0), const Color(0xFF5D4037));
      case 'tag':
        return _previewTagDashed();
      case 'tagGray':
        return _previewTagWithColor(const Color(0xFF9E9E9E));
      case 'tagPink':
        return _previewTagWithColor(const Color(0xFFFFB6C1));
      case 'tagBlue':
        return _previewTagWithColor(const Color(0xFF90CAF9));
      case 'tagMint':
        return _previewTagWithColor(const Color(0xFF80CBC4));
      case 'tagLavender':
        return _previewTagWithColor(const Color(0xFFB39DDB));
      case 'tagOrange':
        return _previewTagWithColor(const Color(0xFFFFCC80));
      case 'tagGreen':
        return _previewTagWithColor(const Color(0xFF81C784));
      case 'tagRed':
        return _previewTagWithColor(const Color(0xFFE57373));
      case 'labelSolid':
        return _previewLabelSolid();
      case 'labelSolidGray':
        return _previewLabelSolidWithColor(const Color(0xFF616161));
      case 'labelSolidPink':
        return _previewLabelSolidWithColor(const Color(0xFFAD1457));
      case 'labelSolidBlue':
        return _previewLabelSolidWithColor(const Color(0xFF1565C0));
      case 'labelSolidMint':
        return _previewLabelSolidWithColor(const Color(0xFF00695C));
      case 'labelSolidRed':
        return _previewLabelSolidWithColor(const Color(0xFFC62828));
      case 'labelSolidGreen':
        return _previewLabelSolidWithColor(const Color(0xFF2E7D32));
      case 'labelSolidOrange':
        return _previewLabelSolidWithColor(const Color(0xFFE65100));
      case 'labelSolidLavender':
        return _previewLabelSolidWithColor(const Color(0xFF5E35B1));
      case 'labelSolidCream':
        return _previewLabelSolidWithColor(const Color(0xFFF5F0E6));
      case 'labelOutline':
        return _previewLabelOutline();
      case 'labelGold':
        return _previewLabelGold();
      case 'labelNeon':
        return _previewLabelNeon();
      case 'labelRose':
        return _previewLabelRose();
      case 'noteYellow':
        return _previewNoteYellow();
      case 'noteBlue':
        return _previewNoteBlue();
      case 'notePink':
        return _previewNotePink();
      case 'noteMint':
        return _previewNoteMint();
      case 'noteLavender':
        return _previewNoteLavender();
      case 'noteOrange':
        return _previewNoteOrange();
      case 'noteGray':
        return _previewNoteGray();
      case 'noteBeige':
        return _previewNoteBeige();
      case 'noteTorn':
        return _previewNoteTornWithColor(const Color(0xFFFFF9C4));
      case 'noteTornGray':
        return _previewNoteTornWithColor(const Color(0xFFF0F0F0));
      case 'noteTornPink':
        return _previewNoteTornWithColor(const Color(0xFFFFEFF4));
      case 'noteTornBlue':
        return _previewNoteTornWithColor(const Color(0xFFE8F0FF));
      case 'noteTornMint':
        return _previewNoteTornWithColor(const Color(0xFFE0F7F0));
      case 'noteTornLavender':
        return _previewNoteTornWithColor(const Color(0xFFF3E8FF));
      case 'noteTornOrange':
        return _previewNoteTornWithColor(const Color(0xFFFFF0E0));
      case 'noteTornCream':
        return _previewNoteTornWithColor(const Color(0xFFFFFBF0));
      case 'noteTornBeige':
        return _previewNoteTornWithColor(const Color(0xFFF5F0E8));
      case 'noteTornYellow':
        return _previewNoteTornWithColor(const Color(0xFFFFF9C4));
      case 'noteTornGold':
        return _previewNoteTornWithColor(const Color(0xFFFFF8E1));
      case 'noteTornRough':
        return _previewNoteTornWithColor(const Color(0xFFFFF9C4));
      case 'noteTornRoughGray':
        return _previewNoteTornWithColor(const Color(0xFFF0F0F0));
      case 'noteTornRoughPink':
        return _previewNoteTornWithColor(const Color(0xFFFFEFF4));
      case 'noteTornRoughBlue':
        return _previewNoteTornWithColor(const Color(0xFFE8F0FF));
      case 'noteTornRoughMint':
        return _previewNoteTornWithColor(const Color(0xFFE0F7F0));
      case 'noteTornRoughLavender':
        return _previewNoteTornWithColor(const Color(0xFFF3E8FF));
      case 'noteTornRoughOrange':
        return _previewNoteTornWithColor(const Color(0xFFFFF0E0));
      case 'noteTornRoughCream':
        return _previewNoteTornWithColor(const Color(0xFFFFFBF0));
      case 'noteTornRoughBeige':
        return _previewNoteTornWithColor(const Color(0xFFF5F0E8));
      case 'noteTornRoughYellow':
        return _previewNoteTornWithColor(const Color(0xFFFFF9C4));
      case 'noteTornRoughGold':
        return _previewNoteTornWithColor(const Color(0xFFFFF8E1));
      case 'noteTornSoft':
        return _previewNoteTornWithColor(const Color(0xFFFFF9C4));
      case 'noteTornSoftGray':
        return _previewNoteTornWithColor(const Color(0xFFF0F0F0));
      case 'noteTornSoftPink':
        return _previewNoteTornWithColor(const Color(0xFFFFEFF4));
      case 'noteTornSoftBlue':
        return _previewNoteTornWithColor(const Color(0xFFE8F0FF));
      case 'noteTornSoftMint':
        return _previewNoteTornWithColor(const Color(0xFFE0F7F0));
      case 'noteTornSoftLavender':
        return _previewNoteTornWithColor(const Color(0xFFF3E8FF));
      case 'noteTornSoftOrange':
        return _previewNoteTornWithColor(const Color(0xFFFFF0E0));
      case 'noteTornSoftCream':
        return _previewNoteTornWithColor(const Color(0xFFFFFBF0));
      case 'noteTornSoftBeige':
        return _previewNoteTornWithColor(const Color(0xFFF5F0E8));
      case 'noteTornSoftYellow':
        return _previewNoteTornWithColor(const Color(0xFFFFF9C4));
      case 'noteTornSoftGold':
        return _previewNoteTornWithColor(const Color(0xFFFFF8E1));
      case 'tapeTorn':
        return _previewTapeTornSolidWithColor(const Color(0xFFFAFAFA));
      case 'tapeTornGray':
        return _previewTapeTornSolidWithColor(const Color(0xFFE0E0E0));
      case 'tapeTornPink':
        return _previewTapeTornSolidWithColor(const Color(0xFFFFCDD2));
      case 'tapeTornMint':
        return _previewTapeTornSolidWithColor(const Color(0xFFB2DFDB));
      case 'tapeTornLavender':
        return _previewTapeTornSolidWithColor(const Color(0xFFD1C4E9));
      case 'tapeTornYellow':
        return _previewTapeTornSolidWithColor(const Color(0xFFFFE0B2));
      case 'tapeTornRough':
        return _previewTapeTornSolidWithColor(const Color(0xFFFAFAFA));
      case 'tapeTornRoughGray':
        return _previewTapeTornSolidWithColor(const Color(0xFFE0E0E0));
      case 'tapeTornRoughPink':
        return _previewTapeTornSolidWithColor(const Color(0xFFFFCDD2));
      case 'tapeTornRoughMint':
        return _previewTapeTornSolidWithColor(const Color(0xFFB2DFDB));
      case 'tapeTornRoughLavender':
        return _previewTapeTornSolidWithColor(const Color(0xFFD1C4E9));
      case 'tapeTornRoughYellow':
        return _previewTapeTornSolidWithColor(const Color(0xFFFFE0B2));
      case 'tapeTornSoft':
        return _previewTapeTornSolidWithColor(const Color(0xFFFAFAFA));
      case 'tapeTornSoftGray':
        return _previewTapeTornSolidWithColor(const Color(0xFFE0E0E0));
      case 'tapeTornSoftPink':
        return _previewTapeTornSolidWithColor(const Color(0xFFFFCDD2));
      case 'tapeTornSoftMint':
        return _previewTapeTornSolidWithColor(const Color(0xFFB2DFDB));
      case 'tapeTornSoftLavender':
        return _previewTapeTornSolidWithColor(const Color(0xFFD1C4E9));
      case 'tapeTornSoftYellow':
        return _previewTapeTornSolidWithColor(const Color(0xFFFFE0B2));
      case 'tapeTornSolid':
        return _previewTapeTornSolidWithColor(const Color(0xFFFAFAFA));
      case 'tapeTornSolidGray':
        return _previewTapeTornSolidWithColor(const Color(0xFFE0E0E0));
      case 'tapeTornSolidPink':
        return _previewTapeTornSolidWithColor(const Color(0xFFFFCDD2));
      case 'tapeTornSolidBlue':
        return _previewTapeTornSolidWithColor(const Color(0xFFBBDEFB));
      case 'tapeTornSolidMint':
        return _previewTapeTornSolidWithColor(const Color(0xFFB2DFDB));
      case 'tapeTornSolidLavender':
        return _previewTapeTornSolidWithColor(const Color(0xFFD1C4E9));
      case 'tapeTornSolidOrange':
        return _previewTapeTornSolidWithColor(const Color(0xFFFFE0B2));
      case 'tapeTornSolidGreen':
        return _previewTapeTornSolidWithColor(const Color(0xFFC8E6C9));
      case 'stripe':
        return _previewTapeStripeWithColor(SnapFitStylePalette.stripeSkyBase, SnapFitStylePalette.stripeSkyStripe);
      case 'tapeYellow':
        return _previewTapeStripeWithColor(SnapFitStylePalette.stripeYellowBase, SnapFitStylePalette.stripeYellowStripe);
      case 'tapePink':
        return _previewTapeStripeWithColor(SnapFitStylePalette.stripePinkBase, SnapFitStylePalette.stripePinkStripe);
      case 'tapeMint':
        return _previewTapeStripeWithColor(SnapFitStylePalette.stripeMintBase, SnapFitStylePalette.stripeMintStripe);
      case 'tapeLavender':
        return _previewTapeStripeWithColor(SnapFitStylePalette.stripeLavenderBase, SnapFitStylePalette.stripeLavenderStripe);
      case 'tapeGray':
        return _previewTapeStripeWithColor(SnapFitStylePalette.stripeGrayBase, SnapFitStylePalette.stripeGrayStripe);
      case 'tapeDots':
        return _previewTapeDots();
      case 'tapeDotsPink':
        return _previewTapeDotsWithColor(const Color(0xFFFFE4EC), const Color(0xFFFFB6C1));
      case 'tapeDotsMint':
        return _previewTapeDotsWithColor(const Color(0xFFE0F7F0), const Color(0xFF80CBC4));
      case 'tapeDotsLavender':
        return _previewTapeDotsWithColor(SnapFitStylePalette.lavender, SnapFitStylePalette.tagLavender);
      case 'tapeDotsOrange':
        return _previewTapeDotsWithColor(SnapFitStylePalette.orange, SnapFitStylePalette.tagOrange);
      case 'tapeDotsGray':
        return _previewTapeDotsWithColor(SnapFitStylePalette.stripeGrayBase, SnapFitStylePalette.stripeGrayStripe);
      case 'tapeKraft':
        return _previewTapeKraft();
      case 'tapeGold':
        return _previewTapeGold();
      case 'tapeSolidWhite':
        return _previewTapeSolidWithColor(const Color(0xFFFAFAFA));
      case 'tapeSolidGray':
        return _previewTapeSolidWithColor(const Color(0xFFE0E0E0));
      case 'tapeSolidPink':
        return _previewTapeSolidWithColor(const Color(0xFFFFCDD2));
      case 'tapeSolidBlue':
        return _previewTapeSolidWithColor(const Color(0xFFBBDEFB));
      case 'tapeSolidMint':
        return _previewTapeSolidWithColor(const Color(0xFFB2DFDB));
      case 'tapeSolidLavender':
        return _previewTapeSolidWithColor(const Color(0xFFD1C4E9));
      case 'tapeSolidOrange':
        return _previewTapeSolidWithColor(const Color(0xFFFFE0B2));
      case 'tapeSolidGreen':
        return _previewTapeSolidWithColor(const Color(0xFFC8E6C9));
      case 'tapeDouble':
        return _previewTapeDouble();
      case 'tapeDoublePink':
        return _previewTapeDoubleWithColor(const Color(0xFFFFEFF4), const Color(0xFFFFCDD2));
      case 'tapeDoubleMint':
        return _previewTapeDoubleWithColor(SnapFitStylePalette.mint, const Color(0xFFA7FFEB));
      case 'tapeDoubleBlue':
        return _previewTapeDoubleWithColor(const Color(0xFFE3F2FD), const Color(0xFF90CAF9));
      case 'tapeDoubleLavender':
        return _previewTapeDoubleWithColor(SnapFitStylePalette.lavender, SnapFitStylePalette.tagLavender);
      case 'tapeDoubleGray':
        return _previewTapeDoubleWithColor(SnapFitStylePalette.stripeGrayBase, SnapFitStylePalette.stripeGrayStripe);
      case 'highlightYellow':
        return _previewHighlightYellow();
      case 'highlightGreen':
        return _previewHighlightGreen();
      case 'highlightPink':
        return _previewHighlightPink();
      case 'stampRed':
        return _previewStampRed();
      case 'stampBlue':
        return _previewStampBlue();
      case 'quote':
        return _previewQuote();
      case 'chalkboard':
        return _previewChalkboard();
      case 'caption':
        return _previewCaption();
      case 'noteGrid':
        return _previewNoteGrid();
      case 'noteGridBlue':
        return _previewNoteGridWithColor(SnapFitStylePalette.blue, const Color(0xFFBBDEFB));
      case 'noteGridPink':
        return _previewNoteGridWithColor(SnapFitStylePalette.pink, const Color(0xFFFFCDD2));
      case 'noteGridMint':
        return _previewNoteGridWithColor(SnapFitStylePalette.mint, const Color(0xFF80CBC4));
      case 'noteGridLavender':
        return _previewNoteGridWithColor(SnapFitStylePalette.lavender, const Color(0xFFB39DDB));
      case 'noteGridOrange':
        return _previewNoteGridWithColor(SnapFitStylePalette.orange, const Color(0xFFFFCC80));
      case 'noteGridGray':
        return _previewNoteGridWithColor(SnapFitStylePalette.gray, const Color(0xFFBDBDBD));
      case 'noteGold':
        return _previewNoteGold();
      case 'noteCream':
        return _previewNoteCream();
      default:
        // 바텀시트 프리뷰 아이콘은 라이트/다크 모드 모두 회색 계열로 고정
        return Icon(Icons.text_fields, size: 28.r, color: Colors.black45);
    }
  }

  /// 기본 없음 – 테두리/색 없음
  Widget _previewNone() {
    return Icon(Icons.text_fields, size: 28.r, color: Colors.black45);
  }

  /// 라운드 – 흰색 pill (바텀시트 디자인)
  Widget _previewRound() {
    return Container(
      width: 56.w,
      height: 28.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: const Color(0xFFE0E4EC), width: 1),
      ),
    );
  }

  /// 기본 – 사각형
  Widget _previewSquare() {
    return Container(
      width: 56.w,
      height: 28.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: const Color(0xFFE0E4EC), width: 1),
      ),
    );
  }

  /// 기본 – 소프트 필 (그림자 효과)
  Widget _previewRoundSoft() {
    return Container(
      width: 56.w,
      height: 28.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 3)),
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 3, offset: const Offset(0, 1)),
        ],
      ),
    );
  }

  Widget _previewRoundWithColor(Color bg) {
    return Container(
      width: 56.w,
      height: 28.h,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: bg == Colors.white ? const Color(0xFFE8EAED) : (Color.lerp(bg, Colors.black, 0.08) ?? bg), width: 1),
      ),
    );
  }

  Widget _previewSquareWithColor(Color bg) {
    return Container(
      width: 56.w,
      height: 28.h,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: bg == Colors.white ? const Color(0xFFE0E4EC) : (Color.lerp(bg, Colors.black, 0.08) ?? bg), width: 1),
      ),
    );
  }

  Widget _previewRoundSoftWithColor(Color bg) {
    return Container(
      width: 56.w,
      height: 28.h,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 3)),
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 3, offset: const Offset(0, 1)),
        ],
      ),
    );
  }

  /// 소프트 필2 미리보기 (사각형, 라운드 없음)
  Widget _previewSoftPill2() {
    return _previewSoftPill2WithColor(Colors.white);
  }

  Widget _previewSoftPill2WithColor(Color bg) {
    return Container(
      width: 56.w,
      height: 28.h,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.zero,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 3)),
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 3, offset: const Offset(0, 1)),
        ],
      ),
    );
  }

  /// 라벨 – 타원 색상 변형 (통일된 pill)
  Widget _previewLabelOvalWithColor(Color bg, Color text) {
    return Container(
      width: 56.w,
      height: 26.h,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999.r),
      ),
    );
  }

  /// 라벨 – 채움 (미리보기 통일: pill 하나, 색만 다름)
  Widget _previewLabelSolid() {
    return _previewLabelSolidWithColor(const Color(0xFF1E3A5F));
  }

  /// 라벨 – 채움 색상 변형 (통일된 pill)
  Widget _previewLabelSolidWithColor(Color bg) {
    return Container(
      width: 64.w,
      height: 26.h,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999.r),
      ),
    );
  }

  /// 태그 – 점선 색상 변형 (통일된 점선 pill)
  Widget _previewTagWithColor(Color borderColor) {
    return SizedBox(
      width: 56.w,
      height: 26.h,
      child: CustomPaint(
        painter: _DashedRectPainter(
          color: borderColor,
          strokeWidth: 1.5,
          borderRadius: 8.r,
          dashWidth: 4,
          dashSpace: 3,
        ),
      ),
    );
  }

  /// 라벨 – 아웃라인만 (TODAY 스타일)
  Widget _previewLabelOutline() {
    return Container(
      width: 52.w,
      height: 26.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: SnapFitColors.accent, width: 1.5),
      ),
    );
  }

  /// 라벨 – 골드
  Widget _previewLabelGold() {
    return Container(
      width: 52.w,
      height: 28.h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFFF5E6C8), const Color(0xFFE8D4A8)],
        ),
        borderRadius: BorderRadius.circular(999.r),
      ),
    );
  }

  /// 라벨 – 네온
  Widget _previewLabelNeon() {
    return Container(
      width: 52.w,
      height: 26.h,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: const Color(0xFF00E5FF), width: 2),
      ),
    );
  }

  /// 라벨 – 로즈
  Widget _previewLabelRose() {
    return Container(
      width: 52.w,
      height: 28.h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFFF8BBD9), const Color(0xFFF48FB1)],
        ),
        borderRadius: BorderRadius.circular(999.r),
      ),
    );
  }

  /// 메모지 민트
  Widget _previewNoteMint() {
    return Container(
      width: 52.w,
      height: 36.h,
      decoration: BoxDecoration(
        color: const Color(0xFFE0F7F0),
        borderRadius: BorderRadius.zero,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 2, offset: const Offset(0, 1))],
      ),
    );
  }

  /// 메모지 라벤더
  Widget _previewNoteLavender() {
    return Container(
      width: 52.w,
      height: 36.h,
      decoration: BoxDecoration(
        color: const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.zero,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 2, offset: const Offset(0, 1))],
      ),
    );
  }

  /// 메모지 오렌지
  Widget _previewNoteOrange() {
    return Container(
      width: 52.w,
      height: 36.h,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0E0),
        borderRadius: BorderRadius.zero,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 2, offset: const Offset(0, 1))],
      ),
    );
  }

  /// 메모지 그레이
  Widget _previewNoteGray() {
    return Container(
      width: 52.w,
      height: 36.h,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.zero,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 2, offset: const Offset(0, 1))],
      ),
    );
  }

  /// 메모지 베이지
  Widget _previewNoteBeige() {
    return Container(
      width: 52.w,
      height: 36.h,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E8),
        borderRadius: BorderRadius.zero,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 2, offset: const Offset(0, 1))],
      ),
    );
  }

  /// 테이프 도트
  Widget _previewTapeDots() {
    return Container(
      width: 60.w,
      height: 28.h,
      decoration: BoxDecoration(
        color: const Color(0xFFFFE0B2),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: CustomPaint(
        painter: _PreviewDotsPainter(dotColor: const Color(0xFFFFCC80)),
      ),
    );
  }

  /// 테이프 도트 색상 변형
  Widget _previewTapeDotsWithColor(Color base, Color dot) {
    return Container(
      width: 60.w,
      height: 28.h,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: CustomPaint(
        painter: _PreviewDotsPainter(dotColor: dot),
      ),
    );
  }

  /// 테이프 크래프트 (단색 통일, 팔레트)
  Widget _previewTapeKraft() {
    return _previewTapeSolidWithColor(SnapFitStylePalette.tapeKraft);
  }

  /// 테이프 골드 (단색 통일, 팔레트)
  Widget _previewTapeGold() {
    return _previewTapeSolidWithColor(SnapFitStylePalette.tapeGold);
  }

  /// 테이프 단색 색상 변형 (크래프트·골드 통일)
  Widget _previewTapeSolidWithColor(Color bg) {
    return Container(
      width: 60.w,
      height: 28.h,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4.r),
      ),
    );
  }

  /// 테이프 이중 스트라이프
  Widget _previewTapeDouble() {
    return Container(
      width: 60.w,
      height: 28.h,
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: CustomPaint(
        painter: _PreviewDoubleStripePainter(),
      ),
    );
  }

  /// 테이프 이중 스트라이프 색상 변형
  Widget _previewTapeDoubleWithColor(Color base, Color stripe) {
    return Container(
      width: 60.w,
      height: 28.h,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: CustomPaint(
        painter: _PreviewDoubleStripePainter(baseColor: base, stripeColor: stripe),
      ),
    );
  }

  /// 하이라이터 노랑
  Widget _previewHighlightYellow() {
    return Container(
      width: 56.w,
      height: 24.h,
      decoration: BoxDecoration(
        color: const Color(0xFFFFEB3B).withOpacity(0.55),
        borderRadius: BorderRadius.zero,
      ),
    );
  }

  /// 하이라이터 초록
  Widget _previewHighlightGreen() {
    return Container(
      width: 56.w,
      height: 24.h,
      decoration: BoxDecoration(
        color: const Color(0xFFB8E986).withOpacity(0.65),
        borderRadius: BorderRadius.zero,
      ),
    );
  }

  /// 하이라이터 핑크
  Widget _previewHighlightPink() {
    return Container(
      width: 56.w,
      height: 24.h,
      decoration: BoxDecoration(
        color: const Color(0xFFFFB6C1).withOpacity(0.7),
        borderRadius: BorderRadius.zero,
      ),
    );
  }

  /// 스탬프 빨강
  Widget _previewStampRed() {
    return Container(
      width: 52.w,
      height: 26.h,
      decoration: BoxDecoration(
        color: const Color(0xFFC62828),
        borderRadius: BorderRadius.circular(6.r),
      ),
    );
  }

  /// 스탬프 파랑
  Widget _previewStampBlue() {
    return Container(
      width: 52.w,
      height: 26.h,
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0),
        borderRadius: BorderRadius.circular(6.r),
      ),
    );
  }

  /// 인용 데코
  Widget _previewQuote() {
    return Container(
      width: 56.w,
      height: 28.h,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8.r),
        border: Border(
          left: BorderSide(color: SnapFitColors.accent, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: SnapFitColors.accent.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(2, 0),
          ),
        ],
      ),
    );
  }

  /// 칠판 포인트
  Widget _previewChalkboard() {
    return Container(
      width: 56.w,
      height: 28.h,
      decoration: BoxDecoration(
        color: const Color(0xFF263238),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: const Color(0xFF546E7A), width: 1.5),
      ),
    );
  }

  /// 점선 프레임 캡션
  Widget _previewCaption() {
    return SizedBox(
      width: 56.w,
      height: 28.h,
      child: Stack(
        children: [
          Container(
            width: 56.w,
            height: 28.h,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _DashedRectPainter(
                color: const Color(0xFFB0BEC5),
                strokeWidth: 1.5,
                borderRadius: 10.r,
                dashWidth: 5,
                dashSpace: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 격자 노트
  Widget _previewNoteGrid() {
    return Container(
      width: 52.w,
      height: 36.h,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDE7),
        borderRadius: BorderRadius.zero,
      ),
      child: CustomPaint(
        painter: _PreviewGridPainter(color: const Color(0xFFE8E0B0)),
      ),
    );
  }

  /// 격자 노트 색상 변형
  Widget _previewNoteGridWithColor(Color bg, Color grid) {
    return Container(
      width: 52.w,
      height: 36.h,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.zero,
      ),
      child: CustomPaint(
        painter: _PreviewGridPainter(color: grid),
      ),
    );
  }

  /// 메모지 골드
  Widget _previewNoteGold() {
    return Container(
      width: 52.w,
      height: 36.h,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.zero,
      ),
    );
  }

  /// 메모지 크림
  Widget _previewNoteCream() {
    return Container(
      width: 52.w,
      height: 36.h,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.zero,
      ),
    );
  }

  /// 찢어진 메모지 미리보기 (아래만 톱니 – 종이 뜯은 느낌)
  Widget _previewNoteTornWithColor(Color color) {
    return SizedBox(
      width: 52.w,
      height: 36.h,
      child: ClipPath(
        clipper: _TornNotePreviewClipper(),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 끝짤림 스트라이프 테이프 미리보기 (기본색)
  Widget _previewTapeTornStripe() {
    return _previewTapeTornStripeWithColor(
      SnapFitStylePalette.stripeSkyBase,
      SnapFitStylePalette.stripeSkyStripe,
    );
  }

  /// 끝짤림 스트라이프 테이프 미리보기 (오른쪽 비스듬 절단)
  Widget _previewTapeTornStripeWithColor(Color baseColor, Color stripeColor) {
    return SizedBox(
      width: 54.w,
      height: 30.h,
      child: ClipPath(
        clipper: _TapeTornPreviewClipper(),
        child: CustomPaint(
          painter: _StripeTapePainter(baseColor: baseColor, stripeColor: stripeColor),
          size: Size(54.w, 30.h),
        ),
      ),
    );
  }

  /// 끝짤림 단색 테이프 미리보기 (오른쪽 비스듬 절단)
  Widget _previewTapeTornSolidWithColor(Color color) {
    return SizedBox(
      width: 54.w,
      height: 30.h,
      child: ClipPath(
        clipper: _TapeTornPreviewClipper(),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 말풍선 – 꼬리 왼쪽 하단 (가장자리에서 살짝 안쪽)
  Widget _previewBubbleTailLeft() {
    return SizedBox(
      width: 48.w,
      height: 32.h,
      child: CustomPaint(
        painter: _SpeechBubblePreviewPainter(tailPosition: 0.28),
      ),
    );
  }

  /// 말풍선 – 꼬리 하단 중앙
  Widget _previewBubbleTailCenter() {
    return SizedBox(
      width: 48.w,
      height: 32.h,
      child: CustomPaint(
        painter: _SpeechBubblePreviewPainter(tailPosition: 0.5),
      ),
    );
  }

  /// 말풍선 – 꼬리 하단 오른쪽 (가장자리에서 살짝 안쪽)
  Widget _previewBubbleTailRight() {
    return SizedBox(
      width: 48.w,
      height: 32.h,
      child: CustomPaint(
        painter: _SpeechBubblePreviewPainter(tailPosition: 0.72),
      ),
    );
  }

  /// 말풍선 – 사각형, 꼬리 왼쪽
  Widget _previewBubbleSquareLeft() {
    return SizedBox(
      width: 48.w,
      height: 32.h,
      child: CustomPaint(
        painter: _SquareBubblePreviewPainter(tailPosition: 0.0),
      ),
    );
  }

  /// 말풍선 – 사각형, 꼬리 가운데
  Widget _previewBubbleSquareCenter() {
    return SizedBox(
      width: 48.w,
      height: 32.h,
      child: CustomPaint(
        painter: _SquareBubblePreviewPainter(tailPosition: 0.5),
      ),
    );
  }

  /// 말풍선 – 사각형, 꼬리 오른쪽
  Widget _previewBubbleSquareRight() {
    return SizedBox(
      width: 48.w,
      height: 32.h,
      child: CustomPaint(
        painter: _SquareBubblePreviewPainter(tailPosition: 1.0),
      ),
    );
  }

  /// 말풍선 색상 프리뷰 (단순 pill — 그룹 모를 때)
  Widget _previewBubbleColor(Color color) {
    return Container(
      width: 48.w,
      height: 28.h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Color.lerp(color, Colors.black, 0.1) ?? color, width: 1),
      ),
    );
  }

  /// 말풍선 색상 + 꼬리 형태 (색상 선택 행에서 그룹별 꼬리 표시)
  Widget _previewBubbleWithColorAndShape(Color color, String groupId) {
    final isSquare = groupId == 'bubbleSquare' || groupId == 'bubbleSquareCenter' || groupId == 'bubbleSquareRight';
    final tailPos = groupId == 'bubble' ? 0.28
        : groupId == 'bubbleCenter' ? 0.5
        : groupId == 'bubbleRight' ? 0.72
        : groupId == 'bubbleSquare' ? 0.0
        : groupId == 'bubbleSquareCenter' ? 0.5
        : 1.0; // bubbleSquareRight
    final borderColor = Color.lerp(color, Colors.black, 0.12) ?? color;
    return SizedBox(
      width: 48.w,
      height: 32.h,
      child: isSquare
          ? CustomPaint(
              painter: _SquareBubblePreviewPainterWithColor(
                fillColor: color,
                borderColor: borderColor,
                tailPosition: tailPos,
              ),
            )
          : CustomPaint(
              painter: _SpeechBubblePreviewPainterWithColor(
                fillColor: color,
                borderColor: borderColor,
                tailPosition: tailPos,
              ),
            ),
    );
  }

  /// 라벨 – 타원형 (미리보기 통일: pill 하나, 색만 다름)
  Widget _previewLabelOval() {
    return _previewLabelOvalWithColor(
      SnapFitColors.accent.withOpacity(0.25),
      SnapFitColors.accent,
    );
  }

  /// 태그 – 점선 테두리 (미리보기 통일: 점선 pill, 색만 다름)
  Widget _previewTagDashed() {
    return _previewTagWithColor(const Color(0xFFB0B0B0));
  }

  /// 메모지 – 연한 노랑 + 접힌 모서리
  Widget _previewNoteYellow() {
    return Container(
      width: 52.w,
      height: 36.h,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCE7),
        borderRadius: BorderRadius.zero,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: CustomPaint(
              size: Size(16.w, 16.h),
              painter: _FoldedCornerPainter(color: const Color(0xFFE8E0C0)),
            ),
          ),
        ],
      ),
    );
  }

  /// 메모지 – 연한 파랑
  Widget _previewNoteBlue() {
    return Container(
      width: 52.w,
      height: 36.h,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FF),
        borderRadius: BorderRadius.zero,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }

  /// 메모지 – 연한 분홍 + 핀
  Widget _previewNotePink() {
    return Container(
      width: 52.w,
      height: 36.h,
      decoration: BoxDecoration(
        color: const Color(0xFFFFEFF4),
        borderRadius: BorderRadius.zero,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.push_pin_outlined,
          size: 18.r,
          color: const Color(0xFFE0A0B0),
        ),
      ),
    );
  }

  /// 마스킹 테이프 – 사선 스트라이프 (기본 하늘색)
  Widget _previewTapeStripe() {
    return _previewTapeStripeWithColor(SnapFitStylePalette.stripeSkyBase, SnapFitStylePalette.stripeSkyStripe);
  }

  /// 마스킹 테이프 – 사선 스트라이프 색상 변형 (미리보기에서 스트라이프 패턴 표시)
  Widget _previewTapeStripeWithColor(Color baseColor, Color stripeColor) {
    return Container(
      width: 60.w,
      height: 28.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4.r),
        child: CustomPaint(
          painter: _StripeTapePainter(baseColor: baseColor, stripeColor: stripeColor),
        ),
      ),
    );
  }
}

/// 스타일 전체보기 화면 (그리드로 모두 표시)
class _TextStyleFullViewScreen extends StatelessWidget {
  final String title;
  final List<_TextStyleItem> items;
  final String? selectedKey;
  final Widget Function(String previewType) buildPreview;
  final ValueChanged<String> onSelect;

  const _TextStyleFullViewScreen({
    required this.title,
    required this.items,
    required this.selectedKey,
    required this.buildPreview,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    final surface = SnapFitColors.surfaceOf(context);
    const textPrimary = Colors.black87;
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 22.r, color: textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: textPrimary,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16.h,
              crossAxisSpacing: 16.w,
              childAspectRatio: 0.85,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isSelected = (selectedKey ?? '') == item.key;
              return GestureDetector(
                onTap: () => onSelect(item.key),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? SnapFitColors.overlayLightOf(context) : Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: isSelected
                          ? SnapFitColors.accent
                          : SnapFitColors.overlayStrongOf(context),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: buildPreview(item.previewType),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 프리뷰용 도트 패턴
class _PreviewDotsPainter extends CustomPainter {
  final Color dotColor;

  _PreviewDotsPainter({required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dotColor;
    const spacing = 8.0;
    const r = 2.0;
    for (var x = spacing; x < size.width; x += spacing) {
      for (var y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 프리뷰용 리본 클리퍼
class _PreviewRibbonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const cut = 10.0;
    return Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width - cut, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(cut, size.height)
      ..lineTo(0, size.height / 2)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// 프리뷰용 격자 (전체 채움 + 테두리)
class _PreviewGridPainter extends CustomPainter {
  final Color color;

  _PreviewGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    const step = 10.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 프리뷰용 이중 대각 스트라이프 (테이프)
class _PreviewDoubleStripePainter extends CustomPainter {
  final Color? baseColor;
  final Color? stripeColor;

  _PreviewDoubleStripePainter({this.baseColor, this.stripeColor});

  @override
  void paint(Canvas canvas, Size size) {
    const stripeWidth = 12.0;
    const gap = 8.0;
    final stripe = stripeColor ?? const Color(0xFF90CAF9);
    final stripePaint = Paint()
      ..color = stripe.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    final path = Path();
    for (var d = -size.height - size.width; d < size.width + size.height * 2; d += stripeWidth + gap) {
      path.moveTo(d.toDouble(), -10);
      path.lineTo(d + stripeWidth, -10);
      path.lineTo(d + stripeWidth + size.height, size.height + 10);
      path.lineTo(d + size.height, size.height + 10);
      path.close();
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, stripePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 말풍선 프리뷰 (꼬리 위치 0~1, 가장자리에서 살짝 안쪽으로)
class _SpeechBubblePreviewPainter extends CustomPainter {
  final double tailPosition;

  _SpeechBubblePreviewPainter({this.tailPosition = 0.5});

  static const double _previewTailMargin = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height * 0.4;
    final tailW = size.width * 0.18;
    final tailH = size.height * 0.35;
    final minX = _previewTailMargin + tailW / 2;
    final maxX = size.width - _previewTailMargin - tailW / 2;
    final tailX = (size.width * tailPosition).clamp(minX, maxX);

    final path = Path();
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height - tailH),
      Radius.circular(r),
    ));
    path.moveTo(tailX - tailW / 2, size.height - tailH);
    path.lineTo(tailX, size.height);
    path.lineTo(tailX + tailW / 2, size.height - tailH);
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 말풍선 프리뷰 + 채움색 (색상 선택 시 꼬리 포함)
class _SpeechBubblePreviewPainterWithColor extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final double tailPosition;

  _SpeechBubblePreviewPainterWithColor({
    required this.fillColor,
    required this.borderColor,
    this.tailPosition = 0.5,
  });

  static const double _previewTailMargin = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height * 0.4;
    final tailW = size.width * 0.18;
    final tailH = size.height * 0.35;
    final minX = _previewTailMargin + tailW / 2;
    final maxX = size.width - _previewTailMargin - tailW / 2;
    final tailX = (size.width * tailPosition).clamp(minX, maxX);

    final path = Path();
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height - tailH),
      Radius.circular(r),
    ));
    path.moveTo(tailX - tailW / 2, size.height - tailH);
    path.lineTo(tailX, size.height);
    path.lineTo(tailX + tailW / 2, size.height - tailH);
    path.close();

    canvas.drawPath(path, Paint()..color = fillColor..style = PaintingStyle.fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 사각형 말풍선 프리뷰 – 꼬리 왼/가운데/오른, 가장자리에서 살짝 안쪽
class _SquareBubblePreviewPainter extends CustomPainter {
  final double tailPosition;

  _SquareBubblePreviewPainter({this.tailPosition = 0.5});

  static const double _tailW = 7.0;
  static const double _tailH = 5.0;
  static const double _margin = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyH = h - _tailH;
    final tailCenterX = tailPosition <= 0.25
        ? _margin + _tailW / 2
        : tailPosition >= 0.75
            ? w - _margin - _tailW / 2
            : w / 2;
    final tailLeft = tailCenterX - _tailW / 2;
    final tailRight = tailCenterX + _tailW / 2;

    final path = Path();
    path.moveTo(tailLeft, bodyH);
    path.lineTo(0, bodyH);
    path.lineTo(0, 0);
    path.lineTo(w, 0);
    path.lineTo(w, bodyH);
    path.lineTo(tailRight, bodyH);
    path.lineTo(tailCenterX, h);
    path.lineTo(tailLeft, bodyH);
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 사각 말풍선 프리뷰 + 채움색 (색상 선택 시 꼬리 포함)
class _SquareBubblePreviewPainterWithColor extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final double tailPosition;

  _SquareBubblePreviewPainterWithColor({
    required this.fillColor,
    required this.borderColor,
    this.tailPosition = 0.5,
  });

  static const double _tailW = 7.0;
  static const double _tailH = 5.0;
  static const double _margin = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyH = h - _tailH;
    final tailCenterX = tailPosition <= 0.25
        ? _margin + _tailW / 2
        : tailPosition >= 0.75
            ? w - _margin - _tailW / 2
            : w / 2;
    final tailLeft = tailCenterX - _tailW / 2;
    final tailRight = tailCenterX + _tailW / 2;

    final path = Path();
    path.moveTo(tailLeft, bodyH);
    path.lineTo(0, bodyH);
    path.lineTo(0, 0);
    path.lineTo(w, 0);
    path.lineTo(w, bodyH);
    path.lineTo(tailRight, bodyH);
    path.lineTo(tailCenterX, h);
    path.lineTo(tailLeft, bodyH);
    path.close();

    canvas.drawPath(path, Paint()..color = fillColor..style = PaintingStyle.fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 접힌 모서리
class _FoldedCornerPainter extends CustomPainter {
  final Color color;

  _FoldedCornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = color,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, 0),
      Paint()
        ..color = const Color(0xFFD0D0C0)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 테이프 사선 스트라이프 (base/stripe 색상 지정 가능)
class _StripeTapePainter extends CustomPainter {
  final Color baseColor;
  final Color stripeColor;

  _StripeTapePainter({
    Color? baseColor,
    Color? stripeColor,
  })  : baseColor = baseColor ?? Colors.white,
        stripeColor = stripeColor ?? SnapFitColors.accent;

  @override
  void paint(Canvas canvas, Size size) {
    const stripeWidth = 6.0;
    var x = -size.height * 2;
    var index = 0;
    while (x < size.width + size.height * 2) {
      final paint = Paint()
        ..color = index.isEven ? stripeColor : baseColor
        ..style = PaintingStyle.fill;
      final path = Path();
      path.moveTo(x, 0);
      path.lineTo(x + stripeWidth, 0);
      path.lineTo(x + stripeWidth + size.height, size.height);
      path.lineTo(x + size.height, size.height);
      path.close();
      canvas.drawPath(path, paint);
      x += stripeWidth;
      index++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 점선 테두리 (라벨/태그 프리뷰)
class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double borderRadius;
  final double dashWidth;
  final double dashSpace;

  _DashedRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.borderRadius,
    this.dashWidth = 4,
    this.dashSpace = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    _drawDashedPath(canvas, path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final segment = metric.extractPath(
          distance,
          distance + dashWidth,
        );
        canvas.drawPath(segment, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 찢어진 메모지 미리보기 – 아래쪽만 톱니 (종이 뜯은 느낌)
class _TornNotePreviewClipper extends CustomClipper<Path> {
  static const double _step = 6.0;
  static const double _amp = 2.0;

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    for (var x = size.width - _step; x > 0; x -= _step) {
      path.lineTo(x + _step / 2, size.height - _amp);
      path.lineTo(x, size.height);
    }
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// 찢어진 테이프 미리보기 – 오른쪽만 톱니 찢김
class _TapeTornPreviewClipper extends CustomClipper<Path> {
  static const double _step = 6.0;
  static const double _amp = 2.0;

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    for (var y = _step; y < size.height; y += _step) {
      path.lineTo(size.width - _amp, y - _step / 2);
      path.lineTo(size.width, y);
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
