import 'package:flutter/material.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../printing/redprinting_fulfillment_policy.dart';

/// Production reference shown while physical checkout is being prepared.
class PrintFulfillmentNotice extends StatelessWidget {
  const PrintFulfillmentNotice({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '제작·배송 참고 안내',
        style: ExperienceFormStyle.text(context, 15, weight: FontWeight.w600),
      ),
      const SizedBox(height: 10),
      Text(
        RedprintingFulfillmentPolicy.dispatchEstimate,
        style: ExperienceFormStyle.text(context, 13),
      ),
      const SizedBox(height: 6),
      Text(
        '제작사의 출고 예상이며, 고객에게 도착하는 날짜를 뜻하지 않습니다.',
        style: ExperienceFormStyle.text(context, 13, secondary: true),
      ),
      const SizedBox(height: 8),
      Text(
        '제작사 기본 포장: ${RedprintingFulfillmentPolicy.packagingNotice}',
        style: ExperienceFormStyle.text(context, 13, secondary: true),
      ),
    ],
  );
}
