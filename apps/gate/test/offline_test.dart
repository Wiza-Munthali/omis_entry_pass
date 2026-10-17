import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omis_gate/data/gate_repository.dart';
import 'package:omis_gate/data/gate_requests_repository.dart';
import 'package:omis_gate/data/local_db.dart';
import 'package:omis_gate/data/models.dart';
import 'package:omis_gate/data/offline_store.dart';
import 'package:omis_gate/data/request_models.dart';
import 'package:omis_gate/data/scan_service.dart';
import 'package:omis_gate/data/sync_worker.dart';
import 'package:omis_gate/main.dart';

import 'support/fakes.dart';

String hashOf(String token) => sha256.convert(utf8.encode(token)).toString();

/// A tiny stand-in for the server: one visit per entry/exit, idempotent on event id,
/// and switches for "unreachable" and "recorded but the reply was lost".
class ServerSim extends FakeGateRepository {
  ServerSim(this.connectivity);

  final FakeConnectivity connectivity;
  final passes = <String, ({String id, String name})>{}; // token → pass
  final open = <String, DateTime>{}; // pass id → entry time
  final events = <String, ScanResult>{}; // event id → original result
  final eventOrder = <String>[];
  int visitCount = 0;
  final loseReplyFor = <String>{}; // event ids whose reply is "lost" once
  final refuse = <String>{}; // event ids the server refuses

  void addPass(String token, String id, String name) =>
      passes[token] = (id: id, name: name);

  ScanResult _record(String? token, DateTime at, String eventId) {
    if (!connectivity.online) {
      throw const GateFailure('No connection', network: true);
    }
    if (refuse.contains(eventId)) throw const GateFailure('gate_not_found');
    final seen = events[eventId];
    if (seen != null) {
      return ScanResult(
        outcome: seen.outcome,
        passId: seen.passId,
        fullName: seen.fullName,
        replayed: true,
      );
    }
    final pass = passes[token];
    if (pass == null) return const ScanResult(outcome: ScanOutcome.invalid);
    final ScanResult result;
    if (open.containsKey(pass.id)) {
      open.remove(pass.id);
      result = ScanResult(
        outcome: ScanOutcome.exitRecorded,
        passId: pass.id,
        fullName: pass.name,
      );
    } else {
      open[pass.id] = at;
      visitCount++;
      result = ScanResult(
        outcome: ScanOutcome.entryRecorded,
        passId: pass.id,
        fullName: pass.name,
        entryAt: at,
      );
    }
    events[eventId] = result;
    eventOrder.add(eventId);
    if (loseReplyFor.remove(eventId)) {
      throw const GateFailure('Connection dropped', network: true);
    }
    return result;
  }

  @override
  Future<ScanResult> recordScan({
    required String qrToken,
    required String gateId,
    String? eventId,
  }) async => _record(qrToken, DateTime.now().toUtc(), eventId!);

  @override
  Future<ScanResult> recordOfflineScan({
    required String tokenHash,
    required String gateId,
    required DateTime scannedAt,
    required String eventId,
  }) async {
    final token = passes.keys.where((t) => hashOf(t) == tokenHash).firstOrNull;
    return _record(token, scannedAt, eventId);
  }

  @override
  Future<OfflineCacheData> offlineCache() async {
    if (!connectivity.online) {
      throw const GateFailure('No connection', network: true);
    }
    return OfflineCacheData(
      generatedAt: DateTime.now().toUtc(),
      passes: [
        for (final e in passes.entries)
          {
            'token_hash': hashOf(e.key),
            'pass_id': e.value.id,
            'full_name': e.value.name,
            'pass_type': 'staff',
            'valid_from': DateTime.utc(2026).toIso8601String(),
            'valid_until': DateTime.utc(2030).toIso8601String(),
          },
      ],
      openVisits: [
        for (final e in open.entries)
          {
            'pass_id': e.key,
            'visit_id': 'v-${e.key}',
            'entry_at': e.value.toIso8601String(),
          },
      ],
    );
  }
}

/// Gate requests on the simulated server: idempotent on client_request_id.
class RequestsSim extends FakeGateRequestsRepository {
  RequestsSim(this.connectivity);
  final FakeConnectivity connectivity;
  final byRequestId = <String, CreatedRequest>{};

  @override
  Future<CreatedRequest> create(NewVisitor v, {String? clientRequestId}) async {
    if (!connectivity.online) {
      throw const GateFailure('No connection', network: true);
    }
    return byRequestId.putIfAbsent(clientRequestId!, () {
      created.add(v);
      return CreatedRequest(
        passId: 'req-${byRequestId.length + 1}',
        statusToken: 't',
      );
    });
  }
}

void main() {
  setUpAll(disableFontFetching);

  late LocalDb db;
  late OfflineStore store;
  late FakeConnectivity net;
  late ServerSim server;
  late RequestsSim requests;
  late ScanService scanner;
  late SyncWorker worker;

  setUp(() async {
    db = LocalDb(NativeDatabase.memory());
    store = OfflineStore(db);
    net = FakeConnectivity(online: true);
    server = ServerSim(net);
    requests = RequestsSim(net);
    scanner = ScanService(remote: server, store: store, connectivity: net);
    worker = SyncWorker(
      store: store,
      remote: server,
      requests: requests,
      connectivity: net,
    );
    for (var i = 1; i <= 5; i++) {
      server.addPass('token-$i', 'pass-$i', 'Person $i');
    }
    await worker.refreshCache();
  });

  tearDown(() async {
    await worker.stop();
    await db.close();
  });

  test('fingerprints are sha256 hex, like passes.qr_token_hash', () {
    expect(
      tokenFingerprint('abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test('the cache holds fingerprints, never tokens', () async {
    final rows = await db.select(db.cachedPasses).get();
    expect(rows, hasLength(5));
    expect(
      rows.every((r) => RegExp(r'^[0-9a-f]{64}$').hasMatch(r.tokenHash)),
      isTrue,
    );
    expect(rows.any((r) => r.tokenHash.contains('token-')), isFalse);
  });

  test('online: scans go straight to the server; nothing is queued', () async {
    final r = await scanner.scan('token-1', 'g-main');
    expect((r.outcome, r.offline), (ScanOutcome.entryRecorded, false));
    expect(server.visitCount, 1);
    expect(await store.pending(), isEmpty);
    expect(
      await store.isOnSite('pass-1'),
      isTrue,
      reason: 'local view follows online scans',
    );
  });

  test(
    'acceptance: 10 scans in airplane mode all sync, once, after a forced retry',
    () async {
      net.online = false;

      // Five people come in and go out again: 10 scans with no network.
      final results = <ScanResult>[];
      for (var i = 1; i <= 5; i++) {
        results.add(await scanner.scan('token-$i', 'g-main'));
      }
      for (var i = 1; i <= 5; i++) {
        results.add(await scanner.scan('token-$i', 'g-main'));
      }
      expect(results.every((r) => r.offline), isTrue);
      expect(results.take(5).map((r) => r.outcome).toSet(), {
        ScanOutcome.entryRecorded,
      });
      expect(results.skip(5).map((r) => r.outcome).toSet(), {
        ScanOutcome.exitRecorded,
      });
      expect(await store.pending(), hasLength(10));
      expect(server.events, isEmpty);

      // Back online, but the reply for the 6th scan is lost after the server recorded it.
      final queued = await store.pending();
      server.loseReplyFor.add(queued[5].eventId);
      net.online = true;
      await worker.syncNow();
      expect(
        server.events,
        hasLength(6),
        reason: 'stopped at the lost reply, keeping order',
      );
      expect(
        await store.pending(),
        hasLength(5),
        reason: 'the 6th is still queued',
      );

      // Forced retry: the 6th is resent with the same event id and is only a replay.
      await worker.syncNow();
      expect(await store.pending(), isEmpty);
      expect(
        server.events,
        hasLength(10),
        reason: 'all 10 scans recorded exactly once',
      );
      expect(
        server.eventOrder,
        queued.map((q) => q.eventId).toList(),
        reason: 'in the order they were scanned',
      );
      expect(
        server.visitCount,
        5,
        reason: 'five visits, each entered and left',
      );
      expect(server.open, isEmpty);

      // Retrying again (or concurrently) changes nothing.
      await Future.wait([worker.syncNow(), worker.syncNow()]);
      expect(server.events, hasLength(10));
    },
  );

  test(
    'a call that fails to reach the server is queued with the same event id',
    () async {
      net.online = true;
      // Make the server record, then lose the reply, for whatever event id comes next.
      final r = await (() async {
        final svc = ScanService(
          remote: _LoseNextReply(server),
          store: store,
          connectivity: net,
        );
        return svc.scan('token-2', 'g-main');
      })();
      expect(r.offline, isTrue, reason: 'shown as saved offline');
      final queued = await store.pending();
      expect(queued, hasLength(1));
      expect(
        server.events.keys,
        contains(queued.single.eventId),
        reason: 'server already has this event',
      );

      await worker.syncNow();
      expect(
        server.visitCount,
        1,
        reason: 'the queued copy is a replay, not a second visit',
      );
      expect(await store.pending(), isEmpty);
    },
  );

  test(
    'offline: codes not in the cache cannot be checked and are not queued',
    () async {
      net.online = false;
      final r = await scanner.scan('stranger', 'g-main');
      expect(r.outcome, ScanOutcome.unknownOffline);
      expect(await store.pending(), isEmpty);
    },
  );

  test('offline: an expired cached pass is refused and not queued', () async {
    await store.replaceCache(
      OfflineCacheData(
        generatedAt: DateTime.now(),
        passes: [
          {
            'token_hash': hashOf('old'),
            'pass_id': 'old',
            'full_name': 'Old Pass',
            'pass_type': 'day',
            'valid_from': DateTime.utc(2025).toIso8601String(),
            'valid_until': DateTime.utc(2025, 2).toIso8601String(),
          },
        ],
        openVisits: const [],
      ),
    );
    net.online = false;
    final r = await scanner.scan('old', 'g-main');
    expect((r.outcome, r.fullName), (ScanOutcome.expired, 'Old Pass'));
    expect(await store.pending(), isEmpty);
  });

  test(
    'a cache refresh keeps people scanned in offline but not yet synced',
    () async {
      net.online = false;
      await scanner.scan('token-3', 'g-main');
      net.online = true;
      // Server does not know yet; refresh from it, then the queued entry is re-applied.
      await worker.refreshCache();
      expect(await store.isOnSite('pass-3'), isTrue);
      net.online = false;
      expect(
        (await scanner.scan('token-3', 'g-main')).outcome,
        ScanOutcome.exitRecorded,
        reason: 'the next offline scan is still an exit',
      );
    },
  );

  test('a refused item is set aside and does not block the rest', () async {
    net.online = false;
    await scanner.scan('token-1', 'g-main');
    await scanner.scan('token-2', 'g-main');
    final queued = await store.pending();
    server.refuse.add(queued.first.eventId);
    net.online = true;
    await worker.syncNow();
    expect(await store.pending(), isEmpty);
    expect(await store.watchFailedCount().first, 1);
    expect(server.events.keys, [queued.last.eventId]);
  });

  test(
    'a gate request made offline is sent later with its photo, once',
    () async {
      net.online = false;
      await store.enqueue(
        kind: 'request',
        eventId: 'req-event-1',
        payload: {
          'full_name': 'Mphatso Kalua',
          'id_number': 'MW 5555',
          'host_name': 'ICT',
          'purpose': 'meeting',
          'pass_type': 'day',
        },
        photo: Uint8List.fromList([1, 2, 3]),
      );
      await worker.syncNow();
      expect(requests.created, isEmpty, reason: 'nothing sent while offline');

      net.online = true;
      await worker.syncNow();
      await worker.syncNow();
      expect(requests.created.single.fullName, 'Mphatso Kalua');
      expect(
        requests.byRequestId.keys,
        ['req-event-1'],
        reason: 'sent with the outbox event id as client_request_id',
      );
      expect(requests.photos['req-1'], 3);
      expect(await store.pending(), isEmpty);
    },
  );

  testWidgets('banner: "Offline — 2 scans waiting to sync"', (tester) async {
    final widgetDb = LocalDb(NativeDatabase.memory());
    final net = FakeConnectivity(online: false);
    await OfflineStore(
      widgetDb,
    ).enqueue(kind: 'scan', eventId: 'e1', payload: {});
    await OfflineStore(
      widgetDb,
    ).enqueue(kind: 'scan', eventId: 'e2', payload: {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(
          auth: FakeAuthRepository(userId: 'u'),
          gates: FakeGateRepository(),
          settings: InMemorySettings(
            const Gate(id: 'g-main', name: 'Main gate'),
          ),
          connectivity: net,
          db: widgetDb,
          liveOutbox: true,
        ),
        child: const OmisGateApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Offline — 2 scans waiting to sync'), findsOneWidget);
    await unmountAndFlush(tester);
  });

  testWidgets('a new visitor registered offline is saved to send later', (
    tester,
  ) async {
    final widgetDb = LocalDb(NativeDatabase.memory());
    tester.view.physicalSize = const Size(390 * 3, 1800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(
          auth: FakeAuthRepository(userId: 'u'),
          gates: FakeGateRepository(),
          settings: InMemorySettings(
            const Gate(id: 'g-main', name: 'Main gate'),
          ),
          connectivity: FakeConnectivity(online: false),
          db: widgetDb,
          liveOutbox: true,
        ),
        child: const OmisGateApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-New visitor')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('visitor-name')),
      'Mphatso Kalua',
    );
    await tester.enterText(find.byKey(const Key('visitor-id')), 'MW 5555');
    await tester.enterText(find.byKey(const Key('visitor-host')), 'ICT');
    await tester.tap(find.byKey(const Key('visitor-purpose')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Meeting').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('send-for-approval')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('request-queued')), findsOneWidget);
    final queued = await OfflineStore(widgetDb).pending();
    expect(queued.single.kind, 'request');
    expect(jsonDecode(queued.single.payload)['full_name'], 'Mphatso Kalua');
    expect(find.text('Offline — 1 scan waiting to sync'), findsOneWidget);
    await unmountAndFlush(tester);
  });
}

/// Records on the server, then loses the reply — for the next call only.
class _LoseNextReply extends FakeGateRepository {
  _LoseNextReply(this.server);
  final ServerSim server;

  @override
  Future<ScanResult> recordScan({
    required String qrToken,
    required String gateId,
    String? eventId,
  }) async {
    server.loseReplyFor.add(eventId!);
    return server.recordScan(
      qrToken: qrToken,
      gateId: gateId,
      eventId: eventId,
    );
  }
}
