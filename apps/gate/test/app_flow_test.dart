import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omis_gate/data/models.dart';
import 'package:omis_gate/main.dart';

import 'support/fakes.dart';

Future<void> startApp(
  WidgetTester tester,
  FakeAuthRepository auth,
  FakeGateRepository gates,
  InMemorySettings settings,
) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: fakeOverrides(auth: auth, gates: gates, settings: settings),
      child: const OmisGateApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(disableFontFetching);

  testWidgets('guard signs in, chooses a gate once, and lands on home', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    final gates = FakeGateRepository(role: OperatorRole.guard);
    final settings = InMemorySettings();
    await startApp(tester, auth, gates, settings);

    expect(find.text('Sign in with your work email'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('email')), 'Guard@GHII.test ');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(auth.sentTo, ['guard@ghii.test']);
    expect(find.text('Enter the 6-digit code'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('code')), '000000');
    await tester.pumpAndSettle();
    expect(find.textContaining('wrong or has expired'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('code')), '123456');
    await tester.pumpAndSettle();
    expect(find.text('Choose your gate'), findsOneWidget);

    await tester.tap(find.text('Main gate'));
    await tester.pumpAndSettle();
    expect(settings.gate, const Gate(id: 'g-main', name: 'Main gate'));
    expect(find.text('Hello, Yamikani'), findsOneWidget);
    expect(find.text('Main gate'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('118'), findsOneWidget);
    expect(find.text('Scan pass'), findsOneWidget);

    // Guard tabs: Home · Scan · On site · New visitor.
    for (final label in ['Home', 'Scan', 'On site', 'New visitor']) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
    }
    expect(find.bySemanticsLabel('Approvals'), findsNothing);
  });

  testWidgets('the gate is remembered: next sign-in goes straight home', (
    tester,
  ) async {
    await startApp(
      tester,
      FakeAuthRepository(userId: 'u'),
      FakeGateRepository(),
      InMemorySettings(const Gate(id: 'g-back', name: 'Back gate')),
    );
    expect(find.text('Hello, Yamikani'), findsOneWidget);
    expect(find.text('Back gate'), findsOneWidget);
  });

  testWidgets('receptionists get five tabs including Approvals', (
    tester,
  ) async {
    await startApp(
      tester,
      FakeAuthRepository(userId: 'u'),
      FakeGateRepository(role: OperatorRole.receptionist),
      InMemorySettings(const Gate(id: 'g-main', name: 'Main gate')),
    );
    for (final label in ['Home', 'Scan', 'Approvals', 'On site', 'More']) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('staff accounts are stopped and can sign out', (tester) async {
    final auth = FakeAuthRepository(userId: 'u');
    await startApp(
      tester,
      auth,
      FakeGateRepository(role: null),
      InMemorySettings(),
    );
    expect(find.text('This app is for gate staff'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in with your work email'), findsOneWidget);
  });

  testWidgets('on-site tab and sign-out from the account sheet', (
    tester,
  ) async {
    final auth = FakeAuthRepository(userId: 'u');
    final gates = FakeGateRepository(
      visits: [
        OnSiteVisit(
          visitId: 'v1',
          fullName: 'Kondwani Mwale',
          passType: PassType.week,
          gateName: 'Main gate',
          entryAt: DateTime.utc(2026, 10, 17, 6, 14),
          plate: 'MZ2210',
        ),
      ],
    );
    await startApp(
      tester,
      auth,
      gates,
      InMemorySettings(const Gate(id: 'g-main', name: 'Main gate')),
    );

    await tester.tap(find.bySemanticsLabel('On site'));
    await tester.pumpAndSettle();
    expect(find.text('Kondwani Mwale'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in with your work email'), findsOneWidget);
  });
}
