import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/snapfit_app_bar_back_button.dart';

class TermsPolicyScreen extends StatelessWidget {
  const TermsPolicyScreen({super.key, this.initialDocType});

  final TermsPolicyDocType? initialDocType;

  static final List<_PolicyDoc> _docs = [
    _PolicyDoc(
      title: '서비스 이용약관',
      summary: '서비스 이용 조건, 계정 책임, 결제/환불, 제한 및 해지 기준을 안내합니다.',
      version: 'v1.4',
      effectiveDate: '2026.04.01',
      body: [
        _PolicySection(
          heading: '제1조 (목적)',
          content:
              '본 약관은 SnapFit(이하 "회사")가 제공하는 앨범 제작 및 주문 서비스의 이용조건, 회원의 권리·의무 및 책임사항을 규정함을 목적으로 합니다.',
        ),
        _PolicySection(
          heading: '제2조 (회원가입 및 계정 관리)',
          content:
              '회원은 본인 명의의 소셜 계정을 통해 가입할 수 있습니다. 회원은 계정 정보 및 기기 보안을 유지할 책임이 있으며, 타인에게 계정을 공유하거나 양도할 수 없습니다.',
        ),
        _PolicySection(
          heading: '제3조 (서비스 이용)',
          content:
              '회사는 앨범 편집, 템플릿 제공, 주문 및 배송 상태 조회 기능을 제공합니다. 회사는 안정적인 서비스 운영을 위해 점검 또는 정책 변경을 시행할 수 있으며, 중요한 변경 사항은 앱 내 공지로 안내합니다.',
        ),
        _PolicySection(
          heading: '제4조 (결제 및 주문)',
          content:
              '유료 상품의 가격, 옵션, 결제수단은 결제 화면에 표시된 내용을 따릅니다. 회원은 주문 전 최종 정보를 확인해야 하며, 결제 완료 후 제작이 시작된 주문은 취소·환불이 제한될 수 있습니다.',
        ),
        _PolicySection(
          heading: '제5조 (취소·환불 기준)',
          content:
              '전자상거래법 등 관계 법령을 준수합니다. 제작 시작 전에는 전액 환불이 가능하며, 제작 시작 후에는 단순 변심 환불이 제한됩니다. 제품 하자/오배송 등 회사 귀책 사유가 확인되면 재제작 또는 환불을 진행합니다.',
        ),
        _PolicySection(
          heading: '제6조 (배송 및 지연 안내)',
          content:
              '배송 일정은 택배사/지역/기상 상황에 따라 변동될 수 있습니다. 장기 지연 시 앱 알림 또는 고객센터를 통해 안내하며, 필요 시 보상 정책을 별도 공지합니다.',
        ),
        _PolicySection(
          heading: '제7조 (금지행위)',
          content:
              '회원은 불법·유해 콘텐츠 업로드, 타인의 권리 침해, 시스템 부하 유발 행위를 해서는 안 됩니다. 위반 시 회사는 사전 통지 후 콘텐츠 삭제, 이용 제한, 계정 해지를 할 수 있습니다.',
        ),
        _PolicySection(
          heading: '제8조 (계약 해지 및 책임 제한)',
          content:
              '회원은 언제든 탈퇴할 수 있습니다. 회사는 천재지변, 불가항력, 이용자 귀책 사유로 발생한 손해에 대해 관련 법령 범위 내에서 책임을 제한합니다.',
        ),
        _PolicySection(
          heading: '문의',
          content: '정책 관련 문의: 앱 내 고객센터 또는 support@snapfit.app',
        ),
      ],
    ),
    _PolicyDoc(
      title: '개인정보 처리방침',
      summary: '수집 항목, 이용 목적, 보관 기간, 파기 절차 및 이용자 권리를 안내합니다.',
      version: 'v1.3',
      effectiveDate: '2026.04.01',
      body: [
        _PolicySection(
          heading: '1. 수집하는 개인정보',
          content:
              '회사는 로그인 식별 정보(이메일 또는 고유식별자), 프로필 정보, 서비스 이용기록(접속 로그, 주문·결제 상태), 배송 정보(수령인, 주소, 연락처)를 수집할 수 있습니다.',
        ),
        _PolicySection(
          heading: '2. 이용 목적',
          content:
              '회원 식별, 주문/결제 처리, 배송 수행, 고객 문의 대응, 서비스 품질 개선 및 부정 이용 방지를 위해 개인정보를 이용합니다.',
        ),
        _PolicySection(
          heading: '3. 보관 및 파기',
          content:
              '회원 탈퇴 시 관련 법령에 따라 보관이 필요한 정보를 제외하고 지체 없이 파기합니다. 전자적 파일은 복구 불가능한 방식으로 삭제하며, 출력물은 분쇄 또는 소각합니다.',
        ),
        _PolicySection(
          heading: '4. 제3자 제공 및 처리위탁',
          content:
              '배송 및 결제 처리를 위해 필요한 범위에서만 수탁사 또는 제휴사에 정보를 제공·위탁할 수 있습니다. 제공/위탁 항목과 목적은 결제·주문 화면 또는 별도 고지를 통해 안내합니다.',
        ),
        _PolicySection(
          heading: '5. 보관 기간(주요 항목)',
          content:
              '주문/결제 관련 정보는 관계 법령(전자상거래법, 국세기본법 등)에 따라 일정 기간 보관될 수 있습니다. 법령상 보관 기간 경과 시 지체 없이 파기합니다.',
        ),
        _PolicySection(
          heading: '6. 이용자 권리',
          content:
              '이용자는 개인정보 열람, 정정, 삭제, 처리정지 및 동의 철회를 요청할 수 있습니다. 회사는 관련 법령에 따라 지체 없이 조치합니다.',
        ),
        _PolicySection(
          heading: '7. 개인정보 보호책임자',
          content: '이메일: privacy@snapfit.app',
        ),
      ],
    ),
    _PolicyDoc(
      title: '마케팅 정보 수신 동의',
      summary: '혜택/이벤트 알림 수신 범위와 수신 거부(철회) 방법을 안내합니다.',
      version: 'v1.1',
      effectiveDate: '2026.03.31',
      body: [
        _PolicySection(
          heading: '1. 수신 항목',
          content: '신규 템플릿 출시, 프로모션, 쿠폰, 이벤트, 서비스 업데이트 소식을 푸시/이메일로 전달할 수 있습니다.',
        ),
        _PolicySection(
          heading: '2. 수신 동의 철회',
          content:
              '앱의 알림 설정 또는 마케팅 수신 설정에서 언제든지 철회할 수 있습니다. 철회 후에도 주문/결제/배송 등 필수 안내는 발송될 수 있습니다.',
        ),
        _PolicySection(
          heading: '3. 유효기간',
          content: '관련 법령에 따라 장기 미이용자 또는 수신 동의 경과 시 재동의를 요청할 수 있습니다.',
        ),
      ],
    ),
    _PolicyDoc(
      title: '오픈소스 라이선스',
      summary: '앱에서 사용하는 오픈소스 구성요소와 라이선스 고지 정보입니다.',
      version: 'v1.0',
      effectiveDate: '2026.03.31',
      body: [
        _PolicySection(
          heading: '고지 범위',
          content:
              'SnapFit 앱 및 서버에서 사용하는 오픈소스 소프트웨어의 라이선스 정보는 법적 고지 의무를 준수하기 위해 제공됩니다.',
        ),
        _PolicySection(
          heading: '라이선스 확인',
          content: '각 라이브러리의 원저작권 및 라이선스 전문은 저장소 또는 공식 배포처에서 확인할 수 있습니다.',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final targetDoc = _docByType(initialDocType);
    if (targetDoc != null) {
      return _TermsDetailScreen(doc: targetDoc);
    }
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
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
        itemCount: _docs.length,
        separatorBuilder: (_, __) => SizedBox(height: 10.h),
        itemBuilder: (context, index) {
          final doc = _docs[index];
          return InkWell(
            borderRadius: BorderRadius.circular(14.r),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => _TermsDetailScreen(doc: doc)),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          doc.title,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: SnapFitColors.textPrimaryOf(context),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 20.sp,
                        color: SnapFitColors.textSecondaryOf(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    doc.summary,
                    style: TextStyle(
                      fontSize: 11.sp,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: SnapFitColors.textSecondaryOf(context),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '버전 ${doc.version} · 시행일 ${doc.effectiveDate}',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      color: SnapFitColors.textMutedOf(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  _PolicyDoc? _docByType(TermsPolicyDocType? type) {
    if (type == null) return null;
    switch (type) {
      case TermsPolicyDocType.terms:
        return _docs[0];
      case TermsPolicyDocType.privacy:
        return _docs[1];
      case TermsPolicyDocType.marketing:
        return _docs[2];
      case TermsPolicyDocType.opensource:
        return _docs[3];
    }
  }
}

class _TermsDetailScreen extends StatelessWidget {
  const _TermsDetailScreen({required this.doc});

  final _PolicyDoc doc;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: SnapFitColors.backgroundOf(context),
        elevation: 0,
        leading: const SnapFitAppBarBackButton(),
        title: Text(
          doc.title,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 24.h),
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: SnapFitColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: SnapFitColors.overlayLightOf(context)),
            ),
            child: Text(
              '버전 ${doc.version}\n시행일 ${doc.effectiveDate}\n최종 개정일 ${doc.effectiveDate}',
              style: TextStyle(
                fontSize: 11.sp,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: SnapFitColors.textSecondaryOf(context),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          ...doc.body.map(
            (section) => Padding(
              padding: EdgeInsets.only(bottom: 14.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.heading,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                      color: SnapFitColors.textPrimaryOf(context),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    section.content,
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                      color: SnapFitColors.textPrimaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyDoc {
  const _PolicyDoc({
    required this.title,
    required this.summary,
    required this.version,
    required this.effectiveDate,
    required this.body,
  });

  final String title;
  final String summary;
  final String version;
  final String effectiveDate;
  final List<_PolicySection> body;
}

class _PolicySection {
  const _PolicySection({required this.heading, required this.content});

  final String heading;
  final String content;
}

enum TermsPolicyDocType { terms, privacy, marketing, opensource }
