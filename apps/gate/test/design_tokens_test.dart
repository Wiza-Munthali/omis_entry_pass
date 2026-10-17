import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omis_gate/core/theme/app_colors.dart';

/// Reads the Colors table in docs/SPEC.md → {token: 0xFFRRGGBB}.
Map<String, int> specColors() {
  final row = RegExp(
    r'^\|\s*`([a-z0-9-]+)`\s*\|\s*#([0-9A-Fa-f]{6})(?:\s+on\s+#([0-9A-Fa-f]{6}))?\s*\|',
  );
  final colors = <String, int>{};
  for (final line in File('../../docs/SPEC.md').readAsLinesSync()) {
    final m = row.firstMatch(line);
    if (m == null) continue;
    colors[m[1]!] = int.parse('FF${m[2]}', radix: 16);
    if (m[3] != null) {
      colors['${m[1]}-soft'] = int.parse('FF${m[3]}', radix: 16);
    }
  }
  return colors;
}

void main() {
  final spec = specColors();

  test('finds the colour table in the spec', () {
    expect(spec.keys, containsAll(['brand', 'ink', 'bg', 'danger-soft']));
  });

  test('AppColors matches the spec exactly', () {
    expect(AppColors.bySpecName.keys.toSet(), spec.keys.toSet());
    spec.forEach((name, argb) {
      expect(AppColors.bySpecName[name]!.toARGB32(), argb, reason: name);
    });
  });

  test('no colour literals outside app_colors.dart', () {
    final literal = RegExp(
      r'Color\(0x|Color\.fromARGB|Color\.fromRGBO|\bColors\.',
    );
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('app_colors.dart'))
        .where((f) => literal.hasMatch(f.readAsStringSync()))
        .map((f) => f.path)
        .toList();
    expect(offenders, isEmpty);
  });
}
