import 'package:flutter/material.dart';

import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../domain/album_creation_start_mode.dart';
import '../../../../../shared/widgets/experience_icon.dart';

/// 방법만 선택한 뒤 기존 제작 흐름으로 연결한다. 닫으면 아무것도 생성하지 않는다.
Future<AlbumCreationStartMode?> showAlbumCreationStartSheet(
  BuildContext context,
) => showModalBottomSheet<AlbumCreationStartMode>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 560),
  backgroundColor: ExperienceFormStyle.surface(context),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      key: const ValueKey('album-creation-start-sheet'),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: ExperienceFormStyle.line(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '앨범 만들기',
            style: ExperienceFormStyle.text(
              context,
              21,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _StartChoice(
            mode: AlbumCreationStartMode.manual,
            title: '직접 만들기',
            detail: '빈 앨범에 사진과 글을 자유롭게',
            icon: Icons.menu_book_outlined,
          ),
          Divider(height: 1, color: ExperienceFormStyle.line(context)),
          _StartChoice(
            mode: AlbumCreationStartMode.design,
            title: '디자인으로 시작하기',
            detail: '준비된 표지와 내지에서 골라요',
            icon: Icons.photo_library_outlined,
          ),
        ],
      ),
    ),
  ),
);

class _StartChoice extends StatelessWidget {
  const _StartChoice({
    required this.mode,
    required this.title,
    required this.detail,
    required this.icon,
  });

  final AlbumCreationStartMode mode;
  final String title, detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      key: ValueKey('album-creation-start-${mode.name}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).pop(mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            Icon(
              icon,
              size: 26,
              color: ExperienceFormStyle.selectionInk(context),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: ExperienceFormStyle.text(
                      context,
                      17,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    detail,
                    style: ExperienceFormStyle.text(
                      context,
                      13,
                      secondary: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ExperienceIcon('ChevronRight', size: 20, color: ExperienceFormStyle.ink(context),
            ),
          ],
        ),
      ),
    ),
  );
}
