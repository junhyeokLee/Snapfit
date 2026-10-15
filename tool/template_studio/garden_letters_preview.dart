import 'package:flutter/material.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'lightbound_preview.dart';

class GardenLettersPreview extends StatelessWidget {
  const GardenLettersPreview({super.key});

  @override
  Widget build(BuildContext context) => AuthoredDraftPreview<bool>(
    title: '정원의 편지',
    chapters: gardenLettersChapters,
    initialCopy: true,
    editionLabel: '웨딩 · 내지 24쪽 · 신규 시안',
    prioritizePageCount: true,
    buildPages: (aspect, _, photos) =>
        templateDocumentPages(buildGardenLetters(aspect))
            .map(
              (page) =>
                  DataTemplateEngine.buildLayersFromJson(page, aspect.canvas)
                      .map(
                        (layer) => !photos && layer.type == LayerType.image
                            ? layer.copyWith(clearImage: true)
                            : layer,
                      )
                      .toList(),
            )
            .toList(),
  );
}
