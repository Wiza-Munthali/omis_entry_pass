import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time.dart';
import '../../core/widgets.dart';
import '../../data/gate_repository.dart';
import '../../data/models.dart';

enum OnSiteFilter { all, staff, visitors }

/// Filters by tab and by a search on name or plate ("bt 45" finds BT4521).
List<OnSiteVisit> filterOnSite(
  List<OnSiteVisit> visits,
  OnSiteFilter filter,
  String query,
) {
  final q = query.trim().toLowerCase();
  final qPlate = q.replaceAll(RegExp(r'\s+'), '');
  return visits.where((v) {
    if (filter == OnSiteFilter.staff && !v.isStaff) return false;
    if (filter == OnSiteFilter.visitors && v.isStaff) return false;
    if (q.isEmpty) return true;
    return v.fullName.toLowerCase().contains(q) ||
        (v.plate?.toLowerCase().contains(qPlate) ?? false);
  }).toList();
}

/// G10 On site: everyone inside now, with manual check-out.
class OnSiteScreen extends ConsumerStatefulWidget {
  const OnSiteScreen({super.key});

  @override
  ConsumerState<OnSiteScreen> createState() => _OnSiteScreenState();
}

class _OnSiteScreenState extends ConsumerState<OnSiteScreen> {
  OnSiteFilter _filter = OnSiteFilter.all;
  String _query = '';
  final _checkingOut = <String>{};

  Future<void> _checkOut(OnSiteVisit visit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Check out ${visit.fullName}?'),
        content: Text(
          'Records that they left now${visit.plate == null ? '' : ' (${displayPlate(visit.plate!)})'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            key: const Key('confirm-check-out'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Check out',
              style: TextStyle(
                color: AppColors.brandStrong,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _checkingOut.add(visit.visitId));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(gateRepositoryProvider).checkOut(visit.visitId);
      messenger.showSnackBar(
        SnackBar(content: Text('${visit.fullName} checked out')),
      );
      ref.invalidate(onSiteProvider);
      ref.invalidate(gateStatsProvider);
    } on GateFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _checkingOut.remove(visit.visitId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visits = ref.watch(onSiteProvider);
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
              'On site',
              style: t.headlineMedium,
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.s1),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: Column(
                children: [
                  TextField(
                    key: const Key('search'),
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Search by name or plate',
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppColors.textMuted,
                      ),
                      fillColor: AppColors.surface2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s1),
                  _Segments(
                    value: _filter,
                    onChanged: (f) => setState(() => _filter = f),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.brandStrong,
              onRefresh: () => ref.refresh(onSiteProvider.future),
              child: visits.when(
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
                      onPressed: () => ref.invalidate(onSiteProvider),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
                data: (all) {
                  final shown = filterOnSite(all, _filter, _query);
                  if (shown.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(AppSpacing.s4),
                      children: [
                        const Icon(
                          Icons.groups_outlined,
                          size: 56,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: AppSpacing.s2),
                        Text(
                          all.isEmpty
                              ? 'No one is on site right now'
                              : 'No one matches your search',
                          style: t.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screen,
                      0,
                      AppSpacing.screen,
                      120,
                    ),
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _VisitCard(
                      visit: shown[i],
                      busy: _checkingOut.contains(shown[i].visitId),
                      onCheckOut: () => _checkOut(shown[i]),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments({required this.value, required this.onChanged});

  final OnSiteFilter value;
  final ValueChanged<OnSiteFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = {
      OnSiteFilter.all: 'All',
      OnSiteFilter.staff: 'Staff',
      OnSiteFilter.visitors: 'Visitors',
    };
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const ShapeDecoration(
        color: AppColors.surface2,
        shape: StadiumBorder(),
      ),
      child: Row(
        children: [
          for (final f in OnSiteFilter.values)
            Expanded(
              child: Semantics(
                selected: f == value,
                button: true,
                child: GestureDetector(
                  onTap: () => onChanged(f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 44,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: f == value ? AppColors.ink : AppColors.surface2,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      labels[f]!,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: f == value ? AppColors.brand : AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({
    required this.visit,
    required this.busy,
    required this.onCheckOut,
  });

  final OnSiteVisit visit;
  final bool busy;
  final VoidCallback onCheckOut;

  @override
  Widget build(BuildContext context) {
    // Two rows so it fits 320 dp phones: who (and the button), then plate · time · gate.
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Avatar(name: visit.fullName, isStaff: visit.isStaff, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visit.fullName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      PassTypeChip(type: visit.passType),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 48,
                  width: 108,
                  child: FilledButton(
                    key: Key('check-out-${visit.visitId}'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: busy ? null : onCheckOut,
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.brand,
                            ),
                          )
                        : const Text('Check out'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                if (visit.plate != null)
                  IconText(
                    icon: Icons.directions_car_outlined,
                    text: displayPlate(visit.plate!),
                  ),
                IconText(
                  icon: Icons.schedule,
                  text: 'In ${formatTime(visit.entryAt)}',
                ),
                IconText(
                  icon: Icons.door_sliding_outlined,
                  text: visit.gateName,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
