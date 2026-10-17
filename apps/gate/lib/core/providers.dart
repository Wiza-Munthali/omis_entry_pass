import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/approvals_repository.dart';
import '../data/auth_repository.dart';
import '../data/gate_repository.dart';
import '../data/gate_requests_repository.dart';
import '../data/local_db.dart';
import '../data/models.dart';
import '../data/request_models.dart';
import '../data/settings_repository.dart';
import 'env.dart';
import 'push.dart';

// Repositories: real implementations by default, replaced with fakes in widget tests.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(Supabase.instance.client),
);

final gateRepositoryProvider = Provider<GateRepository>(
  (ref) => SupabaseGateRepository(Supabase.instance.client),
);

final localDbProvider = Provider<LocalDb>((ref) {
  final db = LocalDb();
  ref.onDispose(db.close);
  return db;
});

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => LocalSettingsRepository(ref.watch(localDbProvider)),
);

/// The signed-in user's id, or null.
final userIdProvider = StreamProvider<String?>((ref) async* {
  final auth = ref.watch(authRepositoryProvider);
  yield auth.currentUserId;
  yield* auth.userIdChanges();
});

/// The signed-in operator's profile (null when signed out).
final profileProvider = FutureProvider<Profile?>((ref) async {
  final userId = ref.watch(userIdProvider).value;
  if (userId == null) return null;
  return ref.watch(gateRepositoryProvider).profile(userId);
});

/// The gate this phone is posted at.
final selectedGateProvider = AsyncNotifierProvider<SelectedGateNotifier, Gate?>(
  SelectedGateNotifier.new,
);

class SelectedGateNotifier extends AsyncNotifier<Gate?> {
  @override
  Future<Gate?> build() => ref.watch(settingsRepositoryProvider).selectedGate();

  Future<void> select(Gate gate) async {
    await ref.read(settingsRepositoryProvider).setSelectedGate(gate);
    state = AsyncData(gate);
  }

  Future<void> clear() async {
    await ref.read(settingsRepositoryProvider).clearSelectedGate();
    state = const AsyncData(null);
  }
}

/// Home screen counts for the selected gate.
final gateStatsProvider = FutureProvider<GateStats>((ref) async {
  final gate = await ref.watch(selectedGateProvider.future);
  return ref.watch(gateRepositoryProvider).stats(gate?.id);
});

/// Who is on site now.
final onSiteProvider = FutureProvider<List<OnSiteVisit>>(
  (ref) => ref.watch(gateRepositoryProvider).onSite(),
);

// ---------------------------------------------------------------------------
// Phase 6: approvals (receptionists, admins) and gate requests (guards)
// ---------------------------------------------------------------------------

final approvalsRepositoryProvider = Provider<ApprovalsRepository>(
  (ref) => SupabaseApprovalsRepository(Supabase.instance.client),
);

final gateRequestsRepositoryProvider = Provider<GateRequestsRepository>(
  (ref) => SupabaseGateRequestsRepository(Supabase.instance.client),
);

final pushServiceProvider = Provider<PushService>(
  (ref) => Env.hasFirebase ? FirebasePushService() : NoPushService(),
);

/// Ticks whenever a pass changes (Realtime), for approvers only; lists watch it to refresh.
final approvalsTickProvider = StreamProvider<int>((ref) {
  final canApprove = ref.watch(profileProvider).value?.canApprove ?? false;
  if (!canApprove) return Stream.value(0);
  var n = 0;
  return ref.watch(approvalsRepositoryProvider).changes().map((_) => ++n);
});

final requestsProvider =
    FutureProvider.family<List<RequestSummary>, RequestTab>((ref, tab) {
      ref.watch(approvalsTickProvider);
      return ref.watch(approvalsRepositoryProvider).requests(tab);
    });

final pendingCountProvider = FutureProvider<int>((ref) {
  ref.watch(approvalsTickProvider);
  return ref.watch(approvalsRepositoryProvider).pendingCount();
});

final recentActivityProvider = FutureProvider<List<ActivityItem>>((ref) {
  ref.watch(approvalsTickProvider);
  return ref.watch(approvalsRepositoryProvider).recentActivity();
});

final requestDetailProvider = FutureProvider.family<RequestDetail, String>((
  ref,
  passId,
) {
  ref.watch(approvalsTickProvider);
  return ref.watch(approvalsRepositoryProvider).detail(passId);
});

/// Guards cannot receive database changes on passes, so their list re-checks every 15 s.
final guardTickProvider = StreamProvider<int>(
  (ref) => Stream.periodic(const Duration(seconds: 15), (i) => i),
);

final myGateRequestsProvider = FutureProvider<List<GateRequest>>((ref) {
  ref.watch(guardTickProvider);
  return ref.watch(gateRequestsRepositoryProvider).mine();
});

/// Signs out after clearing this phone's push token, so a shared gate phone stops
/// receiving the previous operator's notifications.
Future<void> signOut(WidgetRef ref) async {
  final userId = ref.read(userIdProvider).value;
  try {
    await ref.read(pushServiceProvider).stop();
    if (userId != null) {
      await ref.read(gateRepositoryProvider).setPushToken(userId, null);
    }
  } catch (_) {
    // Offline: sign out anyway; the server drops dead tokens on the next send.
  }
  await ref.read(authRepositoryProvider).signOut();
}
