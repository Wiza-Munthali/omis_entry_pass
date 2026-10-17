import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omis_gate/data/local_db.dart';
import 'package:omis_gate/data/models.dart';
import 'package:omis_gate/data/settings_repository.dart';

void main() {
  test(
    'the chosen gate is stored on the device and can be changed or cleared',
    () async {
      final db = LocalDb(NativeDatabase.memory());
      addTearDown(db.close);
      final settings = LocalSettingsRepository(db);

      expect(await settings.selectedGate(), isNull);
      await settings.setSelectedGate(
        const Gate(id: 'g-main', name: 'Main gate'),
      );
      expect(
        await settings.selectedGate(),
        const Gate(id: 'g-main', name: 'Main gate'),
      );
      await settings.setSelectedGate(
        const Gate(id: 'g-back', name: 'Back gate'),
      );
      expect(
        await settings.selectedGate(),
        const Gate(id: 'g-back', name: 'Back gate'),
      );
      await settings.clearSelectedGate();
      expect(await settings.selectedGate(), isNull);
    },
  );
}
