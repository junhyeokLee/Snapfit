import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../../shared/widgets/experience_form_style.dart';

class HomeErrorState extends StatelessWidget {
  const HomeErrorState({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final type = error is DioException ? (error as DioException).type : null;
    final timeout =
        type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.receiveTimeout ||
        type == DioExceptionType.sendTimeout;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - 48),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 32,
                    color: ExperienceFormStyle.muted(context),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '앨범을 불러오지 못했어요',
                    textAlign: TextAlign.center,
                    style: ExperienceFormStyle.text(
                      context,
                      20,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    timeout
                        ? '연결이 지연되고 있어요. 잠시 후 다시 시도해주세요.'
                        : type == DioExceptionType.connectionError
                        ? '네트워크 연결을 확인해주세요.'
                        : '잠시 후 다시 시도해주세요.',
                    textAlign: TextAlign.center,
                    style: ExperienceFormStyle.text(
                      context,
                      14,
                      secondary: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onRetry,
                    style: ExperienceFormStyle.primary(context),
                    icon: const Icon(Icons.refresh, size: 20),
                    label: const Text('다시 불러오기'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
