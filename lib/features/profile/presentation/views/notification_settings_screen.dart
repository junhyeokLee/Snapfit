import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/notifications/fcm_notification_service.dart';
import '../../../../shared/widgets/snapfit_app_bar_back_button.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _loading = true;

  bool all = true;
  bool order = true;
  bool invite = true;
  bool comment = true;
  bool marketing = false;
  bool newTemplate = true;
  bool nightMute = false;
  bool permissionGranted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await FcmNotificationService.loadSettings();
    if (!mounted) return;
    setState(() {
      all = settings.all;
      order = settings.order;
      invite = settings.invite;
      comment = settings.comment;
      marketing = settings.marketing;
      newTemplate = settings.newTemplate;
      nightMute = settings.nightMute;
      permissionGranted = settings.permissionGranted;
      _loading = false;
    });
  }

  Future<void> _toggle(String key, bool value) async {
    setState(() {
      switch (key) {
        case FcmNotificationService.kAll:
          all = value;
          order = value;
          invite = value;
          comment = value;
          marketing = value;
          newTemplate = value;
          break;
        case FcmNotificationService.kOrder:
          order = value;
          break;
        case FcmNotificationService.kInvite:
          invite = value;
          break;
        case FcmNotificationService.kComment:
          comment = value;
          break;
        case FcmNotificationService.kMarketing:
          marketing = value;
          break;
        case FcmNotificationService.kNewTemplate:
          newTemplate = value;
          break;
        case FcmNotificationService.kNightMute:
          nightMute = value;
          break;
      }
      all = order && invite && comment && marketing && newTemplate;
    });
    await FcmNotificationService.updateSettings(
      all: all,
      order: order,
      invite: invite,
      comment: comment,
      marketing: marketing,
      newTemplate: newTemplate,
      nightMute: nightMute,
    );
  }

  Future<void> _requestPermission() async {
    final granted = await FcmNotificationService.requestPermission();
    if (!mounted) return;
    setState(() => permissionGranted = granted);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: SnapFitColors.backgroundOf(context),
        appBar: AppBar(
          backgroundColor: SnapFitColors.backgroundOf(context),
          elevation: 0,
          leading: const SnapFitAppBarBackButton(),
          title: Text(
            '알림 설정',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: SnapFitColors.textPrimaryOf(context),
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: SnapFitColors.backgroundOf(context),
        elevation: 0,
        leading: const SnapFitAppBarBackButton(),
        title: Text(
          '알림 설정',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 20.h),
        children: [
          _permissionCard(context),
          SizedBox(height: 10.h),
          _sectionTitle(context, '기본'),
          _switchTile(
            context,
            title: '전체 알림',
            subtitle: '주요 알림을 모두 수신합니다.',
            value: all,
            onChanged: (v) => _toggle(FcmNotificationService.kAll, v),
          ),
          _switchTile(
            context,
            title: '주문/배송 알림',
            subtitle: '결제, 제작, 인쇄, 배송 상태 변경 안내',
            value: order,
            onChanged: (v) => _toggle(FcmNotificationService.kOrder, v),
          ),
          _switchTile(
            context,
            title: '공유/초대 알림',
            subtitle: '앨범 초대, 권한 변경, 협업 알림',
            value: invite,
            onChanged: (v) => _toggle(FcmNotificationService.kInvite, v),
          ),
          _switchTile(
            context,
            title: '댓글/반응 알림',
            subtitle: '댓글, 좋아요 등 상호작용 알림',
            value: comment,
            onChanged: (v) => _toggle(FcmNotificationService.kComment, v),
          ),
          _switchTile(
            context,
            title: '새 템플릿 알림',
            subtitle: '스토어에 신규 템플릿이 등록되면 알려드려요.',
            value: newTemplate,
            onChanged: (v) => _toggle(FcmNotificationService.kNewTemplate, v),
          ),
          SizedBox(height: 10.h),
          _sectionTitle(context, '마케팅 및 시간대'),
          _switchTile(
            context,
            title: '혜택/이벤트 알림',
            subtitle: '쿠폰, 할인, 신규 템플릿 추천',
            value: marketing,
            onChanged: (v) => _toggle(FcmNotificationService.kMarketing, v),
          ),
          _switchTile(
            context,
            title: '야간 알림 끄기',
            subtitle: '22:00 - 08:00 동안 푸시 알림 미수신',
            value: nightMute,
            onChanged: (v) => _toggle(FcmNotificationService.kNightMute, v),
          ),
        ],
      ),
    );
  }

  Widget _permissionCard(BuildContext context) {
    final textColor = SnapFitColors.textPrimaryOf(context);
    final subColor = SnapFitColors.textSecondaryOf(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: SnapFitColors.overlayLightOf(context)),
      ),
      child: Row(
        children: [
          Icon(
            permissionGranted
                ? Icons.notifications_active_rounded
                : Icons.notifications_off_rounded,
            size: 18.sp,
            color: permissionGranted ? SnapFitColors.accent : subColor,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              permissionGranted ? '푸시 알림 권한이 허용됨' : '푸시 알림 권한이 꺼져 있음',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          if (!permissionGranted)
            TextButton(
              onPressed: _requestPermission,
              child: Text(
                '권한 허용',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: SnapFitColors.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: EdgeInsets.only(left: 2.w, bottom: 6.h, top: 6.h),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          color: SnapFitColors.textSecondaryOf(context),
        ),
      ),
    );
  }

  Widget _switchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: SnapFitColors.overlayLightOf(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: SnapFitColors.textPrimaryOf(context),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: SnapFitColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Switch.adaptive(
            value: value,
            activeColor: SnapFitColors.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
