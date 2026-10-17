import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time.dart';
import '../../core/widgets.dart';
import '../../data/gate_repository.dart';
import '../../data/request_models.dart';
import '../scan/scan_result_sheet.dart';

/// Live status for one of the guard's requests (Realtime broadcast on request:{token}).
final requestStatusChangesProvider =
    StreamProvider.family<RequestStatus, String>(
      (ref, statusToken) =>
          ref.watch(gateRequestsRepositoryProvider).statusChanges(statusToken),
    );

/// G9 Waiting for approval: updates the moment reception decides, then offers "Check in now".
class WaitingScreen extends ConsumerStatefulWidget {
  const WaitingScreen({super.key, required this.passId});

  final String passId;

  @override
  ConsumerState<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends ConsumerState<WaitingScreen> {
  Timer? _clock;
  bool _checkingIn = false;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(
      const Duration(seconds: 1),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _checkIn(GateRequest r) async {
    final gate = ref.read(selectedGateProvider).value;
    if (gate == null) return;
    setState(() => _checkingIn = true);
    try {
      final result = await ref
          .read(gateRequestsRepositoryProvider)
          .checkIn(r.passId, gate.id);
      ref.invalidate(myGateRequestsProvider);
      ref.invalidate(gateStatsProvider);
      ref.invalidate(onSiteProvider);
      if (!mounted) return;
      unawaited(HapticFeedback.mediumImpact());
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        builder: (_) => ScanResultSheet(result: result),
      );
      if (mounted) context.go('/home');
    } on GateFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(myGateRequestsProvider);
    final request = requests.value
        ?.where((r) => r.passId == widget.passId)
        .firstOrNull;
    final t = Theme.of(context).textTheme;

    if (request != null) {
      ref.listen(requestStatusChangesProvider(request.statusToken), (_, next) {
        if (next.hasValue) {
          HapticFeedback.heavyImpact();
          ref.invalidate(myGateRequestsProvider);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: CircleIconButton(
            icon: Icons.arrow_back,
            tooltip: 'Back',
            background: AppColors.surface,
            onPressed: () => context.go('/home'),
          ),
        ),
        leadingWidth: 64,
        centerTitle: true,
        title: Text(
          request?.status == RequestStatus.pending || request == null
              ? 'Waiting for approval'
              : 'Request',
          style: t.titleLarge,
        ),
      ),
      body: request == null
          ? Center(
              child: requests.hasError
                  ? Text(
                      '${requests.error}',
                      style: const TextStyle(color: AppColors.danger),
                    )
                  : const CircularProgressIndicator(
                      color: AppColors.brandStrong,
                    ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.s1,
                AppSpacing.screen,
                AppSpacing.s4,
              ),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.s3),
                    child: Column(
                      children: [
                        _StatusHero(request: request),
                        const SizedBox(height: AppSpacing.s3),
                        if (request.status == RequestStatus.pending)
                          _Timing(request: request),
                        if (request.status == RequestStatus.rejected &&
                            request.rejectReason != null)
                          _Note(
                            color: AppColors.danger,
                            bg: AppColors.dangerSoft,
                            text: 'Reason: ${request.rejectReason}',
                          ),
                        const Divider(
                          height: AppSpacing.s4,
                          color: AppColors.border,
                        ),
                        Row(
                          children: [
                            Avatar(
                              name: request.fullName,
                              isStaff: false,
                              size: 56,
                            ),
                            const SizedBox(width: AppSpacing.s2),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(request.fullName, style: t.titleLarge),
                                  const SizedBox(height: 4),
                                  PassTypeChip(type: request.passType),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            direction: Axis.vertical,
                            spacing: 8,
                            children: [
                              if (request.hostName != null)
                                IconText(
                                  icon: Icons.apartment_outlined,
                                  text: 'Visiting: ${request.hostName}',
                                ),
                              IconText(
                                icon: Icons.event_outlined,
                                text:
                                    'Pass: ${request.passType.name == 'week' ? 'One week' : 'One day'}',
                              ),
                              if (request.plate != null)
                                IconText(
                                  icon: Icons.directions_car_outlined,
                                  text:
                                      'Vehicle: ${displayPlate(request.plate!)}',
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s2),
                if (request.status == RequestStatus.approved && !request.onSite)
                  FilledButton.icon(
                    key: const Key('check-in-now'),
                    onPressed: _checkingIn ? null : () => _checkIn(request),
                    icon: const Icon(Icons.login),
                    label: const Text('Check in now'),
                  )
                else if (request.status != RequestStatus.pending)
                  FilledButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Done'),
                  ),
              ],
            ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.request});
  final GateRequest request;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final (icon, fg, title, text) = switch (request.status) {
      RequestStatus.pending => (
        Icons.schedule,
        AppColors.warning,
        'Request sent',
        'Waiting for reception to approve.',
      ),
      RequestStatus.approved when request.onSite => (
        Icons.check,
        AppColors.success,
        'Checked in',
        'They are on site now.',
      ),
      RequestStatus.approved => (
        Icons.check,
        AppColors.success,
        'Approved',
        'Check them in now, or scan later.',
      ),
      RequestStatus.rejected => (
        Icons.close,
        AppColors.danger,
        'Not approved',
        'Do not let them in.',
      ),
      _ => (
        Icons.event_busy,
        AppColors.info,
        'Expired',
        'This request is no longer valid.',
      ),
    };
    return Column(
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            color: fg.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: CircleAvatar(
            radius: 40,
            backgroundColor: fg,
            child: Icon(icon, size: 44, color: AppColors.surface),
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          title,
          key: const Key('waiting-title'),
          style: t.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: t.bodyLarge?.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _Timing extends StatelessWidget {
  const _Timing({required this.request});
  final GateRequest request;

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(request.requestedAt);
    final mm = elapsed.inMinutes;
    final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.s2),
          decoration: BoxDecoration(
            color: AppColors.warningSoft,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'Sent to reception at',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    Text(
                      formatTime(request.requestedAt),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 48, color: AppColors.border),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$mm:$ss',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Text(
                      'elapsed',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (request.escalatedAt != null) ...[
          const SizedBox(height: 12),
          const _Note(
            color: AppColors.danger,
            bg: AppColors.dangerSoft,
            text:
                'This is taking longer than usual. It has been sent to the admins. You can call reception.',
          ),
        ],
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.color, required this.bg, required this.text});
  final Color color;
  final Color bg;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}
