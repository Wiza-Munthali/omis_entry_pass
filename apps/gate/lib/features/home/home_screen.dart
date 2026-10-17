import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ago.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time.dart';
import '../../core/widgets.dart';
import '../../data/approvals_repository.dart';
import '../../data/request_models.dart';
import '../approvals/approvals_screen.dart';
import '../approvals/request_widgets.dart';
import '../shell/account_sheet.dart';

/// G3 Guard home and R1 Receptionist/admin home: same header and Scan button;
/// guards see their requests waiting for approval, approvers see what needs approving.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final gate = ref.watch(selectedGateProvider).value;
    final stats = ref.watch(gateStatsProvider);
    final approver = profile?.canApprove ?? false;
    final t = Theme.of(context).textTheme;

    String statText(AsyncValue<int> v) =>
        v.when(data: (n) => '$n', loading: () => '–', error: (_, _) => '?');

    Future<void> refresh() async {
      ref.invalidate(gateStatsProvider);
      if (approver) {
        ref.invalidate(pendingCountProvider);
        ref.invalidate(requestsProvider(RequestTab.pending));
        ref.invalidate(recentActivityProvider);
      } else {
        ref.invalidate(myGateRequestsProvider);
      }
      try {
        await ref.read(gateStatsProvider.future);
      } catch (_) {
        // The error is shown on the screen.
      }
    }

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.brandStrong,
        onRefresh: refresh,
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
                  child: approver
                      ? StatCard(
                          icon: Icons.pending_actions,
                          value: statText(ref.watch(pendingCountProvider)),
                          label: 'Pending',
                        )
                      : StatCard(
                          icon: Icons.groups,
                          value: statText(stats.whenData((s) => s.onSite)),
                          label: 'On site',
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: approver
                      ? StatCard(
                          icon: Icons.groups,
                          value: statText(stats.whenData((s) => s.onSite)),
                          label: 'On site',
                        )
                      : StatCard(
                          icon: Icons.login,
                          value: statText(
                            stats.whenData((s) => s.entriesToday),
                          ),
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
            if (approver) const _NeedsApproval() else const _MyRequests(),
          ],
        ),
      ),
    );
  }
}

/// Dark lower section with a title (spec: dark hero section on home screens).
class _DarkSection extends StatelessWidget {
  const _DarkSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s2),
      decoration: BoxDecoration(
        color: AppColors.ink2,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: AppColors.surface),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

/// Guard: their own requests (pending first), then quick actions.
class _MyRequests extends ConsumerWidget {
  const _MyRequests();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(myGateRequestsProvider);
    final list = [...?requests.value]
      ..sort(
        (a, b) => (a.status == RequestStatus.pending ? 0 : 1).compareTo(
          b.status == RequestStatus.pending ? 0 : 1,
        ),
      );
    final shown = list.take(4).toList();

    return _DarkSection(
      title: 'Waiting for approval',
      children: [
        if (requests.isLoading && !requests.hasValue)
          const Center(child: CircularProgressIndicator(color: AppColors.brand))
        else if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Visitors you register at the gate show here until reception decides.',
              style: TextStyle(color: AppColors.surface2),
            ),
          ),
        for (final r in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              child: ListTile(
                key: Key('my-request-${r.passId}'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                leading: Avatar(name: r.fullName, isStaff: false, size: 44),
                title: Text(
                  r.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${r.hostName ?? ''} · ${formatTime(r.requestedAt)}',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                trailing: statusChip(
                  r.status,
                  escalated: r.escalatedAt != null,
                ),
                onTap: () => context.push('/requests/${r.passId}'),
              ),
            ),
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _DarkAction(
                icon: Icons.person_add_alt,
                label: 'New visitor',
                onTap: () => context.go('/new-visitor'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DarkAction(
                icon: Icons.groups_outlined,
                label: 'On site',
                onTap: () => context.go('/on-site'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Receptionist / admin: the oldest three pending requests with inline decisions,
/// then today's activity at the gates.
class _NeedsApproval extends ConsumerWidget {
  const _NeedsApproval();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(requestsProvider(RequestTab.pending));
    final activity = ref.watch(recentActivityProvider);
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Needs approval', style: t.titleLarge)),
            TextButton(
              onPressed: () => context.go('/approvals'),
              child: const Text(
                'View all',
                style: TextStyle(color: AppColors.brandStrong),
              ),
            ),
          ],
        ),
        ...pending.when(
          loading: () => [
            const Center(
              child: CircularProgressIndicator(color: AppColors.brandStrong),
            ),
          ],
          error: (e, _) => [
            Text('$e', style: const TextStyle(color: AppColors.danger)),
          ],
          data: (list) => list.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Nothing waiting. New requests appear here straight away.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ]
              : [
                  for (final r in list.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: RequestCard(request: r, compact: true),
                    ),
                ],
        ),
        const SizedBox(height: AppSpacing.s1),
        _DarkSection(
          title: "Today's activity",
          children: activity.when(
            loading: () => [
              const Center(
                child: CircularProgressIndicator(color: AppColors.brand),
              ),
            ],
            error: (e, _) => [
              Text('$e', style: const TextStyle(color: AppColors.surface2)),
            ],
            data: (items) => items.isEmpty
                ? [
                    const Text(
                      'No entries yet today.',
                      style: TextStyle(color: AppColors.surface2),
                    ),
                  ]
                : [
                    for (final a in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10, left: 4),
                        child: Row(
                          children: [
                            Icon(
                              a.exitAt == null ? Icons.login : Icons.logout,
                              color: AppColors.brand,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${a.fullName} ${a.exitAt == null ? 'came in' : 'left'}${a.gateName.isEmpty ? '' : ' · ${a.gateName}'}',
                                style: const TextStyle(
                                  color: AppColors.surface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              timeAgo(a.latest),
                              style: const TextStyle(
                                color: AppColors.surface2,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
          ),
        ),
      ],
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.brandStrong),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
