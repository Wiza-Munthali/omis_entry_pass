import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';
import '../data/gate_repository.dart';
import '../data/local_db.dart';
import '../data/models.dart';
import '../data/settings_repository.dart';

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
