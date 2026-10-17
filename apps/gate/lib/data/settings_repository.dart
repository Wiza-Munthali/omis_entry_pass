import 'models.dart';
import 'local_db.dart';

/// Device settings: the gate this phone is posted at (kept across sign-ins and shifts).
abstract class SettingsRepository {
  Future<Gate?> selectedGate();
  Future<void> setSelectedGate(Gate gate);
  Future<void> clearSelectedGate();
}

class LocalSettingsRepository implements SettingsRepository {
  LocalSettingsRepository(this._db);
  final LocalDb _db;

  static const _gateId = 'gate_id';
  static const _gateName = 'gate_name';

  @override
  Future<Gate?> selectedGate() async {
    final id = await _db.read(_gateId);
    final name = await _db.read(_gateName);
    return id == null || name == null ? null : Gate(id: id, name: name);
  }

  @override
  Future<void> setSelectedGate(Gate gate) => _db.transaction(() async {
    await _db.write(_gateId, gate.id);
    await _db.write(_gateName, gate.name);
  });

  @override
  Future<void> clearSelectedGate() => _db.transaction(() async {
    await _db.remove(_gateId);
    await _db.remove(_gateName);
  });
}
