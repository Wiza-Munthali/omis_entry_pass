import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';

/// Persistent strip at the top while offline or while scans wait to sync
/// (docs/SPEC.md → "Offline — N scans waiting to sync").
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineProvider).value ?? true;
    final waiting = ref.watch(outboxCountProvider).value ?? 0;
    final failed = ref.watch(outboxFailedProvider).value ?? 0;

    final (String? text, Color fg, Color bg, IconData icon) = switch ((
      online,
      waiting,
      failed,
    )) {
      (false, final n, _) => (
        n == 0
            ? 'Offline — scans are saved on this phone'
            : 'Offline — $n ${n == 1 ? 'scan' : 'scans'} waiting to sync',
        AppColors.warning,
        AppColors.warningSoft,
        Icons.cloud_off,
      ),
      (true, final n, _) when n > 0 => (
        'Syncing $n waiting ${n == 1 ? 'item' : 'items'}…',
        AppColors.info,
        AppColors.infoSoft,
        Icons.sync,
      ),
      (true, _, final f) when f > 0 => (
        '$f ${f == 1 ? 'item' : 'items'} could not sync — tell an admin',
        AppColors.danger,
        AppColors.dangerSoft,
        Icons.error_outline,
      ),
      _ => (null, AppColors.text, AppColors.bg, Icons.check),
    };
    if (text == null) return const SizedBox.shrink();

    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('offline-banner'),
        width: double.infinity,
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(color: fg, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
