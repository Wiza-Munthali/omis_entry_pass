import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Env.hasSupabase) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
    );
  }
  runApp(const OmisGateApp());
}

class OmisGateApp extends StatelessWidget {
  const OmisGateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OMIS Entry',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const SetupScreen(),
    );
  }
}

/// Placeholder until sign-in (G1) is built in Phase 5.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            children: [
              const Spacer(),
              Image.asset('assets/logo.png', width: 96, height: 96),
              const SizedBox(height: AppSpacing.s3),
              Text('OMIS Entry', style: text.headlineMedium),
              const SizedBox(height: AppSpacing.s1),
              Text(
                Env.hasSupabase
                    ? 'Connected to ${Env.supabaseUrl}'
                    : 'Supabase not configured — run with --dart-define-from-file=env/dev.json',
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(color: AppColors.textMuted),
              ),
              const Spacer(),
              FilledButton(onPressed: () {}, child: const Text('Scan pass')),
            ],
          ),
        ),
      ),
    );
  }
}
