import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/gate_repository.dart';
import '../../data/models.dart';
import '../../data/request_models.dart';

/// Small pill: neutral tags ("One day"), source ("Gate" / "Web"), statuses.
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.icon,
    this.fg = AppColors.ink,
    this.bg = AppColors.surface2,
  });

  final String label;
  final IconData? icon;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String passLength(PassType t) => t == PassType.week ? 'One week' : 'One day';

TagChip sourceChip(bool fromGate) => fromGate
    ? const TagChip(
        label: 'Gate',
        icon: Icons.door_sliding_outlined,
        fg: AppColors.brandStrong,
        bg: AppColors.brandSoft,
      )
    : const TagChip(
        label: 'Web',
        icon: Icons.language,
        fg: AppColors.info,
        bg: AppColors.infoSoft,
      );

TagChip statusChip(RequestStatus s, {bool escalated = false}) => switch (s) {
  RequestStatus.pending when escalated => const TagChip(
    label: 'Waiting long',
    icon: Icons.priority_high,
    fg: AppColors.danger,
    bg: AppColors.dangerSoft,
  ),
  RequestStatus.pending => const TagChip(
    label: 'Pending',
    icon: Icons.schedule,
    fg: AppColors.warning,
    bg: AppColors.warningSoft,
  ),
  RequestStatus.approved => const TagChip(
    label: 'Approved',
    icon: Icons.check_circle_outline,
    fg: AppColors.success,
    bg: AppColors.successSoft,
  ),
  RequestStatus.rejected => const TagChip(
    label: 'Rejected',
    icon: Icons.block,
    fg: AppColors.danger,
    bg: AppColors.dangerSoft,
  ),
  RequestStatus.revoked => const TagChip(
    label: 'Revoked',
    icon: Icons.block,
    fg: AppColors.danger,
    bg: AppColors.dangerSoft,
  ),
  RequestStatus.expired => const TagChip(
    label: 'Expired',
    icon: Icons.event_busy,
    fg: AppColors.info,
    bg: AppColors.infoSoft,
  ),
};

const quickRejectReasons = [
  'Host is not available',
  'No appointment today',
  'ID does not match',
  'Please come back another day',
];

/// Asks for a rejection reason (quick picks or typed). Returns null if cancelled.
Future<String?> showRejectSheet(BuildContext context, String visitorName) {
  final controller = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screen,
        0,
        AppSpacing.screen,
        MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.screen,
      ),
      child: StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Reject $visitorName?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text(
              'The visitor sees this reason.',
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.s2),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in quickRejectReasons)
                  ChoiceChip(
                    label: Text(r),
                    selected: controller.text == r,
                    selectedColor: AppColors.brandSoft,
                    onSelected: (_) => setState(() => controller.text = r),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s2),
            TextField(
              key: const Key('reject-reason'),
              controller: controller,
              maxLines: 2,
              minLines: 1,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Or type a reason',
                fillColor: AppColors.surface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppRadii.card),
                  ),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            FilledButton(
              key: const Key('confirm-reject'),
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () =>
                        Navigator.of(sheetContext).pop(controller.text.trim()),
              child: const Text('Reject request'),
            ),
          ],
        ),
      ),
    ),
  ).whenComplete(controller.dispose);
}

/// Approves, or asks for a reason and rejects. Shows the outcome (including "already
/// decided by someone else") and returns true when this call made the decision.
Future<bool> decideWithFeedback(
  BuildContext context,
  WidgetRef ref, {
  required String passId,
  required String visitorName,
  required bool approve,
}) async {
  String? reason;
  if (!approve) {
    reason = await showRejectSheet(context, visitorName);
    if (reason == null) return false;
  }
  if (!context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final d = await ref
        .read(approvalsRepositoryProvider)
        .decide(passId, approve: approve, reason: reason);
    ref.invalidate(requestsProvider);
    ref.invalidate(pendingCountProvider);
    ref.invalidate(requestDetailProvider(passId));
    if (d.alreadyDecided) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Already ${d.status.name} by ${d.decidedByName ?? 'someone else'}. Your decision was not applied.',
          ),
        ),
      );
      return false;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text('$visitorName ${approve ? 'approved' : 'rejected'}'),
      ),
    );
    return true;
  } on GateFailure catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
}

/// Reject (white) and Approve (black) side by side.
class DecisionButtons extends StatelessWidget {
  const DecisionButtons({
    super.key,
    required this.onReject,
    required this.onApprove,
    this.busy = false,
  });

  final VoidCallback onReject;
  final VoidCallback onApprove;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('reject'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.border),
              minimumSize: const Size(0, 52),
            ),
            onPressed: busy ? null : onReject,
            icon: const Icon(Icons.close),
            label: const Text('Reject'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            key: const Key('approve'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
            onPressed: busy ? null : onApprove,
            icon: const Icon(Icons.check),
            label: const Text('Approve'),
          ),
        ),
      ],
    );
  }
}
