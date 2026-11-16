import 'package:flutter/material.dart';

import '../../../../core/constants/cover_size.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../album/presentation/widgets/create_flow/cover_size_picker.dart';

/// Uses the exact same five formats as album creation without changing a
/// document until the user explicitly selects an option.
Future<CoverSize?> showMomentPhotoFormatPicker(
  BuildContext context, {
  required CoverSize? selectedCover,
  required String title,
  required String description,
}) => showDialog<CoverSize>(
  context: context,
  useRootNavigator: false,
  builder: (dialog) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 560,
        maxHeight: MediaQuery.sizeOf(dialog).height * .85,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: ExperienceFormStyle.text(
                dialog,
                20,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: ExperienceFormStyle.text(dialog, 13, secondary: true),
            ),
            const SizedBox(height: 20),
            CoverSizePicker(
              selectedCover: selectedCover,
              onSelected: (cover) => Navigator.pop(dialog, cover),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: const Text('닫기'),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
