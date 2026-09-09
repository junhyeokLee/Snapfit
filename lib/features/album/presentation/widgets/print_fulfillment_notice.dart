import 'package:flutter/material.dart';

import '../../printing/redprinting_fulfillment_policy.dart';

/// Production reference shown while physical checkout is being prepared.
class PrintFulfillmentNotice extends StatelessWidget {
  const PrintFulfillmentNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('제작·배송 참고 안내', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            const Text(RedprintingFulfillmentPolicy.dispatchEstimate),
            const SizedBox(height: 4),
            const Text('제작사의 출고 예상이며, 고객에게 도착하는 날짜를 뜻하지 않습니다.'),
            const SizedBox(height: 8),
            const Text(
              '제작사 기본 포장: ${RedprintingFulfillmentPolicy.packagingNotice}',
            ),
          ],
        ),
      ),
    );
  }
}
