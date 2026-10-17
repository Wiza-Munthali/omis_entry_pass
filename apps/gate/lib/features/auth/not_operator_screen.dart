import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Signed in, but not an active guard, receptionist or admin (e.g. a staff member).
class NotOperatorScreen extends ConsumerWidget {
  const NotOperatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            children: [
              const Spacer(),
              const Icon(
                Icons.lock_outline,
                size: 56,
                color: AppColors.warning,
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                'This app is for gate staff',
                style: t.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s1),
              Text(
                'Your account is not set up as a guard, receptionist or admin, or it has been switched off. '
                'Staff and visitors can get their pass on the OMIS Entry website.',
                style: t.bodyLarge?.copyWith(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => signOut(ref),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
