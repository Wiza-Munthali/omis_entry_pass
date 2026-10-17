import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/connectivity.dart';
import 'gate_repository.dart';
import 'gate_requests_repository.dart';
import 'models.dart';
import 'offline_store.dart';
import 'request_models.dart';

/// Sends the outbox in order when the network is back, and keeps the offline cache
/// fresh (on start, every 5 minutes, after each sync). Retries are safe: every item
/// carries its event id, which the server uses to ignore duplicates.
class SyncWorker {
  SyncWorker({
    required this.store,
    required this.remote,
    required this.requests,
    required this.connectivity,
    this.retryEvery = const Duration(seconds: 30),
    this.refreshEvery = const Duration(minutes: 5),
  });

  final OfflineStore store;
  final GateRepository remote;
  final GateRequestsRepository requests;
  final ConnectivityService connectivity;
  final Duration retryEvery;
  final Duration refreshEvery;

  /// Results of synced scans the server flagged (pass changed while offline).
  final conflicts = ValueNotifier<int>(0);

  StreamSubscription<bool>? _online;
  Timer? _retry;
  Timer? _refresh;
  Future<void>? _running;

  void start() {
    _online ??= connectivity.onlineChanges().listen((online) {
      if (online) unawaited(syncNow());
    });
    _retry ??= Timer.periodic(
      retryEvery,
      (_) => unawaited(syncNow(refresh: false)),
    );
    _refresh ??= Timer.periodic(refreshEvery, (_) => unawaited(refreshCache()));
    unawaited(syncNow());
  }

  Future<void> stop() async {
    // Timers first, synchronously: nothing may fire after the caller is gone.
    _retry?.cancel();
    _retry = null;
    _refresh?.cancel();
    _refresh = null;
    final online = _online;
    _online = null;
    await online?.cancel();
  }

  /// Sends everything queued, oldest first; stops at the first network failure.
  /// Concurrent calls share one run.
  Future<void> syncNow({bool refresh = true}) =>
      _running ??= _sync(refresh).whenComplete(() => _running = null);

  Future<void> _sync(bool refresh) async {
    if (!await connectivity.isOnline()) return;
    for (final item in await store.pending()) {
      try {
        await _send(
          item.kind,
          item.eventId,
          jsonDecode(item.payload) as Map<String, dynamic>,
          item.photo,
        );
        await store.markSent(item.id);
      } on GateFailure catch (e) {
        if (e.network) {
          await store.markAttempt(item.id, e.message);
          return; // still offline; keep order and try again later
        }
        await store.markFailed(item.id, e.message);
      }
    }
    if (refresh) await refreshCache();
  }

  Future<void> _send(
    String kind,
    String eventId,
    Map<String, dynamic> p,
    Uint8List? photo,
  ) async {
    switch (kind) {
      case 'scan':
        final r = await remote.recordOfflineScan(
          tokenHash: p['token_hash'] as String,
          gateId: p['gate_id'] as String,
          scannedAt: DateTime.parse(p['scanned_at'] as String),
          eventId: eventId,
        );
        if (r.conflict != null && !r.replayed) conflicts.value++;
      case 'request':
        final created = await requests.create(
          NewVisitor(
            fullName: p['full_name'] as String,
            idNumber: p['id_number'] as String,
            hostName: p['host_name'] as String,
            purpose: p['purpose'] as String,
            passType: PassType.values.byName(p['pass_type'] as String),
            phone: p['phone'] as String?,
            plate: p['plate'] as String?,
          ),
          clientRequestId: eventId,
        );
        if (photo != null) {
          try {
            await requests.uploadIdPhoto(created.passId, photo);
          } on GateFailure catch (e) {
            if (e.network) {
              rethrow; // retry the whole item; create is idempotent
            }
            // A refused photo does not block the request itself.
          }
        }
      default:
        throw GateFailure('Unknown outbox item: $kind');
    }
  }

  /// Downloads the latest pass fingerprints and open visits. Failures keep the old cache.
  Future<void> refreshCache() async {
    if (!await connectivity.isOnline()) return;
    try {
      await store.replaceCache(await remote.offlineCache());
    } on GateFailure catch (e) {
      debugPrint('Offline cache not refreshed: ${e.message}');
    }
  }
}
