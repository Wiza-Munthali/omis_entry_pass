import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omis_gate/data/models.dart';
import 'package:omis_gate/main.dart';

import 'support/fakes.dart';

/// Cheap Android phones can be 320–360 dp wide. Any overflow fails the test.
void main() {
  setUpAll(disableFontFetching);

  for (final width in [320.0, 360.0]) {
    for (final role in [OperatorRole.guard, OperatorRole.receptionist]) {
      testWidgets('no overflow at ${width.toInt()} dp for a ${role.name}', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width * 2, 640 * 2);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: fakeOverrides(
              auth: FakeAuthRepository(userId: 'u'),
              gates:
                  FakeGateRepository(
                      role: role,
                      visits: [
                        OnSiteVisit(
                          visitId: 'v1',
                          fullName: 'Jane Mpinganjira-Chirwa',
                          passType: PassType.week,
                          gateName: 'Main gate (north)',
                          entryAt: DateTime.utc(2026, 10, 17, 6, 14),
                          plate: 'MZ22100',
                        ),
                      ],
                    )
                    ..statsValue = const GateStats(
                      onSite: 1234,
                      entriesToday: 56789,
                    ),
              settings: InMemorySettings(
                const Gate(id: 'g-main', name: 'Main gate (north entrance)'),
              ),
            ),
            child: const OmisGateApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Scan pass'), findsOneWidget);

        await tester.tap(find.byKey(const Key('nav-On site')));
        await tester.pumpAndSettle();
        expect(find.text('Jane Mpinganjira-Chirwa'), findsOneWidget);
        // Any RenderFlex overflow is reported as a test exception.
      });
    }
  }
}
