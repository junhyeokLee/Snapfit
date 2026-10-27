import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/context_extensions.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../profile/presentation/widgets/customer_web_page.dart';
import '../../data/admin_home_news_repository.dart';
import '../../domain/home_news.dart';
import '../providers/home_news_providers.dart';

class AdminHomeNewsScreen extends ConsumerWidget {
  const AdminHomeNewsScreen({super.key});

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    HomeNewsCampaign campaign,
  ) async {
    final owner = ref.read(homeNewsCurrentOwnerProvider);
    final repository = ref.read(adminHomeNewsRepositoryProvider);
    if (owner == null ||
        !ref.read(adminHomeNewsAccessProvider) ||
        repository.currentUserId != owner) {
      throw StateError('새 소식을 관리할 권한이 필요합니다.');
    }
    await repository.updateCampaign(campaign);
    if (!context.mounted ||
        ref.read(homeNewsCurrentOwnerProvider) != owner ||
        !ref.read(adminHomeNewsAccessProvider) ||
        repository.currentUserId != owner) {
      throw StateError('운영 계정이 변경됐습니다.');
    }
    ref.invalidate(adminHomeNewsSnapshotProvider);
    ref.invalidate(homeNewsExposureStateProvider);
    ref.invalidate(homeNewsCatalogProvider);
    context.showSnack('새 소식 설정을 저장했습니다. 다음 조회부터 반영됩니다.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(homeNewsCurrentOwnerProvider);
    final allowed = ref.watch(adminHomeNewsAccessProvider);
    Widget content() => !allowed || owner == null
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 64),
            child: Center(child: Text('새 소식을 관리할 관리자 권한이 필요합니다.')),
          )
        : ref
              .watch(adminHomeNewsSnapshotProvider)
              .when(
                skipLoadingOnRefresh: false,
                skipLoadingOnReload: false,
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 64),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('새 소식 설정을 불러오지 못했습니다.'),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        key: const ValueKey('admin-home-news-retry'),
                        onPressed: () =>
                            ref.invalidate(adminHomeNewsSnapshotProvider),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('다시 불러오기'),
                      ),
                    ],
                  ),
                ),
                data: (snapshot) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: ExperienceFormStyle.selection(context),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '메인에서 전하는 네 가지 소식',
                            style: ExperienceFormStyle.text(
                              context,
                              19,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '앱 업데이트 없이 켜고 끌 수 있어요. 기간과 순서를 저장하면 앱과 웹에 함께 반영됩니다.',
                            style: ExperienceFormStyle.text(
                              context,
                              14,
                              secondary: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '모든 시간은 한국 시간입니다. 자동 팝업의 하루·주간 노출 제한은 유지됩니다.',
                            style: ExperienceFormStyle.text(
                              context,
                              12,
                              secondary: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (final campaign in snapshot.campaigns) ...[
                      _CampaignCard(
                        key: ValueKey('$owner-${campaign.kind.name}'),
                        campaign: campaign,
                        serverNow: snapshot.serverNow,
                        onSave: (updated) => _save(context, ref, updated),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              );

    if (kIsWeb) {
      return CustomerWebPage(
        title: '새 소식 운영',
        scrollBody: true,
        child: content(),
      );
    }
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: const ExperienceHeader(
        title: '새 소식 운영',
        themeAware: true,
        showNotifications: false,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: content(),
            ),
          ),
        ),
      ),
    );
  }
}

class _CampaignCard extends StatefulWidget {
  const _CampaignCard({
    super.key,
    required this.campaign,
    required this.serverNow,
    required this.onSave,
  });
  final HomeNewsCampaign campaign;
  final DateTime serverNow;
  final Future<void> Function(HomeNewsCampaign) onSave;

  @override
  State<_CampaignCard> createState() => _CampaignCardState();
}

class _CampaignCardState extends State<_CampaignCard> {
  late bool _enabled;
  late DateTime? _startsAt, _endsAt;
  late int _sortOrder;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant _CampaignCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.campaign != widget.campaign) _reset();
  }

  void _reset() {
    _enabled = widget.campaign.enabled;
    _startsAt = widget.campaign.startsAt;
    _endsAt = widget.campaign.endsAt;
    _sortOrder = widget.campaign.sortOrder;
    _error = null;
  }

  bool get _changed =>
      _enabled != widget.campaign.enabled ||
      _startsAt != widget.campaign.startsAt ||
      _endsAt != widget.campaign.endsAt ||
      _sortOrder != widget.campaign.sortOrder;

  Future<void> _save() async {
    if (_saving) return;
    if (_startsAt != null && _endsAt != null && !_endsAt!.isAfter(_startsAt!)) {
      setState(() => _error = '종료 시간은 시작 시간보다 늦게 선택해 주세요.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        HomeNewsCampaign(
          kind: widget.campaign.kind,
          enabled: _enabled,
          startsAt: _startsAt,
          endsAt: _endsAt,
          sortOrder: _sortOrder,
        ),
      );
    } catch (_) {
      if (mounted)
        setState(() => _error = '저장하지 못했습니다. 관리자 권한과 연결 상태를 확인한 뒤 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate(bool start) async {
    final initial =
        (_startsAt != null && start
                ? _startsAt!
                : _endsAt != null && !start
                ? _endsAt!
                : widget.serverNow)
            .toUtc()
            .add(const Duration(hours: 9));
    final first = DateTime(initial.year < 2020 ? initial.year : 2020);
    final last = DateTime(initial.year > 2100 ? initial.year : 2100, 12, 31);
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: first,
      lastDate: last,
      helpText: start ? '노출 시작일' : '노출 종료일',
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
      helpText: start ? '노출 시작 시간 · 한국 시간' : '노출 종료 시간 · 한국 시간',
    );
    if (!mounted || time == null) return;
    final instant = DateTime.utc(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    ).subtract(const Duration(hours: 9));
    setState(() {
      if (start) {
        _startsAt = instant;
      } else {
        _endsAt = instant;
      }
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.campaign.kind;
    final label = switch (kind) {
      HomeNewsKind.monthlyDesign => '이달의 디자인',
      HomeNewsKind.attendance => '출석 혜택 안내',
      HomeNewsKind.referral => '친구 초대 혜택',
      HomeNewsKind.monthReview => '월말 돌아보기',
    };
    final status = !widget.campaign.enabled
        ? '꺼짐'
        : widget.campaign.startsAt != null &&
              widget.serverNow.isBefore(widget.campaign.startsAt!)
        ? '예약됨'
        : widget.campaign.endsAt != null &&
              !widget.serverNow.isBefore(widget.campaign.endsAt!)
        ? '기간 종료'
        : '노출 중';
    final orders = <int>{0, 1, 2, 3, _sortOrder}.toList()..sort();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ExperienceFormStyle.surface(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ExperienceFormStyle.line(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: ExperienceFormStyle.text(
                          context,
                          18,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        status,
                        key: ValueKey('admin-news-status-${kind.name}'),
                        style: ExperienceFormStyle.text(
                          context,
                          13,
                          color: widget.campaign.isActiveAt(widget.serverNow)
                              ? ExperienceFormStyle.selectionInk(context)
                              : ExperienceFormStyle.muted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Semantics(
                  label: '$label 노출',
                  child: Switch.adaptive(
                    key: ValueKey('admin-news-enabled-${kind.name}'),
                    value: _enabled,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() {
                            _enabled = value;
                            _error = null;
                          }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _scheduleRow(context, start: true),
            const SizedBox(height: 10),
            _scheduleRow(context, start: false),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              key: ValueKey('admin-news-order-${kind.name}-$_sortOrder'),
              initialValue: _sortOrder,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '노출 순서',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final order in orders)
                  DropdownMenuItem(value: order, child: Text('${order + 1}번째')),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) setState(() => _sortOrder = value);
                    },
            ),
            const SizedBox(height: 8),
            Text(
              '숫자가 작은 순서부터 표시됩니다. 기간을 비우면 바로 시작하거나 종료 없이 유지됩니다.',
              style: ExperienceFormStyle.text(context, 12, secondary: true),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: ExperienceFormStyle.text(
                  context,
                  13,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: ValueKey('admin-news-save-${kind.name}'),
              style: ExperienceFormStyle.primary(context),
              onPressed: !_changed || _saving ? null : _save,
              child: Text(_saving ? '저장 중…' : '설정 저장'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scheduleRow(BuildContext context, {required bool start}) {
    final instant = start ? _startsAt : _endsAt;
    final korean = instant?.toUtc().add(const Duration(hours: 9));
    final text = korean == null
        ? (start ? '시작 시간 없음' : '종료 시간 없음')
        : '${korean.year}.${korean.month.toString().padLeft(2, '0')}.${korean.day.toString().padLeft(2, '0')} '
              '${korean.hour.toString().padLeft(2, '0')}:${korean.minute.toString().padLeft(2, '0')}';
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: ValueKey(
              'admin-news-${start ? 'starts' : 'ends'}-${widget.campaign.kind.name}',
            ),
            onPressed: _saving ? null : () => _pickDate(start),
            icon: const Icon(Icons.calendar_today_outlined, size: 17),
            label: Text('${start ? '시작' : '종료'} · $text'),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),
        if (instant != null) ...[
          const SizedBox(width: 4),
          IconButton(
            tooltip: start ? '시작 시간 지우기' : '종료 시간 지우기',
            onPressed: _saving
                ? null
                : () => setState(() {
                    if (start) {
                      _startsAt = null;
                    } else {
                      _endsAt = null;
                    }
                  }),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ],
    );
  }
}
