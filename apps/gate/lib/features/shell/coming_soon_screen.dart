import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Placeholder for tabs built in Phase 6 (New visitor, Approvals).
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: t.headlineMedium),
            const SizedBox(height: AppSpacing.s2),
            Text(
              text,
              style: t.bodyLarge?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
