import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'local_db.g.dart';

/// Small key/value settings kept on this device, e.g. the chosen gate.
/// (Phase 7 adds the offline pass cache and scan outbox to this database.)
class DeviceSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [DeviceSettings])
class LocalDb extends _$LocalDb {
  LocalDb([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'omis_gate'));

  @override
  int get schemaVersion => 1;

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
