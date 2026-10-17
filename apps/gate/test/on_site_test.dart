import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omis_gate/data/models.dart';
import 'package:omis_gate/features/onsite/on_site_screen.dart';

import 'support/fakes.dart';

final visits = [
  OnSiteVisit(
    visitId: 'v1',
    fullName: 'Chikondi Banda',
    passType: PassType.staff,
    gateName: 'Main gate',
    entryAt: DateTime.utc(2026, 10, 17, 6, 42),
    plate: 'BT4521',
  ),
  OnSiteVisit(
    visitId: 'v2',
    fullName: 'Thoko Phiri',
    passType: PassType.day,
    gateName: 'Back gate',
    entryAt: DateTime.utc(2026, 10, 17, 7, 15),
    plate: 'LL2087',
  ),
  OnSiteVisit(
    visitId: 'v3',
    fullName: 'Kondwani Mwale',
    passType: PassType.week,
    gateName: 'Main gate',
    entryAt: DateTime.utc(2026, 10, 17, 5, 58),
  ),
];

void main() {
  setUpAll(disableFontFetching);

  group('filterOnSite', () {
    test('tabs', () {
      expect(filterOnSite(visits, OnSiteFilter.all, '').length, 3);
      expect(
        filterOnSite(visits, OnSiteFilter.staff, '').map((v) => v.visitId),
        ['v1'],
      );
      expect(
        filterOnSite(visits, OnSiteFilter.visitors, '').map((v) => v.visitId),
        ['v2', 'v3'],
      );
    });
    test('search by name or plate, ignoring case and spaces', () {
      expect(
        filterOnSite(visits, OnSiteFilter.all, 'thoko').map((v) => v.visitId),
        ['v2'],
      );
      expect(
        filterOnSite(visits, OnSiteFilter.all, 'bt 45').map((v) => v.visitId),
        ['v1'],
      );
      expect(filterOnSite(visits, OnSiteFilter.staff, 'thoko'), isEmpty);
    });
  });

  testWidgets('lists who is on site and checks someone out after confirming', (
    tester,
  ) async {
    final repo = FakeGateRepository(visits: List.of(visits));
    await tester.pumpWidget(
      themed(
        const OnSiteScreen(),
        overrides: fakeOverrides(
          auth: FakeAuthRepository(userId: 'u'),
          gates: repo,
          settings: InMemorySettings(
            const Gate(id: 'g-main', name: 'Main gate'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chikondi Banda'), findsOneWidget);
    expect(find.text('BT 4521'), findsOneWidget);
    expect(find.text('In 08:42'), findsOneWidget);
    expect(find.text('Thoko Phiri'), findsOneWidget);

    await tester.tap(find.text('Visitors'));
    await tester.pumpAndSettle();
    expect(find.text('Chikondi Banda'), findsNothing);
    expect(find.text('Thoko Phiri'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.enterText(find.byKey(const Key('search')), 'nobody');
    await tester.pumpAndSettle();
    expect(find.text('No one matches your search'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('search')), '');
    await tester.pumpAndSettle();

    // Cancel keeps them on site.
    await tester.tap(find.byKey(const Key('check-out-v1')));
    await tester.pumpAndSettle();
    expect(find.text('Check out Chikondi Banda?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.checkedOut, isEmpty);

    await tester.tap(find.byKey(const Key('check-out-v1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-check-out')));
    await tester.pumpAndSettle();
    expect(repo.checkedOut, ['v1']);
    expect(find.text('Chikondi Banda checked out'), findsOneWidget);
    expect(find.byKey(const Key('check-out-v1')), findsNothing);
  });

  testWidgets('empty state', (tester) async {
    await tester.pumpWidget(
      themed(
        const OnSiteScreen(),
        overrides: fakeOverrides(
          auth: FakeAuthRepository(userId: 'u'),
          gates: FakeGateRepository(),
          settings: InMemorySettings(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No one is on site right now'), findsOneWidget);
  });
}
