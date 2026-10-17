import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omis_gate/data/gate_repository.dart';
import 'package:omis_gate/data/models.dart';
import 'package:omis_gate/features/scan/scan_result_sheet.dart';
import 'package:omis_gate/features/scan/scan_session.dart';

import 'support/fakes.dart';

void main() {
  setUpAll(disableFontFetching);

  group('ScanSession', () {
    late FakeGateRepository repo;
    late DateTime now;
    late ScanSession session;

    setUp(() {
      repo = FakeGateRepository();
      now = DateTime(2026, 10, 17, 8);
      session = ScanSession(
        repository: repo,
        gateId: 'g-main',
        clock: () => now,
      );
    });

    test('records a scan at the chosen gate with a fresh event id', () async {
      final event = await session.handle(' token-1 ');
      expect(event, isA<ScanSucceeded>());
      expect(repo.scans.single.token, 'token-1');
      expect(repo.scans.single.gateId, 'g-main');
      expect(repo.scans.single.eventId, isNotNull);
    });

    test('ignores detections while a result is on screen', () async {
      await session.handle('token-1');
      expect(await session.handle('token-2'), isNull);
      expect(repo.scans, hasLength(1));
    });

    test(
      'ignores the same pass for 3 s after its result, so it is not scanned as an exit',
      () async {
        await session.handle('token-1');
        session.done();
        now = now.add(const Duration(seconds: 2));
        expect(await session.handle('token-1'), isNull);
        now = now.add(const Duration(seconds: 2));
        expect(await session.handle('token-1'), isA<ScanSucceeded>());
        expect(repo.scans, hasLength(2));
        expect(repo.scans[0].eventId, isNot(repo.scans[1].eventId));
      },
    );

    test('a different pass can be scanned straight away', () async {
      await session.handle('token-1');
      session.done();
      expect(await session.handle('token-2'), isA<ScanSucceeded>());
    });

    test('network failures become a message and scanning can resume', () async {
      repo.failWith = const GateFailure(
        'No connection. Check the network and try again.',
      );
      final event = await session.handle('token-1');
      expect((event as ScanFailed).message, contains('No connection'));
      session.done();
      repo.failWith = null;
      now = now.add(const Duration(seconds: 5));
      expect(await session.handle('token-1'), isA<ScanSucceeded>());
    });

    test('empty codes are ignored', () async {
      expect(await session.handle(null), isNull);
      expect(await session.handle('  '), isNull);
      expect(repo.scans, isEmpty);
    });
  });

  group('ScanResultSheet', () {
    Future<void> show(WidgetTester tester, ScanResult result) async {
      await tester.pumpWidget(
        themed(
          Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => ScanResultSheet(result: result),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('entry: name, type, plate and time; closes itself after 3 s', (
      tester,
    ) async {
      await show(
        tester,
        ScanResult(
          outcome: ScanOutcome.entryRecorded,
          fullName: 'Chikondi Banda',
          passType: PassType.staff,
          plate: 'BT4521',
          entryAt: DateTime.utc(2026, 10, 17, 6, 42),
        ),
      );
      expect(find.text('Entry recorded'), findsOneWidget);
      expect(find.text('Chikondi Banda'), findsOneWidget);
      expect(find.text('Staff'), findsOneWidget);
      expect(find.text('BT 4521'), findsOneWidget);
      expect(find.text('08:42'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Entry recorded'), findsNothing);
    });

    testWidgets('exit shows time on site', (tester) async {
      await show(
        tester,
        ScanResult(
          outcome: ScanOutcome.exitRecorded,
          fullName: 'Chikondi Banda',
          passType: PassType.staff,
          exitAt: DateTime.utc(2026, 10, 17, 15, 5),
          duration: const Duration(hours: 8, minutes: 23),
        ),
      );
      expect(find.text('Exit recorded'), findsOneWidget);
      expect(find.text('On site 8 h 23 min'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    final blocked = {
      ScanOutcome.pending: 'Not approved yet',
      ScanOutcome.rejected: 'Request rejected',
      ScanOutcome.revoked: 'Pass revoked',
      ScanOutcome.expired: 'Pass expired',
      ScanOutcome.notYetValid: 'Not valid yet',
      ScanOutcome.invalid: 'Unknown code',
    };
    blocked.forEach((outcome, title) {
      testWidgets('$outcome → "$title", stays until Scan again', (
        tester,
      ) async {
        await show(
          tester,
          ScanResult(
            outcome: outcome,
            fullName: outcome == ScanOutcome.invalid ? null : 'Thoko Phiri',
            passType: PassType.day,
            validUntil: DateTime.utc(2026, 10, 14, 22),
          ),
        );
        expect(find.text(title), findsOneWidget);
        expect(find.text('Scan again'), findsOneWidget);
        if (outcome == ScanOutcome.invalid) {
          expect(find.text('Thoko Phiri'), findsNothing);
        } else {
          expect(find.text('Thoko Phiri'), findsOneWidget);
        }
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(
          find.text(title),
          findsOneWidget,
          reason: 'blocked results do not close by themselves',
        );
        await tester.tap(find.text('Scan again'));
        await tester.pumpAndSettle();
        expect(find.text(title), findsNothing);
      });
    });

    testWidgets('expired shows the expiry date', (tester) async {
      await show(
        tester,
        ScanResult(
          outcome: ScanOutcome.expired,
          fullName: 'Thoko Phiri',
          passType: PassType.day,
          validUntil: DateTime.utc(2026, 10, 14, 10),
        ),
      );
      expect(find.text('Expired 14 Oct 2026'), findsOneWidget);
    });
  });
}
