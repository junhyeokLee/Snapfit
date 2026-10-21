import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/widgets/experience_form_style.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/commerce/commerce_policy.dart';
import '../../../../shared/web/web_design.dart';
import '../widgets/customer_web_page.dart';

class TermsPolicyScreen extends StatelessWidget {
  const TermsPolicyScreen({super.key, this.initialDocType});

  final TermsPolicyDocType? initialDocType;

  static final List<CommercePolicyDocument> _docs = [
    for (final kind in CommercePolicyKind.values) CommercePolicy.document(kind),
  ];

  @override
  Widget build(BuildContext context) {
    final targetDoc = _docByType(initialDocType);
    if (targetDoc != null) return _TermsDetailScreen(doc: targetDoc);
    if (kIsWeb) return _webIndex(context);
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: const ExperienceHeader(title: '이용 안내', themeAware: true),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              children: [
                Text(
                  '약관과 정책',
                  style: ExperienceFormStyle.text(
                    context,
                    24,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                for (final doc in _docs)
                  ExperienceRow(
                    themeAware: true,
                    icon: Icons.description_outlined,
                    title: doc.title,
                    subtitle: doc.summary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _TermsDetailScreen(doc: doc),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _webIndex(BuildContext context) => CustomerWebPage(
    title: '약관과 정책',
    eyebrow: 'POLICIES',
    description: '스냅핏의 서비스 이용 기준과 개인정보 보호 안내를 확인하세요.',
    scrollBody: true,
    sidebar: const CustomerWebNote(
      title: '문서 안내',
      message:
          '현재는 운영 전 준비본입니다. 실제 결제는 열려 있지 않습니다. 문서 열람은 수신 동의나 약관 동의를 변경하지 않습니다.',
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < _docs.length; index++) ...[
          if (index > 0) const Divider(height: 1),
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => _TermsDetailScreen(doc: _docs[index]),
              ),
            ),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 26,
                    color: WebPalette.of(context).brandInk,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _docs[index].title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: WebPalette.of(context).ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _docs[index].summary,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.8,
                            color: WebPalette.of(context).muted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${_docs[index].version} · 시행일 ${_docs[index].effectiveDate}',
                          style: TextStyle(
                            fontSize: 12,
                            color: WebPalette.of(context).muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.arrow_forward,
                    size: 20,
                    color: WebPalette.of(context).muted,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );

  CommercePolicyDocument? _docByType(TermsPolicyDocType? type) {
    if (type == null) return null;
    return CommercePolicy.document(switch (type) {
      TermsPolicyDocType.terms => CommercePolicyKind.terms,
      TermsPolicyDocType.privacy => CommercePolicyKind.privacy,
      TermsPolicyDocType.marketing => CommercePolicyKind.marketing,
      TermsPolicyDocType.opensource => CommercePolicyKind.opensource,
      TermsPolicyDocType.refund => CommercePolicyKind.refund,
      TermsPolicyDocType.shipping => CommercePolicyKind.shipping,
      TermsPolicyDocType.seller => CommercePolicyKind.seller,
    });
  }
}

class _TermsDetailScreen extends StatelessWidget {
  const _TermsDetailScreen({required this.doc});
  final CommercePolicyDocument doc;
  @override
  Widget build(BuildContext context) => kIsWeb
      ? _webDocument(context)
      : Scaffold(
          backgroundColor: SnapFitColors.backgroundOf(context),
          appBar: ExperienceHeader(title: doc.title, themeAware: true),
          body: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  children: [
                    Text(
                      '버전 ${doc.version} · 시행일 ${doc.effectiveDate}',
                      style: ExperienceFormStyle.text(
                        context,
                        13,
                        secondary: true,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '준비본 갱신일 ${CommercePolicy.updatedDate}',
                      style: ExperienceFormStyle.text(
                        context,
                        13,
                        secondary: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Divider(
                      color: ExperienceFormStyle.line(context),
                      height: 1,
                    ),
                    const SizedBox(height: 28),
                    for (final section in doc.sections)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section.heading,
                              style: ExperienceFormStyle.text(
                                context,
                                17,
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SelectableText(
                              section.content,
                              style: ExperienceFormStyle.text(
                                context,
                                14,
                              ).copyWith(height: 1.8),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );

  Widget _webDocument(BuildContext context) => CustomerWebPage(
    title: doc.title,
    eyebrow: 'POLICIES',
    description: doc.summary,
    scrollBody: true,
    sidebar: CustomerWebNote(
      title: '문서 정보',
      message:
          '버전 ${doc.version}\n\n시행일 ${doc.effectiveDate}\n\n준비본 갱신일 ${CommercePolicy.updatedDate}',
    ),
    child: SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < doc.sections.length; index++) ...[
            if (index > 0) const SizedBox(height: 36),
            Text(
              doc.sections[index].heading,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.5,
                color: WebPalette.of(context).ink,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              doc.sections[index].content,
              style: TextStyle(
                fontSize: 15,
                height: 1.9,
                color: WebPalette.of(context).ink,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

enum TermsPolicyDocType {
  terms,
  privacy,
  marketing,
  opensource,
  refund,
  shipping,
  seller,
}
