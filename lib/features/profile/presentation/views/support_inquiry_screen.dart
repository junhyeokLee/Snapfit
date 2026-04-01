import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/theme/snapfit_design_tokens.dart';
import '../../../../core/utils/app_error_mapper.dart';
import '../../data/support_inquiry_repository.dart';

class SupportInquiryScreen extends ConsumerStatefulWidget {
  const SupportInquiryScreen({super.key});

  @override
  ConsumerState<SupportInquiryScreen> createState() =>
      _SupportInquiryScreenState();
}

class _SupportInquiryScreenState extends ConsumerState<SupportInquiryScreen> {
  static const List<String> _categories = <String>[
    'GENERAL',
    'ORDER',
    'PAYMENT',
    'DELIVERY',
    'BUG',
  ];

  String _category = _categories.first;
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_submitting) return;
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('제목과 내용을 모두 입력해주세요.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(supportInquiryRepositoryProvider)
          .createInquiry(
            category: _category,
            subject: subject,
            message: message,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('문의가 접수되었습니다. 빠르게 답변드릴게요.')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final msg = AppErrorMapper.toUserMessage(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('문의 접수 실패: $msg')));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = SnapFitColors.textPrimaryOf(context);
    final subColor = SnapFitColors.textSecondaryOf(context);

    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        backgroundColor: SnapFitColors.backgroundOf(context),
        appBar: AppBar(
          title: Text(
            '고객 센터',
            style: context.sfTitle(size: 17.sp, weight: FontWeight.w800),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: AbsorbPointer(
          absorbing: _submitting,
          child: ListView(
            padding: EdgeInsets.fromLTRB(18.w, 10.h, 18.w, 24.h),
            children: [
              Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: SnapFitColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: SnapFitColors.overlayLightOf(context),
                  ),
                ),
                child: Text(
                  '문의 내용을 남겨주시면 운영팀이 확인 후 순차적으로 답변드립니다.',
                  style: context.sfBody(size: 13.sp).copyWith(color: subColor),
                ),
              ),
              SizedBox(height: 14.h),
              Text(
                '문의 유형',
                style: context
                    .sfSub(size: 13.sp, weight: FontWeight.w700)
                    .copyWith(color: textColor),
              ),
              SizedBox(height: 8.h),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 12.h,
                  ),
                ),
                items: _categories
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e,
                        child: Text(
                          e,
                          style: context
                              .sfBody(size: 14.sp)
                              .copyWith(color: textColor),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _category = value);
                  }
                },
              ),
              SizedBox(height: 14.h),
              Text(
                '제목',
                style: context
                    .sfSub(size: 13.sp, weight: FontWeight.w700)
                    .copyWith(color: textColor),
              ),
              SizedBox(height: 8.h),
              TextField(
                controller: _subjectController,
                maxLength: 80,
                decoration: InputDecoration(
                  hintText: '예) 결제는 되었는데 주문이 생성되지 않았어요',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  counterText: '',
                ),
              ),
              SizedBox(height: 14.h),
              Text(
                '내용',
                style: context
                    .sfSub(size: 13.sp, weight: FontWeight.w700)
                    .copyWith(color: textColor),
              ),
              SizedBox(height: 8.h),
              TextField(
                controller: _messageController,
                minLines: 6,
                maxLines: 10,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText: '문제 상황을 자세히 적어주세요. (주문번호/시간/기기정보 등)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
              SizedBox(height: 18.h),
              SizedBox(
                height: 48.h,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: _submitting
                      ? SizedBox(
                          width: 18.w,
                          height: 18.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          '문의 접수하기',
                          style: context
                              .sfBody(size: 14.sp, weight: FontWeight.w700)
                              .copyWith(color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
