import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models.dart';
import 'account_sheet.dart';
import 'offline_banner.dart';

class NavItem {
  const NavItem(this.label, this.icon, this.location);
  final String label;
  final IconData icon;

  /// Route to open; null opens the account sheet ("More").
  final String? location;
}

const _home = NavItem('Home', Icons.home_outlined, '/home');
const _scan = NavItem('Scan', Icons.qr_code_scanner, '/scan');
const _onSite = NavItem('On site', Icons.groups_outlined, '/on-site');

/// Bottom navigation by role (docs/SPEC.md → Screen brief: gate app):
/// guard: Home · Scan · On site · New visitor; receptionist/admin: Home · Scan · Approvals · On site · More.
List<NavItem> navItemsFor(OperatorRole? role) =>
    role == OperatorRole.guard || role == null
    ? const [
        _home,
        _scan,
        _onSite,
        NavItem('New visitor', Icons.person_add_alt, '/new-visitor'),
      ]
    : const [
        _home,
        _scan,
        NavItem('Approvals', Icons.fact_check_outlined, '/approvals'),
        _onSite,
        NavItem('More', Icons.more_horiz, null),
      ];

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final items = navItemsFor(profile?.role);
    final pending = profile?.canApprove == true
        ? (ref.watch(pendingCountProvider).value ?? 0)
        : 0;
    ref.watch(syncWorkerProvider); // sync and cache refresh run while signed in
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: _bannerShowing(ref),
              child: child,
            ),
          ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          AppSpacing.s1,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: ShapeDecoration(
            color: AppColors.border,
            shape: const StadiumBorder(),
          ),
          // Equal shares of the width, so five tabs fit on a 320 dp phone.
          child: Row(
            children: [
              for (final item in items)
                Expanded(
                  child: _NavButton(
                    item: item,
                    active: item.location == location,
                    badge: item.location == '/approvals' ? pending : 0,
                    onTap: () {
                      if (item.location == null) {
                        showAccountSheet(context, ref);
                      } else if (item.location == '/scan') {
                        context.push('/scan');
                      } else {
                        context.go(item.location!);
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.active,
    required this.onTap,
    this.badge = 0,
  });

  final NavItem item;
  final bool active;
  final VoidCallback onTap;

  /// Count bubble (pending approvals); hidden at 0.
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: Key('nav-${item.label}'),
      button: true,
      selected: active,
      label: badge > 0 ? '${item.label}, $badge waiting' : item.label,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: active ? AppColors.ink : AppColors.surface2,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item.icon,
                      color: active ? AppColors.brand : AppColors.ink,
                    ),
                  ),
                  if (badge > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 22),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: const ShapeDecoration(
                          color: AppColors.danger,
                          shape: StadiumBorder(),
                        ),
                        child: Text(
                          badge > 99 ? '99+' : '$badge',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.surface,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              ExcludeSemantics(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? AppColors.brandStrong : AppColors.text,
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

/// Whether the offline banner is visible (it then takes care of the status-bar inset).
bool _bannerShowing(WidgetRef ref) {
  final online = ref.watch(onlineProvider).value ?? true;
  final waiting = ref.watch(outboxCountProvider).value ?? 0;
  final failed = ref.watch(outboxFailedProvider).value ?? 0;
  return !online || waiting > 0 || failed > 0;
}
