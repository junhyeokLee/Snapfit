import 'package:flutter/material.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../domain/entities/layer.dart';
import '../../controllers/layer_interaction_manager.dart';

enum _OrderAction { forward, backward }

/// Transient metadata-only choices. No thumbnails, image decodes, or persistent
/// copies of an album document are needed for selecting covered artwork.
class EditorOverlapPicker extends StatelessWidget {
  const EditorOverlapPicker({
    super.key,
    required this.layers,
    required this.interaction,
  });
  final List<LayerModel> layers;
  final LayerInteractionManager interaction;

  @override
  Widget build(BuildContext context) {
    final ids = interaction.overlapLayerIds;
    if (ids.length < 2 || interaction.isInteractingNow)
      return const SizedBox.shrink();
    final byId = {for (final layer in layers) layer.id: layer};
    final labels = <String, String>{};
    var photos = 0, stickers = 0, decorations = 0;
    for (final layer in layers) {
      labels[layer.id] = switch (layer.type) {
        LayerType.image => '사진 ${++photos}',
        LayerType.text =>
          layer.text?.trim().isNotEmpty == true ? layer.text! : '글',
        LayerType.sticker => '스티커 ${++stickers}',
        LayerType.decoration => '꾸미기 ${++decorations}',
      };
    }
    final choices = [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
    final revision = interaction.overlapRevision;
    if (choices.length < 2) return const SizedBox.shrink();
    return Material(
      key: const ValueKey('editor-overlap-picker'),
      color: ExperienceFormStyle.surface(context),
      borderRadius: BorderRadius.circular(24),
      child: PopupMenuButton<Object>(
        tooltip: '겹친 요소 선택',
        constraints: const BoxConstraints(maxWidth: 280, maxHeight: 320),
        onSelected: (action) {
          if (!interaction.isOverlapSnapshotCurrent(revision)) return;
          if (action is String)
            interaction.selectOverlappingLayer(action);
          else
            interaction.moveSelectedLayer(
              action == _OrderAction.forward ? 1 : -1,
            );
        },
        itemBuilder: (_) {
          final ordered = interaction.sortByZ(layers);
          return [
            for (var i = 0; i < choices.length; i++)
              PopupMenuItem(
                value: choices[i].id,
                child: Row(
                  children: [
                    Icon(
                      choices[i].type == LayerType.text
                          ? Icons.text_fields
                          : Icons.image_outlined,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        labels[choices[i].id]!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (choices[i].id == interaction.selectedLayerId)
                      const Icon(Icons.check, size: 18),
                  ],
                ),
              ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: _OrderAction.forward,
              enabled: interaction.canMoveSelectedLayer(1, paintOrder: ordered),
              child: const ListTile(
                dense: true,
                leading: Icon(Icons.arrow_upward),
                title: Text('앞으로'),
              ),
            ),
            PopupMenuItem(
              value: _OrderAction.backward,
              enabled: interaction.canMoveSelectedLayer(
                -1,
                paintOrder: ordered,
              ),
              child: const ListTile(
                dense: true,
                leading: Icon(Icons.arrow_downward),
                title: Text('뒤로'),
              ),
            ),
          ];
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.layers_outlined, size: 18),
              const SizedBox(width: 6),
              Text(
                '겹친 요소 ${choices.length}개',
                style: ExperienceFormStyle.text(context, 12),
              ),
              const Icon(Icons.expand_more, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
