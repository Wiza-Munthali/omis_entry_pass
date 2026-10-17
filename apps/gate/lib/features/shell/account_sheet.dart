import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Account actions: who is signed in, change gate, sign out.
Future<void> showAccountSheet(BuildContext context, WidgetRef ref) {
  final profile = ref.read(profileProvider).value;
  final gate = ref.read(selectedGateProvider).value;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          AppSpacing.screen,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              profile?.fullName ?? '',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            Text(
              '${profile?.email ?? ''} · ${profile?.role?.name ?? ''}',
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.s3),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.surface2,
              ),
              icon: const Icon(Icons.door_sliding_outlined),
              label: Text('Change gate (${gate?.name ?? 'none'})'),
              onPressed: () {
                Navigator.of(sheetContext).pop();
                context.go('/gate');
              },
            ),
            const SizedBox(height: AppSpacing.s1),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.surface2,
                foregroundColor: AppColors.danger,
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
              onPressed: () {
                Navigator.of(sheetContext).pop();
                ref.read(authRepositoryProvider).signOut();
              },
            ),
          ],
        ),
      ),
    ),
  );
}
