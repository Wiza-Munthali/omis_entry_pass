import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models.dart';

final activeGatesProvider = FutureProvider<List<Gate>>(
  (ref) => ref.watch(gateRepositoryProvider).activeGates(),
);

/// G2 Choose gate: remembered on this phone for the next sign-in.
class ChooseGateScreen extends ConsumerWidget {
  const ChooseGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gates = ref.watch(activeGatesProvider);
    final current = ref.watch(selectedGateProvider).value;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            Text('Choose your gate', style: t.headlineMedium),
            const SizedBox(height: AppSpacing.s1),
            Text(
              'This phone remembers it for the next shift.',
              style: t.bodyLarge?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.s3),
            ...gates.when(
              loading: () => [
                const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.brandStrong,
                  ),
                ),
              ],
              error: (e, _) => [
                Text(
                  '$e',
                  style: t.bodyLarge?.copyWith(color: AppColors.danger),
                ),
                const SizedBox(height: AppSpacing.s2),
                FilledButton(
                  onPressed: () => ref.invalidate(activeGatesProvider),
                  child: const Text('Try again'),
                ),
              ],
              data: (list) => list.isEmpty
                  ? [
                      Text(
                        'No gates are open. Ask an admin to add one.',
                        style: t.bodyLarge,
                      ),
                    ]
                  : [
                      for (final gate in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Card(
                            child: ListTile(
                              key: Key('gate-${gate.id}'),
                              minTileHeight: 72,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.card,
                                ),
                              ),
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.brandSoft,
                                child: Icon(
                                  Icons.door_sliding_outlined,
                                  color: AppColors.brandStrong,
                                ),
                              ),
                              title: Text(gate.name, style: t.titleLarge),
                              trailing: current?.id == gate.id
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: AppColors.brandStrong,
                                    )
                                  : const Icon(
                                      Icons.chevron_right,
                                      color: AppColors.textMuted,
                                    ),
                              onTap: () async {
                                await ref
                                    .read(selectedGateProvider.notifier)
                                    .select(gate);
                                if (context.mounted) context.go('/home');
                              },
                            ),
                          ),
                        ),
                    ],
            ),
            const SizedBox(height: AppSpacing.s2),
            TextButton(
              onPressed: () => signOut(ref),
              child: const Text(
                'Sign out',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
