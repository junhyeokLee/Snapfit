import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../profile/presentation/views/notification_settings_screen.dart';
import '../../../social/presentation/widgets/social_web_frame.dart';
import '../../../social/presentation/widgets/social_widgets.dart';
import '../../data/moment_engagement_repository.dart';
import '../../domain/moment_record.dart';
import '../providers/moment_engagement_providers.dart';
import '../providers/moments_providers.dart';
import '../widgets/moments_widgets.dart';

class MomentReminderSettingsScreen extends ConsumerStatefulWidget {
  const MomentReminderSettingsScreen({super.key});

  @override
  ConsumerState<MomentReminderSettingsScreen> createState() =>
      _MomentReminderSettingsScreenState();
}

class _MomentReminderSettingsScreenState
    extends ConsumerState<MomentReminderSettingsScreen> {
  static const _days = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
  String? _owner, _error;
  bool _loading = true, _busy = false, _changedAccount = false;
  MomentEngagement? _saved;
  MomentReminder _draft = const MomentReminder();
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _owner = ref.read(momentsCurrentUserIdProvider);
    _load();
  }

  bool _current(int generation) =>
      mounted &&
      !_changedAccount &&
      generation == _generation &&
      _owner != null &&
      ref.read(momentsCurrentUserIdProvider) == _owner;

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final result = await ref.read(momentEngagementRepositoryProvider).load();
      if (!_current(generation)) return;
      setState(() {
        _saved = result;
        _draft = result.reminder;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!_current(generation)) return;
      setState(() {
        _loading = false;
        _error = error is MomentException ? error.message : '알림 설정을 불러오지 못했어요.';
      });
    }
  }

  void _change({bool? enabled, int? weekday, int? hour, int? minute}) {
    setState(() {
      _draft = MomentReminder(
        enabled: enabled ?? _draft.enabled,
        weekday: weekday ?? _draft.weekday,
        hour: hour ?? _draft.hour,
        minute: minute ?? _draft.minute,
      );
      _error = null;
    });
  }

  Future<void> _time() async {
    final generation = _generation;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _draft.hour, minute: _draft.minute),
      helpText: '돌아볼 시간 · 한국 시간',
      cancelText: '취소',
      confirmText: '선택',
    );
    if (!_current(generation) || time == null) return;
    if (time.hour < 8 || time.hour > 21) {
      setState(() => _error = '편안히 쉬실 수 있도록 오전 8시부터 오후 9시 59분 사이로 선택해 주세요.');
      return;
    }
    _change(hour: time.hour, minute: time.minute);
  }

  Future<void> _save() async {
    if (_busy || _loading || !_current(_generation)) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(momentEngagementRepositoryProvider)
          .saveReminder(_draft);
      if (!_current(generation)) return;
      setState(() {
        _saved = result;
        _draft = result.reminder;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.reminder.enabled
                ? result.canRemind
                      ? '선택한 시간에 주 1회 알려드릴게요.'
                      : '시간을 저장했어요. 전체 알림을 켜면 받을 수 있어요.'
                : '주간 기록 알림을 껐어요.',
          ),
        ),
      );
    } catch (error) {
      if (!_current(generation)) return;
      setState(
        () => _error = error is MomentException
            ? error.message
            : '설정을 저장하지 못했어요. 다시 시도해 주세요.',
      );
    } finally {
      if (_current(generation)) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(momentsCurrentUserIdProvider);
    ref.listen(momentsCurrentUserIdProvider, (previous, next) {
      if (previous == next || next == _owner) return;
      _generation++;
      _changedAccount = true;
      _saved = null;
      _draft = const MomentReminder();
      _busy = false;
      _error = null;
    });
    final enabled = !_loading && !_busy && !_changedAccount && _saved != null;
    return SocialWebFrame(
      section: WebSection.moments,
      child: Scaffold(
        backgroundColor: SocialStyle.background(context),
        appBar: const ExperienceHeader(
          title: '이번 주를 돌아볼 시간',
          showNotifications: false,
        ),
        body: SafeArea(
          top: false,
          child: SocialContent(
            maxWidth: 560,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  '잊고 있던 순간을,\n가볍게 다시 만나요.',
                  style: ExperienceFormStyle.text(
                    context,
                    28,
                    weight: FontWeight.w600,
                  ).copyWith(height: 1.35, letterSpacing: -.7),
                ),
                const SizedBox(height: 14),
                Text(
                  '원하는 날과 시간에 한 번만 알려드려요.\n그 주에 이미 기록하거나 돌아봤다면 쉬어갑니다.',
                  style: ExperienceFormStyle.text(
                    context,
                    14,
                    secondary: true,
                  ).copyWith(height: 1.7),
                ),
                const SizedBox(height: 26),
                if (_changedAccount || _owner == null)
                  const MomentErrorNotice(
                    message: '로그인 계정이 변경됐어요. 기록 화면에서 다시 열어 주세요.',
                  )
                else if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  if (_error != null) ...[
                    MomentErrorNotice(
                      message: _error!,
                      onRetry: _saved == null
                          ? () {
                              setState(() => _loading = true);
                              _load();
                            }
                          : null,
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (_saved?.hasRecords == false) ...[
                    Text(
                      '사진 한 장을 남긴 뒤 알림을 켤 수 있어요.',
                      style: ExperienceFormStyle.text(
                        context,
                        15,
                      ).copyWith(height: 1.6),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (_saved?.hasRecords == true &&
                      _saved?.canRemind == false) ...[
                    Text(
                      '전체 알림이 꺼져 있어요. 아래 기기 알림 설정에서 전체 알림을 켜면 받을 수 있어요.',
                      style: ExperienceFormStyle.text(
                        context,
                        14,
                        secondary: true,
                      ).copyWith(height: 1.7),
                    ),
                    const SizedBox(height: 20),
                  ],
                  SwitchListTile.adaptive(
                    key: const ValueKey('moments-reminder-toggle'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('주간 기록 알림'),
                    subtitle: const Text('선택한 요일에 주 1회'),
                    value: _draft.enabled,
                    onChanged: enabled && (_saved!.hasRecords || _draft.enabled)
                        ? (value) => _change(enabled: value)
                        : null,
                  ),
                  const SizedBox(height: 22),
                  DropdownButtonFormField<int>(
                    key: const ValueKey('moments-reminder-weekday'),
                    initialValue: _draft.weekday,
                    decoration: const InputDecoration(labelText: '돌아볼 요일'),
                    items: List.generate(
                      7,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text(_days[index]),
                      ),
                    ),
                    onChanged: enabled && _draft.enabled
                        ? (value) => _change(weekday: value)
                        : null,
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    key: const ValueKey('moments-reminder-time'),
                    onPressed: enabled && _draft.enabled ? _time : null,
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text(
                      '${_draft.hour.toString().padLeft(2, '0')}:${_draft.minute.toString().padLeft(2, '0')} · 한국 시간',
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    key: const ValueKey('moments-reminder-save'),
                    style: SocialStyle.primary(context),
                    onPressed:
                        enabled && (!_draft.enabled || _saved!.hasRecords)
                        ? _save
                        : null,
                    child: Text(_busy ? '저장하고 있어요…' : '알림 설정 저장'),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    '알림함에서도 확인할 수 있어요. 휴대폰·브라우저로 받으려면 기기 알림도 허용해 주세요.',
                    style: ExperienceFormStyle.text(
                      context,
                      13,
                      secondary: true,
                    ).copyWith(height: 1.7),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const NotificationSettingsScreen(),
                              ),
                            ),
                      icon: const Icon(Icons.notifications_outlined, size: 18),
                      label: const Text('기기 알림 설정'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
