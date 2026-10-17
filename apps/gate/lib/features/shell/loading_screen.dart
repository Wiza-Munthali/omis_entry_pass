import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Shown while sign-in state, profile and gate load; offers retry if the profile fails.
class LoadingScreen extends ConsumerWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Center(
            child: profile.hasError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.wifi_off,
                        size: 48,
                        color: AppColors.warning,
                      ),
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        'Could not load your account',
                        style: text.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.s1),
                      Text(
                        '${profile.error}',
                        style: text.bodyLarge?.copyWith(
                          color: AppColors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.s3),
                      FilledButton(
                        onPressed: () => ref.invalidate(profileProvider),
                        child: const Text('Try again'),
                      ),
                      const SizedBox(height: AppSpacing.s1),
                      OutlinedButton(
                        onPressed: () =>
                            ref.read(authRepositoryProvider).signOut(),
                        child: const Text('Sign out'),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(color: AppColors.brandStrong),
          ),
        ),
      ),
    );
  }
}
