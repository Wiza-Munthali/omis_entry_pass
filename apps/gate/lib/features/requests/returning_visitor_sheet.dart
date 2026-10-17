import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time.dart';
import '../../core/widgets.dart';
import '../../data/gate_repository.dart';
import '../../data/request_models.dart';
import '../scan/scan_result_sheet.dart';

/// Returning visitor on a week pass without their QR: find by name or ID number,
/// compare the last 4 ID characters with their card, then check in (or out).
Future<void> showReturningVisitorSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ReturningVisitorSheet(),
    );

class _ReturningVisitorSheet extends ConsumerStatefulWidget {
  const _ReturningVisitorSheet();

  @override
  ConsumerState<_ReturningVisitorSheet> createState() =>
      _ReturningVisitorSheetState();
}

class _ReturningVisitorSheetState
    extends ConsumerState<_ReturningVisitorSheet> {
  final _query = TextEditingController();
  List<VisitorPassMatch>? _results;
  bool _searching = false;
  String? _error;
  String? _busyPass;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 3) {
      setState(
        () => _error =
            'Type at least 3 letters of the name, or the full ID number.',
      );
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final r = await ref.read(gateRequestsRepositoryProvider).findVisitors(q);
      if (mounted) setState(() => _results = r);
    } on GateFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _checkIn(VisitorPassMatch m) async {
    final gate = ref.read(selectedGateProvider).value;
    if (gate == null) return;
    setState(() => _busyPass = m.passId);
    try {
      final result = await ref
          .read(gateRequestsRepositoryProvider)
          .checkIn(m.passId, gate.id);
      ref.invalidate(gateStatsProvider);
      ref.invalidate(onSiteProvider);
      if (!mounted) return;
      unawaited(HapticFeedback.mediumImpact());
      if (!mounted) return;
      final navigator = Navigator.of(context);
      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        builder: (_) => ScanResultSheet(result: result),
      );
      navigator.maybePop();
    } on GateFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busyPass = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screen,
        0,
        AppSpacing.screen,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.screen,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Returning visitor', style: t.titleLarge),
          const Text(
            'Find a valid visitor pass by name or ID number.',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.s2),
          TextField(
            key: const Key('returning-search'),
            controller: _query,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Name or ID number',
              fillColor: AppColors.surface2,
              prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
              suffixIcon: IconButton(
                tooltip: 'Search',
                onPressed: _searching ? null : _search,
                icon: const Icon(
                  Icons.arrow_forward,
                  color: AppColors.brandStrong,
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: AppSpacing.s2),
          if (_searching)
            const Center(
              child: CircularProgressIndicator(color: AppColors.brandStrong),
            ),
          if (!_searching && _results != null && _results!.isEmpty)
            const Text(
              'No valid visitor pass found. Register them as a new visitor.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          if (!_searching && _results != null)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results!.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final m = _results![i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(AppRadii.card),
                    ),
                    child: Row(
                      children: [
                        Avatar(name: m.fullName, isStaff: false, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.fullName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                [
                                  if (m.idLast4 != null) 'ID …${m.idLast4}',
                                  'until ${formatDate(m.validUntil.subtract(const Duration(seconds: 1)))}',
                                  if (m.plate != null) displayPlate(m.plate!),
                                ].join(' · '),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          key: Key('check-in-${m.passId}'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(96, 44),
                          ),
                          onPressed: _busyPass != null
                              ? null
                              : () => _checkIn(m),
                          child: Text(m.onSite ? 'Check out' : 'Check in'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
