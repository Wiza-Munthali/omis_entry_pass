import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ago.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets.dart';
import '../../data/approvals_repository.dart';
import '../../data/models.dart';
import '../../data/request_models.dart';
import 'request_widgets.dart';

/// R2 Approvals: Pending · Approved · Rejected, plus Escalated for admins. Updates live.
class ApprovalsScreen extends ConsumerStatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  ConsumerState<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends ConsumerState<ApprovalsScreen> {
  RequestTab _tab = RequestTab.pending;

  @override
  Widget build(BuildContext context) {
    final isAdmin =
        ref.watch(profileProvider).value?.role == OperatorRole.admin;
    final tabs = [
      RequestTab.pending,
      if (isAdmin) RequestTab.escalated,
      RequestTab.approved,
      RequestTab.rejected,
    ];
    const labels = {
      RequestTab.pending: 'Pending',
      RequestTab.escalated: 'Escalated',
      RequestTab.approved: 'Approved',
      RequestTab.rejected: 'Rejected',
    };
    final requests = ref.watch(requestsProvider(_tab));
    final t = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.s2,
              AppSpacing.screen,
              0,
            ),
            child: Text(
              'Approvals',
              style: t.headlineMedium,
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const ShapeDecoration(
                color: AppColors.surface,
                shape: StadiumBorder(),
              ),
              child: Row(
                children: [
                  for (final tab in tabs)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: tab == _tab,
                        child: GestureDetector(
                          onTap: () => setState(() => _tab = tab),
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: ShapeDecoration(
                              color: tab == _tab
                                  ? AppColors.ink
                                  : AppColors.surface,
                              shape: const StadiumBorder(),
                            ),
                            child: Text(
                              labels[tab]!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: tab == _tab
                                    ? AppColors.brand
                                    : AppColors.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.brandStrong,
              onRefresh: () => ref.refresh(requestsProvider(_tab).future),
              child: requests.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.brandStrong,
                  ),
                ),
                error: (e, _) => ListView(
                  padding: const EdgeInsets.all(AppSpacing.screen),
                  children: [
                    Text(
                      '$e',
                      style: t.bodyLarge?.copyWith(color: AppColors.danger),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    FilledButton(
                      onPressed: () => ref.invalidate(requestsProvider(_tab)),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
                data: (list) => list.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(AppSpacing.s4),
                        children: [
                          const Icon(
                            Icons.inbox_outlined,
                            size: 56,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: AppSpacing.s2),
                          Text(
                            _tab == RequestTab.pending
                                ? 'Nothing waiting for approval'
                                : 'No ${labels[_tab]!.toLowerCase()} requests this week',
                            style: t.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screen,
                          0,
                          AppSpacing.screen,
                          120,
                        ),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => RequestCard(request: list[i]),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One request: who, contact, visiting, chips, age; Reject/Approve while pending.
class RequestCard extends ConsumerStatefulWidget {
  const RequestCard({super.key, required this.request, this.compact = false});

  final RequestSummary request;

  /// Home screen variant: no phone line.
  final bool compact;

  @override
  ConsumerState<RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<RequestCard> {
  bool _busy = false;

  Future<void> _decide(bool approve) async {
    setState(() => _busy = true);
    await decideWithFeedback(
      context,
      ref,
      passId: widget.request.passId,
      visitorName: widget.request.fullName,
      approve: approve,
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final t = Theme.of(context).textTheme;
    return Card(
      key: Key('request-${r.passId}'),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: () => context.push('/approvals/${r.passId}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Avatar(name: r.fullName, isStaff: r.fromGate, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.fullName,
                          style: t.titleLarge?.copyWith(fontSize: 18),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!widget.compact && r.phone != null)
                          IconText(icon: Icons.phone_outlined, text: r.phone!),
                        if (r.hostName != null)
                          IconText(
                            icon: Icons.apartment_outlined,
                            text: 'Visiting: ${r.hostName}',
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeAgo(
                      r.status == RequestStatus.pending
                          ? r.requestedAt
                          : (r.decidedAt ?? r.requestedAt),
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      color: r.escalated && r.status == RequestStatus.pending
                          ? AppColors.danger
                          : AppColors.textMuted,
                      fontWeight: r.escalated
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PassTypeChip(type: r.passType),
                  TagChip(label: passLength(r.passType)),
                  sourceChip(r.fromGate),
                  if (r.status != RequestStatus.pending || r.escalated)
                    statusChip(r.status, escalated: r.escalated),
                ],
              ),
              if (r.status == RequestStatus.rejected &&
                  r.rejectReason != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Reason: ${r.rejectReason}',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
              if (r.status == RequestStatus.pending) ...[
                const SizedBox(height: 12),
                DecisionButtons(
                  busy: _busy,
                  onReject: () => _decide(false),
                  onApprove: () => _decide(true),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
