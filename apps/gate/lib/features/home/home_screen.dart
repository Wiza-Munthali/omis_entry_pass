import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time.dart';
import '../../core/widgets.dart';
import '../shell/account_sheet.dart';

/// G3 Guard home (and, until Phase 6 adds approvals, the receptionist/admin home).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final gate = ref.watch(selectedGateProvider).value;
    final stats = ref.watch(gateStatsProvider);
    final t = Theme.of(context).textTheme;

    String count(int Function(dynamic) pick) => stats.when(
      data: (s) => '${pick(s)}',
      loading: () => '–',
      error: (_, _) => '?',
    );

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.brandStrong,
        onRefresh: () => ref.refresh(gateStatsProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.s2,
            AppSpacing.screen,
            120,
          ),
          children: [
            Row(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.brand,
                    shape: BoxShape.circle,
                  ),
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  child: Text(
                    profile == null ? '' : initials(profile.fullName),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.surface,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, ${profile?.firstName ?? ''}',
                        style: t.titleLarge,
                      ),
                      Text(
                        gate?.name ?? '',
                        style: t.bodyLarge?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                CircleIconButton(
                  icon: Icons.more_horiz,
                  tooltip: 'Account',
                  background: AppColors.surface,
                  onPressed: () => showAccountSheet(context, ref),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            if (stats.hasError)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s1),
                child: Text(
                  '${stats.error}',
                  style: t.labelLarge?.copyWith(color: AppColors.danger),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.groups,
                    value: count((s) => s.onSite),
                    label: 'On site',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    icon: Icons.login,
                    value: count((s) => s.entriesToday),
                    label: 'Entries today',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s2),
            SizedBox(
              height: 72,
              child: FilledButton.icon(
                key: const Key('scan-pass'),
                onPressed: () async {
                  await context.push('/scan');
                  ref.invalidate(gateStatsProvider);
                },
                icon: const Icon(Icons.qr_code_scanner, size: 32),
                label: const Text(
                  'Scan pass',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s3),
              decoration: BoxDecoration(
                color: AppColors.ink2,
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick actions',
                    style: t.titleLarge?.copyWith(color: AppColors.surface),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  _DarkAction(
                    icon: Icons.groups_outlined,
                    label: 'Who is on site',
                    onTap: () => context.go('/on-site'),
                  ),
                  const SizedBox(height: 12),
                  _DarkAction(
                    icon: Icons.person_add_alt,
                    label: 'Register a visitor',
                    onTap: () => context.go('/new-visitor'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkAction extends StatelessWidget {
  const _DarkAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s2),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.brandSoft,
                child: Icon(icon, color: AppColors.brandStrong),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
