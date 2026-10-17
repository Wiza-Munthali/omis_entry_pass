import 'dart:async';

import '../core/connectivity.dart';
import '../core/event_id.dart';
import 'gate_repository.dart';
import 'models.dart';
import 'offline_store.dart';

/// Records a scanned code: online through record_scan, or — when the network is down
/// or the call fails to reach the server — on this phone from the offline cache,
/// queued in the outbox with the same event id (docs/SPEC.md → Offline scanning).
class ScanService {
  ScanService({
    required this.remote,
    required this.store,
    required this.connectivity,
    this.timeout = const Duration(seconds: 6),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final GateRepository remote;
  final OfflineStore store;
  final ConnectivityService connectivity;
  final Duration timeout;
  final DateTime Function() _now;

  Future<ScanResult> scan(String qrToken, String gateId) async {
    final eventId = newEventId();
    final scannedAt = _now().toUtc();

    if (await connectivity.isOnline()) {
      try {
        final result = await remote
            .recordScan(qrToken: qrToken, gateId: gateId, eventId: eventId)
            .timeout(timeout);
        await _mirror(result, scannedAt);
        return result;
      } on GateFailure catch (e) {
        if (!e.network) rethrow;
      } on TimeoutException {
        // The server may or may not have recorded it; the queued copy carries the
        // same event id, so syncing it later is a harmless replay if it did.
      }
    }
    return _offline(qrToken, gateId, eventId, scannedAt);
  }

  /// Keeps the local "who is inside" view in step with online scans.
  Future<void> _mirror(ScanResult r, DateTime at) async {
    final passId = r.passId;
    if (passId == null) return;
    if (r.outcome == ScanOutcome.entryRecorded) {
      await store.apply(passId, OfflineDecision.entry, r.entryAt ?? at);
    }
    if (r.outcome == ScanOutcome.exitRecorded) {
      await store.apply(passId, OfflineDecision.exit, at);
    }
  }

  Future<ScanResult> _offline(
    String qrToken,
    String gateId,
    String eventId,
    DateTime scannedAt,
  ) async {
    final hash = tokenFingerprint(qrToken.trim());
    final pass = await store.findByHash(hash);
    if (pass == null) {
      return const ScanResult(
        outcome: ScanOutcome.unknownOffline,
        offline: true,
      );
    }

    final type = PassType.values.byName(pass.passType);
    final base = (
      fullName: pass.fullName,
      passType: type,
      plate: pass.plate,
      validUntil: pass.validUntil,
    );
    if (!scannedAt.isBefore(pass.validUntil)) {
      return ScanResult(
        outcome: ScanOutcome.expired,
        offline: true,
        passId: pass.passId,
        fullName: base.fullName,
        passType: base.passType,
        plate: base.plate,
        validUntil: base.validUntil,
      );
    }
    if (scannedAt.isBefore(pass.validFrom)) {
      return ScanResult(
        outcome: ScanOutcome.notYetValid,
        offline: true,
        passId: pass.passId,
        fullName: base.fullName,
        passType: base.passType,
        plate: base.plate,
        validUntil: base.validUntil,
      );
    }

    final entryAt = await store.entryTime(pass.passId);
    final decision = entryAt == null
        ? OfflineDecision.entry
        : OfflineDecision.exit;
    await store.enqueue(
      kind: 'scan',
      eventId: eventId,
      payload: {
        'token_hash': hash,
        'pass_id': pass.passId,
        'gate_id': gateId,
        'scanned_at': scannedAt.toIso8601String(),
        'decision': decision.name,
      },
    );
    await store.apply(pass.passId, decision, scannedAt);

    return ScanResult(
      outcome: decision == OfflineDecision.entry
          ? ScanOutcome.entryRecorded
          : ScanOutcome.exitRecorded,
      offline: true,
      passId: pass.passId,
      fullName: base.fullName,
      passType: base.passType,
      plate: base.plate,
      validUntil: base.validUntil,
      entryAt: decision == OfflineDecision.entry ? scannedAt : entryAt,
      exitAt: decision == OfflineDecision.exit ? scannedAt : null,
      duration: decision == OfflineDecision.exit
          ? scannedAt.difference(entryAt!)
          : null,
    );
  }
}
