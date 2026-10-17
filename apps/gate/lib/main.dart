import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env.dart';
import 'core/providers.dart';
import 'core/router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Env.hasSupabase) {
    runApp(const SetupApp());
    return;
  }
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );
  runApp(const ProviderScope(child: OmisGateApp()));
}

class OmisGateApp extends ConsumerWidget {
  const OmisGateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Register for push once an operator is signed in; tapping a notification
    // opens the request (approvers) or home (guards).
    ref.listen(profileProvider, (previous, next) {
      final profile = next.value;
      if (profile == null ||
          !profile.isOperator ||
          previous?.value?.id == profile.id) {
        return;
      }
      final router = ref.read(routerProvider);
      ref
          .read(pushServiceProvider)
          .start(
            onToken: (token) => ref
                .read(gateRepositoryProvider)
                .setPushToken(profile.id, token),
            onOpen: (passId) => profile.canApprove
                ? router.push('/approvals/$passId')
                : router.go('/home'),
          );
    });

    return MaterialApp.router(
      title: 'OMIS Entry',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

/// Shown when the app was built without Supabase settings.
class SetupApp extends StatelessWidget {
  const SetupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OMIS Entry',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) {
          final text = Theme.of(context).textTheme;
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screen),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/logo.png', width: 96, height: 96),
                      const SizedBox(height: AppSpacing.s3),
                      Text('OMIS Entry', style: text.headlineMedium),
                      const SizedBox(height: AppSpacing.s1),
                      Text(
                        'Supabase not configured — run with --dart-define-from-file=env/dev.json',
                        textAlign: TextAlign.center,
                        style: text.bodyLarge?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
