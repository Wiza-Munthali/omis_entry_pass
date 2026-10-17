import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:omis_gate/data/models.dart';
import 'package:omis_gate/data/request_models.dart';
import 'package:omis_gate/features/requests/new_visitor_screen.dart';
import 'package:omis_gate/features/scan/scan_result_sheet.dart';
import 'package:omis_gate/main.dart';

import 'support/fakes.dart';

RequestSummary pendingRequest(
  String id,
  String name, {
  bool gate = true,
  DateTime? escalatedAt,
}) => RequestSummary(
  passId: id,
  status: RequestStatus.pending,
  passType: PassType.day,
  fromGate: gate,
  fullName: name,
  hostName: 'Finance',
  phone: '+265 88 123 4567',
  requestedAt: DateTime.now().subtract(const Duration(minutes: 4)),
  validFrom: DateTime.now(),
  validUntil: DateTime.now().add(const Duration(hours: 12)),
  escalatedAt: escalatedAt,
);

Future<void> startApp(
  WidgetTester tester, {
  required OperatorRole role,
  FakeApprovalsRepository? approvals,
  FakeGateRequestsRepository? requests,
  List<Override> extra = const [],
  double width = 390,
  double height = 844,
}) async {
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...fakeOverrides(
          auth: FakeAuthRepository(userId: 'u'),
          gates: FakeGateRepository(role: role),
          settings: InMemorySettings(
            const Gate(id: 'g-main', name: 'Main gate'),
          ),
          approvals: approvals,
          requests: requests,
        ),
        ...extra,
      ],
      child: const OmisGateApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// A real (1×1) PNG so the photo preview can decode it.
final tinyPng = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  ),
);

void main() {
  setUpAll(disableFontFetching);

  group('receptionist', () {
    testWidgets(
      'home shows pending count, needs-approval cards and the tab badge',
      (tester) async {
        final approvals = FakeApprovalsRepository(
          pending: [
            pendingRequest('p1', 'Chikondi Banda'),
            pendingRequest('p2', 'Thoko Phiri', gate: false),
          ],
        );
        await startApp(
          tester,
          role: OperatorRole.receptionist,
          approvals: approvals,
        );

        expect(find.text('Pending'), findsWidgets);
        expect(find.text('Needs approval'), findsOneWidget);
        expect(find.text('Chikondi Banda'), findsOneWidget);
        expect(find.text('Gate'), findsOneWidget);
        expect(find.text('Web'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('nav-Approvals')),
            matching: find.text('2'),
          ),
          findsOneWidget,
          reason: 'pending count badge on the Approvals tab',
        );
      },
    );

    testWidgets('approve from the queue; reject needs a reason', (
      tester,
    ) async {
      final approvals = FakeApprovalsRepository(
        pending: [
          pendingRequest('p1', 'Chikondi Banda'),
          pendingRequest('p2', 'Thoko Phiri', gate: false),
        ],
      );
      await startApp(
        tester,
        role: OperatorRole.receptionist,
        approvals: approvals,
      );
      await tester.tap(find.byKey(const Key('nav-Approvals')));
      await tester.pumpAndSettle();
      expect(find.text('4 min ago'), findsNWidgets(2));

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('request-p1')),
          matching: find.byKey(const Key('approve')),
        ),
      );
      await tester.pumpAndSettle();
      expect(approvals.decisions.single, (
        passId: 'p1',
        approve: true,
        reason: null,
      ));
      expect(find.text('Chikondi Banda approved'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('request-p2')),
          matching: find.byKey(const Key('reject')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reject Thoko Phiri?'), findsOneWidget);
      final confirm = tester.widget<FilledButton>(
        find.byKey(const Key('confirm-reject')),
      );
      expect(confirm.onPressed, isNull, reason: 'no reason yet');
      await tester.tap(find.text('No appointment today'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('confirm-reject')));
      await tester.tap(find.byKey(const Key('confirm-reject')));
      await tester.pumpAndSettle();
      expect(approvals.decisions.last, (
        passId: 'p2',
        approve: false,
        reason: 'No appointment today',
      ));
    });

    testWidgets('a request someone else already decided says so', (
      tester,
    ) async {
      final approvals =
          FakeApprovalsRepository(
              pending: [pendingRequest('p1', 'Chikondi Banda')],
            )
            ..nextDecision = const Decision(
              alreadyDecided: true,
              status: RequestStatus.rejected,
              decidedByName: 'Mercy Banda',
            );
      await startApp(
        tester,
        role: OperatorRole.receptionist,
        approvals: approvals,
      );
      await tester.tap(find.byKey(const Key('approve')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Already rejected by Mercy Banda. Your decision was not applied.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'request detail: visitor, visit, timeline and sticky decision buttons',
      (tester) async {
        final approvals = FakeApprovalsRepository(
          pending: [
            pendingRequest('p1', 'Chikondi Banda', escalatedAt: DateTime.now()),
          ],
          detail: RequestDetail(
            passId: 'p1',
            status: RequestStatus.pending,
            passType: PassType.week,
            fromGate: true,
            fullName: 'Chikondi Banda',
            idNumber: 'MW-123',
            phone: '+265 88 123 4567',
            plate: 'BT4521',
            hostName: 'Finance',
            purpose: 'meeting',
            requestedByName: 'Yamikani Phiri',
            requestedAt: DateTime.now().subtract(const Duration(minutes: 7)),
            escalatedAt: DateTime.now().subtract(const Duration(minutes: 2)),
            validFrom: DateTime.utc(2026, 10, 17, 22),
            validUntil: DateTime.utc(2026, 10, 24, 22),
          ),
        );
        await startApp(
          tester,
          role: OperatorRole.receptionist,
          approvals: approvals,
        );
        await tester.tap(find.text('Chikondi Banda'));
        await tester.pumpAndSettle();

        expect(find.text('Request details'), findsOneWidget);
        expect(find.text('ID: MW-123'), findsOneWidget);
        expect(find.text('Meeting'), findsOneWidget);
        expect(find.text('BT 4521'), findsOneWidget);
        expect(find.textContaining('By Yamikani Phiri'), findsOneWidget);
        expect(find.text('Escalated to admins'), findsOneWidget);
        expect(find.text('Waiting long'), findsOneWidget);

        await tester.tap(find.byKey(const Key('approve')));
        await tester.pumpAndSettle();
        expect(approvals.decisions.single.approve, isTrue);
        expect(
          find.text('Request details'),
          findsNothing,
          reason: 'returns to the list after deciding',
        );
      },
    );
  });

  group('guard', () {
    testWidgets(
      'registers a visitor with an ID photo and follows the decision live',
      (tester) async {
        final requests = FakeGateRequestsRepository();
        await startApp(
          tester,
          role: OperatorRole.guard,
          requests: requests,
          extra: [takePhotoProvider.overrideWithValue(() async => tinyPng)],
          // Tall window so the whole form is on screen; phone-size layout is covered below.
          height: 1800,
        );
        await tester.tap(find.byKey(const Key('nav-New visitor')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('send-for-approval')));
        await tester.pumpAndSettle();
        expect(find.text('Enter the visitor\'s full name.'), findsOneWidget);
        expect(find.text('Choose the purpose.'), findsOneWidget);
        expect(requests.created, isEmpty);

        await tester.enterText(
          find.byKey(const Key('visitor-name')),
          'Mphatso Kalua',
        );
        await tester.enterText(find.byKey(const Key('visitor-id')), 'MW 5555');
        await tester.enterText(
          find.byKey(const Key('visitor-host')),
          'ICT unit',
        );
        await tester.tap(find.byKey(const Key('visitor-purpose')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Contractor work').last);
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('One week'));
        await tester.tap(find.byKey(const Key('add-id-photo')));
        await tester.pumpAndSettle();
        expect(find.text('ID photo added'), findsOneWidget);

        await tester.tap(find.byKey(const Key('send-for-approval')));
        await tester.pumpAndSettle();

        final sent = requests.created.single;
        expect(
          (
            sent.fullName,
            sent.idNumber,
            sent.hostName,
            sent.purpose,
            sent.passType,
          ),
          ('Mphatso Kalua', 'MW 5555', 'ICT unit', 'contractor', PassType.week),
        );
        expect(
          requests.photos['req-1'],
          tinyPng.lengthInBytes,
          reason: 'ID photo uploaded for the new request',
        );
        expect(find.text('Request sent'), findsOneWidget);
        expect(find.text('Sent to reception at'), findsOneWidget);

        // Reception approves: the broadcast arrives and the screen refreshes.
        requests.requests = [
          GateRequest(
            passId: 'req-1',
            statusToken: 'tok-req-1',
            status: RequestStatus.approved,
            fullName: 'Mphatso Kalua',
            passType: PassType.week,
            requestedAt: DateTime.now(),
          ),
        ];
        requests.emitStatus(RequestStatus.approved);
        await tester.pumpAndSettle();
        expect(find.text('Approved'), findsWidgets);

        await tester.tap(find.byKey(const Key('check-in-now')));

        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(requests.checkedIn, ['req-1']);
        expect(find.text('Entry recorded'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('a rejected request shows the reason', (tester) async {
      final requests = FakeGateRequestsRepository()
        ..requests = [
          GateRequest(
            passId: 'r1',
            statusToken: 't1',
            status: RequestStatus.rejected,
            fullName: 'Chisomo Gondwe',
            passType: PassType.day,
            requestedAt: DateTime.now(),
            rejectReason: 'Host is not available',
          ),
        ];
      await startApp(tester, role: OperatorRole.guard, requests: requests);
      expect(
        find.text('Chisomo Gondwe'),
        findsOneWidget,
        reason: 'listed on the guard home',
      );
      await tester.tap(find.byKey(const Key('my-request-r1')));
      await tester.pumpAndSettle();
      expect(find.text('Not approved'), findsOneWidget);
      expect(find.text('Reason: Host is not available'), findsOneWidget);
    });

    testWidgets('returning visitor: find by name and check in', (tester) async {
      final requests = FakeGateRequestsRepository()
        ..matches = [
          VisitorPassMatch(
            passId: 'w1',
            fullName: 'Kondwani Mwale',
            idLast4: '7731',
            passType: PassType.week,
            validUntil: DateTime.now().add(const Duration(days: 3)),
            plate: 'MZ2210',
          ),
        ];
      await startApp(tester, role: OperatorRole.guard, requests: requests);
      await tester.tap(find.byKey(const Key('nav-New visitor')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('returning-visitor')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('returning-search')), 'Ko');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.textContaining('at least 3 letters'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('returning-search')),
        'Kondwani',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.textContaining('ID …7731'), findsOneWidget);
      await tester.tap(find.byKey(const Key('check-in-w1')));
      await tester.pumpAndSettle();
      expect(requests.checkedIn, ['w1']);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });
  });

  testWidgets('scan-and-approve: a pending result offers Review request', (
    tester,
  ) async {
    var reviewed = false;
    await tester.pumpWidget(
      themed(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => ScanResultSheet(
                result: const ScanResult(
                  outcome: ScanOutcome.pending,
                  fullName: 'Thoko Phiri',
                  passId: 'p9',
                ),
                onReview: () => reviewed = true,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Not approved yet'), findsOneWidget);
    await tester.tap(find.byKey(const Key('review-request')));
    expect(reviewed, isTrue);
  });

  for (final width in [320.0, 360.0]) {
    testWidgets(
      'no overflow at ${width.toInt()} dp: approvals, request card, new visitor',
      (tester) async {
        final approvals = FakeApprovalsRepository(
          pending: [
            pendingRequest(
              'p1',
              'Jane Mpinganjira-Chirwa Banda',
              escalatedAt: DateTime.now(),
            ),
          ],
        );
        await startApp(
          tester,
          role: OperatorRole.admin,
          approvals: approvals,
          width: width,
        );
        await tester.tap(find.byKey(const Key('nav-Approvals')));
        await tester.pumpAndSettle();
        expect(
          find.text('Escalated'),
          findsOneWidget,
          reason: 'admins get the Escalated tab',
        );

        await startApp(tester, role: OperatorRole.guard, width: width);
        await tester.tap(find.byKey(const Key('nav-New visitor')));
        await tester.pumpAndSettle();
        expect(find.text('Send for approval'), findsOneWidget);
      },
    );
  }
}
