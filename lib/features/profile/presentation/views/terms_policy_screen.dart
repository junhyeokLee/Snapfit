import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/snapfit_app_bar_back_button.dart';

class TermsPolicyScreen extends StatelessWidget {
  const TermsPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = const [
      ('서비스 이용약관', '서비스 이용 조건, 회원 책임, 금지행위, 해지 및 면책 조항을 확인하세요.'),
      ('개인정보 처리방침', '수집 항목, 이용 목적, 보관 기간, 제3자 제공 및 이용자 권리를 안내합니다.'),
      ('마케팅 정보 수신 동의', '푸시/이메일 프로모션 수신 범위와 철회 방법을 안내합니다.'),
      ('오픈소스 라이선스', '앱에서 사용하는 오픈소스 라이브러리의 라이선스 고지를 제공합니다.'),
    ];

    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: SnapFitColors.backgroundOf(context),
        elevation: 0,
        leading: const SnapFitAppBarBackButton(),
        title: Text(
          '약관 및 정책',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
      ),
      body: ListView.separated(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h),
        itemCount: sections.length,
        separatorBuilder: (_, __) => SizedBox(height: 10.h),
        itemBuilder: (context, index) {
          final section = sections[index];
          return InkWell(
            borderRadius: BorderRadius.circular(14.r),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _TermsDetailScreen(
                    title: section.$1,
                    description: section.$2,
                  ),
                ),
              );
            },
            child: Ink(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: SnapFitColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: SnapFitColors.overlayLightOf(context),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.$1,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: SnapFitColors.textPrimaryOf(context),
                          ),
                        ),
                        SizedBox(height: 5.h),
                        Text(
                          section.$2,
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                            color: SnapFitColors.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20.sp,
                    color: SnapFitColors.textSecondaryOf(context),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TermsDetailScreen extends StatelessWidget {
  final String title;
  final String description;

  const _TermsDetailScreen({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: SnapFitColors.backgroundOf(context),
        elevation: 0,
        leading: const SnapFitAppBarBackButton(),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
        child: Text(
          '$description\n\n'
          '본 문서는 실제 서비스 정책 반영을 위해 관리자가 업데이트할 수 있습니다.\n\n'
          '1. 목적\n'
          'SnapFit 서비스 이용에 필요한 기준과 절차를 정의합니다.\n\n'
          '2. 적용 범위\n'
          '회원 가입, 앨범 제작, 결제, 공유 기능을 포함한 전체 서비스에 적용됩니다.\n\n'
          '3. 이용자 권리\n'
          '이용자는 정보 열람/정정/삭제 및 동의 철회를 요청할 수 있습니다.\n\n'
          '4. 문의\n'
          '정책 문의는 고객센터를 통해 접수할 수 있습니다.',
          style: TextStyle(
            fontSize: 12.sp,
            height: 1.55,
            fontWeight: FontWeight.w500,
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
      ),
    );
  }
}
