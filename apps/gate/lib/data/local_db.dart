import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'local_db.g.dart';

/// Small key/value settings kept on this device, e.g. the chosen gate.
class DeviceSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Approved passes this phone can check without a network (docs/SPEC.md → Offline
/// scanning). Only sha256(qr_token) is stored, never the token itself.
class CachedPasses extends Table {
  TextColumn get tokenHash => text()();
  TextColumn get passId => text()();
  TextColumn get fullName => text()();
  TextColumn get passType => text()();
  TextColumn get plate => text().nullable()();
  DateTimeColumn get validFrom => dateTime()();
  DateTimeColumn get validUntil => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {tokenHash};
}

/// Who this phone believes is inside: the server's open visits at the last refresh,
/// plus the effect of scans still waiting in the outbox. Decides entry vs exit offline.
class LocalOpenVisits extends Table {
  TextColumn get passId => text()();
  DateTimeColumn get entryAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {passId};
}

/// Work done offline, sent in order when the network returns. [eventId] is the
/// client_event_id (scans) or client_request_id (gate requests): retries never duplicate.
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => text()(); // 'scan' | 'request'
  TextColumn get eventId => text().unique()();
  TextColumn get payload => text()(); // JSON
  BlobColumn get photo => blob().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  /// Refused by the server for a reason a retry will not fix; kept for review.
  BoolColumn get failed => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [DeviceSettings, CachedPasses, LocalOpenVisits, Outbox])
class LocalDb extends _$LocalDb {
  LocalDb([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'omis_gate'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(cachedPasses);
        await m.createTable(localOpenVisits);
        await m.createTable(outbox);
      }
    },
  );

  Future<String?> read(String key) async => (await (select(
    deviceSettings,
  )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> write(String key, String value) =>
      into(deviceSettings).insertOnConflictUpdate(
        DeviceSettingsCompanion.insert(key: key, value: value),
      );

  Future<void> remove(String key) =>
      (delete(deviceSettings)..where((s) => s.key.equals(key))).go();
}
