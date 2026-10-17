import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import 'gate_repository.dart';
import 'local_db.dart';

/// sha256 of a QR token, hex — matches passes.qr_token_hash on the server.
String tokenFingerprint(String qrToken) =>
    sha256.convert(utf8.encode(qrToken)).toString();

/// A queued scan's decision, kept so the local "who is inside" view stays right
/// until the scan syncs.
enum OfflineDecision { entry, exit }

/// The phone's offline data: pass cache, local open visits and the outbox.
class OfflineStore {
  OfflineStore(this._db);
  final LocalDb _db;

  static const _cacheTimeKey = 'cache_generated_at';

  // ---------------------------------------------------------------------------
  // Cache
  // ---------------------------------------------------------------------------

  /// Replaces the cache with the server's copy, then re-applies scans still in the
  /// outbox (the server has not seen them yet).
  Future<void> replaceCache(OfflineCacheData data) => _db.transaction(() async {
    await _db.delete(_db.cachedPasses).go();
    await _db.batch(
      (b) => b.insertAll(_db.cachedPasses, [
        for (final p in data.passes)
          CachedPassesCompanion.insert(
            tokenHash: p['token_hash'] as String,
            passId: p['pass_id'] as String,
            fullName: p['full_name'] as String,
            passType: p['pass_type'] as String,
            plate: Value(p['plate'] as String?),
            validFrom: DateTime.parse(p['valid_from'] as String),
            validUntil: DateTime.parse(p['valid_until'] as String),
          ),
      ]),
    );
    await _db.delete(_db.localOpenVisits).go();
    await _db.batch(
      (b) => b.insertAll(_db.localOpenVisits, [
        for (final v in data.openVisits)
          LocalOpenVisitsCompanion.insert(
            passId: v['pass_id'] as String,
            entryAt: DateTime.parse(v['entry_at'] as String),
          ),
      ], mode: InsertMode.insertOrReplace),
    );
    for (final item in await pending()) {
      if (item.kind != 'scan') continue;
      final p = jsonDecode(item.payload) as Map<String, dynamic>;
      await _apply(
        p['pass_id'] as String,
        OfflineDecision.values.byName(p['decision'] as String),
        DateTime.parse(p['scanned_at'] as String),
      );
    }
    await _db.write(_cacheTimeKey, data.generatedAt.toUtc().toIso8601String());
  });

  Future<DateTime?> cacheTime() async {
    final v = await _db.read(_cacheTimeKey);
    return v == null ? null : DateTime.parse(v);
  }

  Future<CachedPassesData?> findByHash(String hash) => (_db.select(
    _db.cachedPasses,
  )..where((p) => p.tokenHash.equals(hash))).getSingleOrNull();

  Future<bool> isOnSite(String passId) async =>
      await (_db.select(
        _db.localOpenVisits,
      )..where((v) => v.passId.equals(passId))).getSingleOrNull() !=
      null;

  Future<DateTime?> entryTime(String passId) async => (await (_db.select(
    _db.localOpenVisits,
  )..where((v) => v.passId.equals(passId))).getSingleOrNull())?.entryAt;

  /// Records an entry or exit in the local "who is inside" view.
  Future<void> apply(String passId, OfflineDecision d, DateTime at) =>
      _apply(passId, d, at);

  Future<void> _apply(String passId, OfflineDecision d, DateTime at) async {
    if (d == OfflineDecision.entry) {
      await _db
          .into(_db.localOpenVisits)
          .insertOnConflictUpdate(
            LocalOpenVisitsCompanion.insert(passId: passId, entryAt: at),
          );
    } else {
      await (_db.delete(
        _db.localOpenVisits,
      )..where((v) => v.passId.equals(passId))).go();
    }
  }

  // ---------------------------------------------------------------------------
  // Outbox
  // ---------------------------------------------------------------------------

  Future<void> enqueue({
    required String kind,
    required String eventId,
    required Map<String, dynamic> payload,
    Uint8List? photo,
  }) => _db
      .into(_db.outbox)
      .insert(
        OutboxCompanion.insert(
          kind: kind,
          eventId: eventId,
          payload: jsonEncode(payload),
          photo: Value(photo),
          createdAt: DateTime.now().toUtc(),
        ),
        mode: InsertMode.insertOrIgnore,
      );

  /// Items still to send, oldest first.
  Future<List<OutboxData>> pending() =>
      (_db.select(_db.outbox)
            ..where((o) => o.failed.equals(false))
            ..orderBy([(o) => OrderingTerm.asc(o.id)]))
          .get();

  Stream<int> watchPendingCount() =>
      (_db.selectOnly(_db.outbox)
            ..addColumns([_db.outbox.id.count()])
            ..where(_db.outbox.failed.equals(false)))
          .map((r) => r.read(_db.outbox.id.count()) ?? 0)
          .watchSingle();

  Stream<int> watchFailedCount() =>
      (_db.selectOnly(_db.outbox)
            ..addColumns([_db.outbox.id.count()])
            ..where(_db.outbox.failed.equals(true)))
          .map((r) => r.read(_db.outbox.id.count()) ?? 0)
          .watchSingle();

  Future<void> markSent(int id) =>
      (_db.delete(_db.outbox)..where((o) => o.id.equals(id))).go();

  Future<void> markAttempt(int id, String error) =>
      (_db.update(_db.outbox)..where((o) => o.id.equals(id))).write(
        OutboxCompanion.custom(
          attempts: _db.outbox.attempts + const Constant(1),
          lastError: Variable(error),
        ),
      );

  Future<void> markFailed(int id, String error) =>
      (_db.update(_db.outbox)..where((o) => o.id.equals(id))).write(
        OutboxCompanion(failed: const Value(true), lastError: Value(error)),
      );
}
