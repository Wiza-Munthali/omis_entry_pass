import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ago.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/request_models.dart';
import 'request_widgets.dart';

const _purposeLabel = {
  'meeting': 'Meeting',
  'delivery': 'Delivery',
  'contractor': 'Contractor work',
  'interview': 'Interview',
  'other': 'Other',
};

/// R3 Request detail: visitor, visit, ID photo, timeline; sticky Reject / Approve.
class RequestDetailScreen extends ConsumerStatefulWidget {
  const RequestDetailScreen({super.key, required this.passId});

  final String passId;

  @override
  ConsumerState<RequestDetailScreen> createState() =>
      _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  bool _busy = false;

  Future<void> _decide(RequestDetail d, bool approve) async {
    setState(() => _busy = true);
    final done = await decideWithFeedback(
      context,
      ref,
      passId: d.passId,
      visitorName: d.fullName,
      approve: approve,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(requestDetailProvider(widget.passId));
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: CircleIconButton(
            icon: Icons.arrow_back,
            tooltip: 'Back',
            background: AppColors.surface,
            onPressed: () => context.pop(),
          ),
        ),
        leadingWidth: 64,
        centerTitle: true,
        title: Text('Request details', style: t.titleLarge),
        actions: [
          if (detail.hasValue)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.screen),
              child: statusChip(
                detail.value!.status,
                escalated: detail.value!.escalatedAt != null,
              ),
            ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.brandStrong),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Text(
              '$e',
              style: t.bodyLarge?.copyWith(color: AppColors.danger),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (d) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.s1,
            AppSpacing.screen,
            AppSpacing.s4,
          ),
          children: [
            if (d.status != RequestStatus.pending)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _Banner(
                  text: d.status == RequestStatus.approved
                      ? 'Approved by ${d.decidedByName ?? 'reception'}${d.decidedAt == null ? '' : ' at ${formatTime(d.decidedAt!)}'}.'
                      : d.status == RequestStatus.rejected
                      ? 'Rejected by ${d.decidedByName ?? 'reception'}: ${d.rejectReason ?? ''}'
                      : 'This request is ${d.status.name}.',
                ),
              ),
            _Section(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Avatar(name: d.fullName, isStaff: d.fromGate, size: 64),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.fullName, style: t.titleLarge),
                        const SizedBox(height: 4),
                        if (d.phone != null)
                          IconText(icon: Icons.phone_outlined, text: d.phone!),
                        if (d.idNumber != null)
                          IconText(
                            icon: Icons.badge_outlined,
                            text: 'ID: ${d.idNumber}',
                          ),
                        if (d.email != null)
                          IconText(icon: Icons.mail_outline, text: d.email!),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            PassTypeChip(type: d.passType),
                            TagChip(label: passLength(d.passType)),
                            sourceChip(d.fromGate),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _Section(
              title: 'Visit information',
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.apartment_outlined,
                    label: 'Visiting',
                    value: d.hostName ?? '—',
                  ),
                  _InfoRow(
                    icon: Icons.list_alt,
                    label: 'Purpose',
                    value: _purposeLabel[d.purpose] ?? d.purpose ?? '—',
                  ),
                  _InfoRow(
                    icon: Icons.event_outlined,
                    label: d.passType == PassType.week ? 'Dates' : 'Date',
                    value: d.passType == PassType.week
                        ? '${formatDate(d.validFrom)} – ${formatDate(d.validUntil.subtract(const Duration(seconds: 1)))}'
                        : formatDate(d.validFrom),
                  ),
                  if (d.plate != null)
                    _InfoRow(
                      icon: Icons.directions_car_outlined,
                      label: 'Vehicle',
                      value: displayPlate(d.plate!),
                    ),
                ],
              ),
            ),
            if (d.photoPaths.isNotEmpty)
              _Section(
                title: 'ID photo',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [for (final p in d.photoPaths) _IdPhoto(path: p)],
                ),
              ),
            _Section(
              title: 'Timeline',
              child: Column(
                children: [
                  _Step(
                    done: true,
                    title: d.fromGate
                        ? 'Registered at the gate'
                        : 'Requested online',
                    detail:
                        '${d.requestedByName != null ? 'By ${d.requestedByName} · ' : ''}${formatTime(d.requestedAt)} (${timeAgo(d.requestedAt)})',
                  ),
                  _Step(
                    done: true,
                    title: 'Sent to reception',
                    detail: formatTime(d.requestedAt),
                  ),
                  if (d.escalatedAt != null)
                    _Step(
                      done: true,
                      warn: true,
                      title: 'Escalated to admins',
                      detail: formatTime(d.escalatedAt!),
                    ),
                  _Step(
                    done: d.status != RequestStatus.pending,
                    title: switch (d.status) {
                      RequestStatus.pending => 'Waiting for approval',
                      RequestStatus.rejected => 'Rejected',
                      _ => 'Approved',
                    },
                    detail: d.decidedAt == null
                        ? 'Reception will review this request.'
                        : '${d.decidedByName ?? ''} · ${formatTime(d.decidedAt!)}',
                    last: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: detail.value?.status == RequestStatus.pending
          ? SafeArea(
              child: Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  12,
                  AppSpacing.screen,
                  12,
                ),
                child: DecisionButtons(
                  busy: _busy,
                  onReject: () => _decide(detail.value!, false),
                  onApprove: () => _decide(detail.value!, true),
                ),
              ),
            )
          : null,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null) ...[
                Text(title!, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s2),
      decoration: BoxDecoration(
        color: AppColors.infoSoft,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.info),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.info,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.done,
    required this.title,
    required this.detail,
    this.warn = false,
    this.last = false,
  });

  final bool done;
  final bool warn;
  final bool last;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final color = warn
        ? AppColors.danger
        : (done ? AppColors.brandStrong : AppColors.border);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Icon(
                done
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: color,
                size: 20,
              ),
              if (!last)
                Expanded(child: Container(width: 2, color: AppColors.border)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: done ? AppColors.text : AppColors.textMuted,
                    ),
                  ),
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ID photo thumbnail from a short-lived signed link; tap to enlarge and zoom.
class _IdPhoto extends ConsumerWidget {
  const _IdPhoto({required this.path});
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String?>(
      future: ref.read(approvalsRepositoryProvider).photoUrl(path),
      builder: (context, snap) {
        final url = snap.data;
        return GestureDetector(
          onTap: url == null
              ? null
              : () => showDialog<void>(
                  context: context,
                  builder: (_) => Dialog(
                    backgroundColor: AppColors.ink,
                    insetPadding: const EdgeInsets.all(AppSpacing.s2),
                    child: InteractiveViewer(
                      child: Image.network(url, fit: BoxFit.contain),
                    ),
                  ),
                ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 140,
              height: 100,
              color: AppColors.surface2,
              alignment: Alignment.center,
              child: url == null
                  ? (snap.connectionState == ConnectionState.done
                        ? const Icon(
                            Icons.hide_image_outlined,
                            color: AppColors.textMuted,
                          )
                        : const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.brandStrong,
                          ))
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      width: 140,
                      height: 100,
                    ),
            ),
          ),
        );
      },
    );
  }
}
