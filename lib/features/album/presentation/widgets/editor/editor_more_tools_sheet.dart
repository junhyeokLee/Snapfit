import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../domain/entities/layer.dart';
import '../../controllers/layer_interaction_manager.dart';
import '../../viewmodels/album_editor_view_model.dart';

enum EditorMoreAction { photoPosition, delete, decorate, layout, background }

/// Only secondary controls live here. Photo replacement, crop and styling stay
/// in the dock, so a second modal never covers their existing touch targets.
class EditorMoreToolsSheet extends ConsumerWidget {
  const EditorMoreToolsSheet({
    super.key,
    required this.interaction,
    required this.session,
    required this.pageId,
    required this.albumId,
    required this.selectedId,
    required this.onAction,
    required this.onClose,
  });

  final LayerInteractionManager interaction;
  final Object session;
  final String? pageId, selectedId;
  final int? albumId;
  final ValueChanged<EditorMoreAction> onAction;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(albumEditorViewModelProvider).value;
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final layer = state?.layers.where((l) => l.id == selectedId).firstOrNull;
    bool targetValid() =>
        identical(vm.editSessionIdentity, session) &&
        vm.currentPage?.id == pageId &&
        vm.editingAlbumId == albumId &&
        interaction.selectedLayerId == selectedId &&
        (selectedId == null || vm.findLayerById(selectedId!) != null);
    bool valid() =>
        context.mounted &&
        ModalRoute.of(context)?.isCurrent != false &&
        identical(ref.read(albumEditorViewModelProvider.notifier), vm) &&
        targetValid();
    final ink = ExperienceFormStyle.ink(context);
    final line = ExperienceFormStyle.line(context);
    Widget action(
      IconData icon,
      String label,
      String description,
      EditorMoreAction value, {
      bool enabled = true,
    }) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: ExperienceFormStyle.selection(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 21, color: ink),
      ),
      title: Text(
        label,
        style: ExperienceFormStyle.text(context, 14, weight: FontWeight.w600),
      ),
      subtitle: Text(
        description,
        style: ExperienceFormStyle.text(context, 12, secondary: true),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      enabled: enabled,
      onTap: enabled
          ? () {
              if (valid()) onAction(value);
            }
          : null,
    );
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        key: const ValueKey('editor-more-sheet'),
        constraints: BoxConstraints(
          maxHeight: math.max(0, MediaQuery.sizeOf(context).height * .82),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '추가 도구',
                      style: ExperienceFormStyle.text(
                        context,
                        20,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '편집 도구 닫기',
                    onPressed: onClose,
                    icon: const Icon(Icons.close, size: 21),
                  ),
                ],
              ),
              if (!targetValid())
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('편집할 요소가 변경됐어요. 닫고 다시 선택해 주세요.'),
                )
              else ...[
                if (layer != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: line),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          layer.type == LayerType.image
                              ? '선택한 사진'
                              : layer.type == LayerType.text
                              ? '선택한 글'
                              : '선택한 요소',
                          style: ExperienceFormStyle.text(
                            context,
                            12,
                            secondary: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '진하기',
                                style: ExperienceFormStyle.text(
                                  context,
                                  14,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${(layer.opacity * 100).round()}%',
                              style: ExperienceFormStyle.text(context, 13),
                            ),
                          ],
                        ),
                        Semantics(
                          label: '선택한 요소 진하기',
                          child: Slider(
                            value: layer.opacity.clamp(0.0, 1.0),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            onChanged: (value) {
                              if (!valid()) return;
                              final current = vm.findLayerById(layer.id);
                              if (current != null) {
                                vm.updateLayer(
                                  current.copyWith(opacity: value),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (layer.type == LayerType.image)
                    action(
                      Icons.open_with,
                      '사진 위치 조정',
                      interaction.isImagePanMode
                          ? '위치 조정을 마치고 요소를 이동해요'
                          : '사진을 끌어 프레임 안의 구도를 조정해요',
                      EditorMoreAction.photoPosition,
                      enabled: layer.hasImageSource || layer.asset != null,
                    ),
                  const SizedBox(height: 14),
                ],
                Text(
                  '페이지 도구',
                  style: ExperienceFormStyle.text(context, 12, secondary: true),
                ),
                const SizedBox(height: 4),
                action(
                  Icons.auto_awesome_outlined,
                  '꾸미기',
                  '스티커·종이·장식 추가',
                  EditorMoreAction.decorate,
                ),
                action(
                  Icons.dashboard_outlined,
                  '레이아웃',
                  '사진과 글을 담을 배치 선택',
                  EditorMoreAction.layout,
                ),
                action(
                  Icons.palette_outlined,
                  '배경',
                  '이 페이지의 배경색 변경',
                  EditorMoreAction.background,
                ),
                if (layer != null) ...[
                  const SizedBox(height: 12),
                  Divider(height: 1, color: line),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      if (valid()) onAction(EditorMoreAction.delete);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    label: const Text('삭제'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
