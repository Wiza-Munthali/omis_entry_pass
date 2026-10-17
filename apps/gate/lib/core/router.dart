import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/approvals/approvals_screen.dart';
import '../features/approvals/request_detail_screen.dart';
import '../features/auth/not_operator_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/gate/choose_gate_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onsite/on_site_screen.dart';
import '../features/requests/new_visitor_screen.dart';
import '../features/requests/waiting_screen.dart';
import '../features/scan/scanner_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/shell/loading_screen.dart';
import 'providers.dart';
import 'redirect.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run the redirect whenever sign-in, profile or gate changes.
  final refresh = ValueNotifier(0);
  void bump(_, _) => refresh.value++;
  ref.listen(userIdProvider, bump);
  ref.listen(profileProvider, bump);
  ref.listen(selectedGateProvider, bump);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/loading',
    refreshListenable: refresh,
    redirect: (context, state) => resolveRedirect(
      location: state.matchedLocation,
      userId: ref.read(userIdProvider),
      profile: ref.read(profileProvider),
      gate: ref.read(selectedGateProvider),
    ),
    routes: [
      GoRoute(path: '/loading', builder: (_, _) => const LoadingScreen()),
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(
        path: '/not-operator',
        builder: (_, _) => const NotOperatorScreen(),
      ),
      GoRoute(path: '/gate', builder: (_, _) => const ChooseGateScreen()),
      // Full-screen camera, outside the tab bar.
      GoRoute(path: '/scan', builder: (_, _) => const ScannerScreen()),
      GoRoute(
        path: '/approvals/:id',
        builder: (_, state) =>
            RequestDetailScreen(passId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/requests/:id',
        builder: (_, state) =>
            WaitingScreen(passId: state.pathParameters['id']!),
      ),
      ShellRoute(
        builder: (_, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (_, _) => const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/on-site',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: OnSiteScreen()),
          ),
          GoRoute(
            path: '/new-visitor',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: NewVisitorScreen()),
          ),
          GoRoute(
            path: '/approvals',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: ApprovalsScreen()),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
