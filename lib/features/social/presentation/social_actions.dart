import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/navigation/web_app_location.dart';
import '../../../shared/web/web_design.dart';
import '../../auth/presentation/views/login_screen.dart';
import 'providers/social_providers.dart';

Future<bool> requireSocialLogin(BuildContext context, WidgetRef ref) async {
  if (ref.read(socialCurrentUserIdProvider) != null) return true;
  final proceed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('로그인하고 기록을 이어가세요.'),
      content: const Text('작품 공개와 저장, 좋아요와 소통은 로그인 후 이용할 수 있어요.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('계속 둘러보기'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('로그인'),
        ),
      ],
    ),
  );
  if (proceed == true && context.mounted) {
    // Keep the public route underneath. The auth root also preserves public
    // destinations on a session change; no action is replayed automatically.
    final web = WebNavigationScope.maybeOf(context)?.onPublicNavigate;
    if (kIsWeb && web != null) {
      web(WebAppLocation.login);
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }
  return false;
}

void invalidateSocial(WidgetRef ref, {String? workId}) {
  ref.invalidate(socialFeedProvider);
  ref.invalidate(socialOwnWorksProvider);
  ref.invalidate(socialOwnWorksPageProvider);
  ref.invalidate(socialSavedWorksProvider);
  ref.invalidate(socialSavedWorksPageProvider);
  ref.invalidate(socialProfileWorksProvider);
  ref.invalidate(socialProfileWorksPageProvider);
  ref.invalidate(socialProfileProvider);
  ref.invalidate(ownSocialProfileProvider);
  if (workId != null) ref.invalidate(socialWorkProvider(workId));
}
