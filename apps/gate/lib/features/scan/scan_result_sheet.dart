import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';

/// How each outcome looks on the result sheet (docs/SPEC.md → G5, G6).
class OutcomeView {
  const OutcomeView({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.fg,
    required this.bg,
    required this.allowed,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color fg;
  final Color bg;
  final bool allowed;

  static OutcomeView of(ScanResult r) => switch (r.outcome) {
    ScanOutcome.entryRecorded => const OutcomeView(
      title: 'Entry recorded',
      subtitle: null,
      icon: Icons.check,
      fg: AppColors.success,
      bg: AppColors.surface2,
      allowed: true,
    ),
    ScanOutcome.exitRecorded => OutcomeView(
      title: 'Exit recorded',
      subtitle: r.duration == null
          ? null
          : 'On site ${formatDuration(r.duration!)}',
      icon: Icons.logout,
      fg: AppColors.success,
      bg: AppColors.surface2,
      allowed: true,
    ),
    ScanOutcome.alreadyCheckedOut => const OutcomeView(
      title: 'Already checked out',
      subtitle: null,
      icon: Icons.info_outline,
      fg: AppColors.info,
      bg: AppColors.infoSoft,
      allowed: true,
    ),
    ScanOutcome.pending => const OutcomeView(
      title: 'Not approved yet',
      subtitle:
          'Reception has not approved this request. Do not let them in yet.',
      icon: Icons.hourglass_top,
      fg: AppColors.warning,
      bg: AppColors.warningSoft,
      allowed: false,
    ),
    ScanOutcome.rejected => const OutcomeView(
      title: 'Request rejected',
      subtitle: 'Reception turned this request down.',
      icon: Icons.block,
      fg: AppColors.danger,
      bg: AppColors.dangerSoft,
      allowed: false,
    ),
    ScanOutcome.revoked => const OutcomeView(
      title: 'Pass revoked',
      subtitle: 'This pass has been cancelled. Call reception.',
      icon: Icons.block,
      fg: AppColors.danger,
      bg: AppColors.dangerSoft,
      allowed: false,
    ),
    ScanOutcome.expired => const OutcomeView(
      title: 'Pass expired',
      subtitle: 'This pass is no longer valid for entry.',
      icon: Icons.priority_high,
      fg: AppColors.danger,
      bg: AppColors.dangerSoft,
      allowed: false,
    ),
    ScanOutcome.notYetValid => const OutcomeView(
      title: 'Not valid yet',
      subtitle: 'This pass starts on a later day.',
      icon: Icons.event,
      fg: AppColors.warning,
      bg: AppColors.warningSoft,
      allowed: false,
    ),
    ScanOutcome.invalid => const OutcomeView(
      title: 'Unknown code',
      subtitle: 'This QR code is not an OMIS Entry pass.',
      icon: Icons.qr_code_2,
      fg: AppColors.danger,
      bg: AppColors.dangerSoft,
      allowed: false,
    ),
  };
}

/// G5 / G6: bottom sheet over the camera. Allowed results close themselves after
/// [autoDismiss]; blocked results stay until the guard taps "Scan again".
class ScanResultSheet extends StatefulWidget {
  const ScanResultSheet({
    super.key,
    required this.result,
    this.autoDismiss = const Duration(seconds: 3),
    this.onReview,
  });

  final ScanResult result;
  final Duration autoDismiss;

  /// Scan-and-approve: shown as "Review request" for a pending pass scanned by an approver.
  final VoidCallback? onReview;

  @override
  State<ScanResultSheet> createState() => _ScanResultSheetState();
}

class _ScanResultSheetState extends State<ScanResultSheet> {
  @override
  void initState() {
    super.initState();
    if (OutcomeView.of(widget.result).allowed) {
      Future<void>.delayed(widget.autoDismiss, () {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final view = OutcomeView.of(r);
    final t = Theme.of(context).textTheme;
    final blocked = !view.allowed;

    final rightDetail = switch (r.outcome) {
      ScanOutcome.entryRecorded when r.entryAt != null => (
        Icons.schedule,
        formatTime(r.entryAt!),
      ),
      ScanOutcome.exitRecorded when r.exitAt != null => (
        Icons.schedule,
        formatTime(r.exitAt!),
      ),
      ScanOutcome.expired when r.validUntil != null => (
        Icons.event,
        'Expired ${formatDate(r.validUntil!)}',
      ),
      _ => null,
    };

    return Container(
      color: view.bg,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.s1,
        AppSpacing.screen,
        AppSpacing.screen,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: view.fg.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: view.fg,
                  child: Icon(view.icon, size: 36, color: AppColors.surface),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              view.title,
              style: t.headlineMedium,
              textAlign: TextAlign.center,
            ),
            if (view.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                view.subtitle!,
                style: t.bodyLarge?.copyWith(color: AppColors.text),
                textAlign: TextAlign.center,
              ),
            ],
            if (r.fullName != null) ...[
              const SizedBox(height: AppSpacing.s2),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s2),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Avatar(
                            name: r.fullName!,
                            isStaff: r.passType == PassType.staff,
                            danger: blocked,
                          ),
                          const SizedBox(width: AppSpacing.s2),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.fullName!, style: t.titleLarge),
                                const SizedBox(height: 4),
                                PassTypeChip(type: r.passType, danger: blocked),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (r.plate != null || rightDetail != null) ...[
                        const Divider(
                          height: AppSpacing.s3,
                          color: AppColors.border,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: r.plate == null
                                  ? const SizedBox.shrink()
                                  : IconText(
                                      icon: Icons.directions_car_outlined,
                                      text: displayPlate(r.plate!),
                                    ),
                            ),
                            if (rightDetail != null)
                              Expanded(
                                child: IconText(
                                  icon: rightDetail.$1,
                                  text: rightDetail.$2,
                                  color: blocked
                                      ? AppColors.danger
                                      : AppColors.text,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s2),
            if (widget.onReview != null) ...[
              FilledButton.icon(
                key: const Key('review-request'),
                onPressed: widget.onReview,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Review request'),
              ),
              const SizedBox(height: AppSpacing.s1),
            ],
            FilledButton.icon(
              key: const Key('result-action'),
              onPressed: () => Navigator.of(context).maybePop(),
              icon: Icon(blocked ? Icons.refresh : Icons.check),
              label: Text(blocked ? 'Scan again' : 'Done'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet for a scan that never reached the server (no connection, gate closed…).
class ScanErrorSheet extends StatelessWidget {
  const ScanErrorSheet({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      color: AppColors.warningSoft,
      padding: const EdgeInsets.all(AppSpacing.screen),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.wifi_off, size: 48, color: AppColors.warning),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'Scan not recorded',
              style: t.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(message, style: t.bodyLarge, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.s3),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.refresh),
              label: const Text('Scan again'),
            ),
          ],
        ),
      ),
    );
  }
}
