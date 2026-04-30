import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/env.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/theme/snapfit_design_tokens.dart';
import '../../../../core/utils/app_error_mapper.dart';
import '../../../../shared/widgets/snapfit_app_bar_back_button.dart';
import '../../../store/data/api/template_provider.dart';
import '../../../store/domain/entities/premium_template.dart';
import '../../data/admin_ops_repository.dart';

class AdminTemplateManagementScreen extends ConsumerStatefulWidget {
  const AdminTemplateManagementScreen({super.key});

  @override
  ConsumerState<AdminTemplateManagementScreen> createState() =>
      _AdminTemplateManagementScreenState();
}

class _AdminTemplateManagementScreenState
    extends ConsumerState<AdminTemplateManagementScreen> {
  int _refreshSeed = 0;

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
      ),
    );
  }

  Future<void> _openEditor({AdminTemplateSummary? summary}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _AdminTemplateEditorScreen(templateId: summary?.id),
      ),
    );
    if (changed == true && mounted) {
      setState(() => _refreshSeed++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminKey = Env.orderAdminKey.trim();
    if (adminKey.isEmpty) {
      return Scaffold(
        backgroundColor: SnapFitColors.backgroundOf(context),
        appBar: AppBar(
          backgroundColor: SnapFitColors.backgroundOf(context),
          elevation: 0,
          leading: const SnapFitAppBarBackButton(),
          title: Text('템플릿 관리', style: context.sfTitle(size: 16.sp)),
        ),
        body: Center(
          child: Text(
            '관리자 키가 설정되지 않았습니다.',
            style: TextStyle(
              fontSize: 13.sp,
              color: SnapFitColors.textSecondaryOf(context),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: SnapFitColors.backgroundOf(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: const SnapFitAppBarBackButton(),
        title: Text('템플릿 관리', style: context.sfTitle(size: 16.sp)),
        actions: [
          IconButton(
            onPressed: _publishCanonicalTemplates,
            icon: const Icon(Icons.cloud_upload_outlined),
            tooltip: '기본 6개 서버 등록',
          ),
          IconButton(
            onPressed: () => setState(() => _refreshSeed++),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: SnapFitColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('템플릿 추가'),
      ),
      body: FutureBuilder<AdminTemplatePage>(
        future: ref
            .read(adminOpsRepositoryProvider)
            .fetchAdminTemplates(adminKey: adminKey, size: 100),
        key: ValueKey(_refreshSeed),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                AppErrorMapper.toUserMessage(
                  snapshot.error ?? Exception('템플릿을 불러올 수 없습니다.'),
                ),
                style: TextStyle(
                  fontSize: 13.sp,
                  color: SnapFitColors.textSecondaryOf(context),
                ),
              ),
            );
          }

          final items = snapshot.data?.items ?? const <AdminTemplateSummary>[];
          if (items.isEmpty) {
            return Center(
              child: Text(
                '등록된 템플릿이 없습니다.',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: SnapFitColors.textSecondaryOf(context),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 110.h),
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(height: 10.h),
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                decoration: BoxDecoration(
                  color: SnapFitColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(color: SnapFitColors.overlayLightOf(context)),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.fromLTRB(16.w, 10.h, 12.w, 10.h),
                  title: Text(
                    item.title.isEmpty ? '제목 없음' : item.title,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: SnapFitColors.textPrimaryOf(context),
                    ),
                  ),
                  subtitle: Padding(
                    padding: EdgeInsets.only(top: 6.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.category.isEmpty ? '카테고리 없음' : item.category} · ${item.pageCount}페이지',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: SnapFitColors.textSecondaryOf(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '관심 ${item.likeCount}명 · 사용 ${item.userCount}명',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: SnapFitColors.textMutedOf(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: Switch(
                    value: item.active,
                    activeColor: SnapFitColors.accent,
                    onChanged: (value) async {
                      try {
                        await ref.read(adminOpsRepositoryProvider).setTemplateActive(
                              adminKey: adminKey,
                              templateId: item.id,
                              active: value,
                            );
                        if (!mounted) return;
                        setState(() => _refreshSeed++);
                      } catch (e) {
                        _showToast(AppErrorMapper.toUserMessage(e));
                      }
                    },
                  ),
                  onTap: () => _openEditor(summary: item),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _publishCanonicalTemplates() async {
    final adminKey = Env.orderAdminKey.trim();
    if (adminKey.isEmpty) {
      _showToast('관리자 키가 없습니다.');
      return;
    }

    try {
      final templates = await loadCanonicalStoreTemplatesForRuntime();
      for (final template in templates) {
        await ref.read(adminOpsRepositoryProvider).upsertTemplate(
              adminKey: adminKey,
              payload: _upsertPayload(template),
            );
      }
      if (!mounted) return;
      setState(() => _refreshSeed++);
      _showToast('기본 6개 템플릿을 서버에 반영했습니다.');
    } catch (e) {
      _showToast(AppErrorMapper.toUserMessage(e));
    }
  }

  Map<String, dynamic> _upsertPayload(PremiumTemplate template) {
    return <String, dynamic>{
      if (template.id > 0) 'id': template.id,
      'title': template.title,
      'subTitle': template.subTitle,
      'description': template.description,
      'coverImageUrl': template.coverImageUrl,
      'previewImagesJson': jsonEncode(template.previewImages),
      'pageCount': template.pageCount,
      'likeCount': template.likeCount,
      'userCount': template.userCount,
      'isBest': template.isBest,
      'isPremium': template.isPremium,
      'category': template.category ?? '기타',
      'tagsJson': jsonEncode(template.tags ?? const <String>[]),
      'weeklyScore': template.weeklyScore,
      'newUntil': template.isNew
          ? DateTime.now()
                .toUtc()
                .add(const Duration(days: 7))
                .toIso8601String()
          : null,
      'active': true,
      'templateJson': template.templateJson ?? '{}',
    };
  }
}

class _AdminTemplateEditorScreen extends ConsumerStatefulWidget {
  const _AdminTemplateEditorScreen({this.templateId});

  final int? templateId;

  @override
  ConsumerState<_AdminTemplateEditorScreen> createState() =>
      _AdminTemplateEditorScreenState();
}

class _AdminTemplateEditorScreenState
    extends ConsumerState<_AdminTemplateEditorScreen> {
  final _titleController = TextEditingController();
  final _subTitleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _coverController = TextEditingController();
  final _previewController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();
  final _pageCountController = TextEditingController(text: '0');
  final _likeCountController = TextEditingController(text: '0');
  final _userCountController = TextEditingController(text: '0');
  final _templateJsonController = TextEditingController();

  bool _isPremium = true;
  bool _isBest = false;
  bool _isNew = false;
  bool _active = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subTitleController.dispose();
    _descriptionController.dispose();
    _coverController.dispose();
    _previewController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    _pageCountController.dispose();
    _likeCountController.dispose();
    _userCountController.dispose();
    _templateJsonController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final templateId = widget.templateId;
    if (templateId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final detail = await ref.read(adminOpsRepositoryProvider).fetchAdminTemplateDetail(
            adminKey: Env.orderAdminKey.trim(),
            templateId: templateId,
          );
      _titleController.text = detail['title']?.toString() ?? '';
      _subTitleController.text =
          (detail['subTitle'] ?? detail['subtitle'])?.toString() ?? '';
      _descriptionController.text = detail['description']?.toString() ?? '';
      _coverController.text = detail['coverImageUrl']?.toString() ?? '';
      final previews = detail['previewImages'];
      if (previews is List) {
        _previewController.text = previews.map((e) => e.toString()).join('\n');
      }
      _categoryController.text = detail['category']?.toString() ?? '';
      final tags = detail['tags'];
      if (tags is List) {
        _tagsController.text = tags.map((e) => e.toString()).join(', ');
      }
      _pageCountController.text = '${(detail['pageCount'] as num?)?.toInt() ?? 0}';
      _likeCountController.text = '${(detail['likeCount'] as num?)?.toInt() ?? 0}';
      _userCountController.text = '${(detail['userCount'] as num?)?.toInt() ?? 0}';
      final templateJson = detail['templateJson'];
      if (templateJson is String) {
        _templateJsonController.text = templateJson;
      } else if (templateJson is Map || templateJson is List) {
        _templateJsonController.text = const JsonEncoder.withIndent(
          '  ',
        ).convert(templateJson);
      }
      _isPremium = detail['isPremium'] != false;
      _isBest = detail['isBest'] == true;
      _isNew = detail['isNew'] == true;
      _active = detail['active'] != false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorMapper.toUserMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final payload = <String, dynamic>{
        if (widget.templateId != null) 'id': widget.templateId,
        'title': _titleController.text.trim(),
        'subTitle': _subTitleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'coverImageUrl': _coverController.text.trim(),
        'previewImages': _previewController.text
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false),
        'category': _categoryController.text.trim(),
        'tags': _tagsController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false),
        'pageCount': int.tryParse(_pageCountController.text.trim()) ?? 0,
        'likeCount': int.tryParse(_likeCountController.text.trim()) ?? 0,
        'userCount': int.tryParse(_userCountController.text.trim()) ?? 0,
        'templateJson': _templateJsonController.text.trim(),
        'isPremium': _isPremium,
        'isBest': _isBest,
        'isNew': _isNew,
        'active': _active,
      };

      await ref.read(adminOpsRepositoryProvider).upsertTemplate(
            adminKey: Env.orderAdminKey.trim(),
            payload: payload,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorMapper.toUserMessage(e))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(
            fontSize: 13.sp,
            color: SnapFitColors.textPrimaryOf(context),
          ),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: SnapFitColors.surfaceOf(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide(color: SnapFitColors.overlayLightOf(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide(color: SnapFitColors.overlayLightOf(context)),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: SnapFitColors.backgroundOf(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: const SnapFitAppBarBackButton(),
        title: Text(
          widget.templateId == null ? '템플릿 추가' : '템플릿 수정',
          style: context.sfTitle(size: 16.sp),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading || _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('저장'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 32.h),
              children: [
                _field('제목', _titleController),
                SizedBox(height: 14.h),
                _field('부제목', _subTitleController),
                SizedBox(height: 14.h),
                _field('설명', _descriptionController, maxLines: 4),
                SizedBox(height: 14.h),
                _field('커버 이미지 URL', _coverController),
                SizedBox(height: 14.h),
                _field(
                  '예시 이미지 목록',
                  _previewController,
                  maxLines: 6,
                  hint: '한 줄에 하나씩 입력',
                ),
                SizedBox(height: 14.h),
                Row(
                  children: [
                    Expanded(child: _field('카테고리', _categoryController)),
                    SizedBox(width: 12.w),
                    Expanded(child: _field('페이지 수', _pageCountController)),
                  ],
                ),
                SizedBox(height: 14.h),
                Row(
                  children: [
                    Expanded(child: _field('관심 수', _likeCountController)),
                    SizedBox(width: 12.w),
                    Expanded(child: _field('사용 수', _userCountController)),
                  ],
                ),
                SizedBox(height: 14.h),
                _field('태그', _tagsController, hint: '쉼표로 구분'),
                SizedBox(height: 14.h),
                _field(
                  '템플릿 JSON',
                  _templateJsonController,
                  maxLines: 16,
                ),
                SizedBox(height: 18.h),
                SwitchListTile(
                  value: _active,
                  activeColor: SnapFitColors.accent,
                  title: const Text('활성화'),
                  onChanged: (value) => setState(() => _active = value),
                ),
                SwitchListTile(
                  value: _isPremium,
                  activeColor: SnapFitColors.accent,
                  title: const Text('프리미엄'),
                  onChanged: (value) => setState(() => _isPremium = value),
                ),
                SwitchListTile(
                  value: _isBest,
                  activeColor: SnapFitColors.accent,
                  title: const Text('BEST 표시'),
                  onChanged: (value) => setState(() => _isBest = value),
                ),
                SwitchListTile(
                  value: _isNew,
                  activeColor: SnapFitColors.accent,
                  title: const Text('NEW 표시'),
                  onChanged: (value) => setState(() => _isNew = value),
                ),
              ],
            ),
    );
  }
}
