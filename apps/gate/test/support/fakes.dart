import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:google_fonts/google_fonts.dart';
import 'package:omis_gate/core/connectivity.dart';
import 'package:omis_gate/core/providers.dart';
import 'package:omis_gate/core/theme/app_theme.dart';
import 'package:omis_gate/data/approvals_repository.dart';
import 'package:omis_gate/data/auth_repository.dart';
import 'package:omis_gate/data/gate_repository.dart';
import 'package:omis_gate/data/gate_requests_repository.dart';
import 'package:omis_gate/data/local_db.dart';
import 'package:omis_gate/data/models.dart';
import 'package:omis_gate/data/request_models.dart';
import 'package:omis_gate/data/settings_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({String? userId})
    : _userId = userId; // ignore: prefer_initializing_formals

  final _changes = StreamController<String?>.broadcast();
  String? _userId;
  final sentTo = <String>[];
  String validCode = '123456';
  String signInAs = 'user-1';

  @override
  String? get currentUserId => _userId;

  @override
  Stream<String?> userIdChanges() => _changes.stream;

  @override
  Future<void> sendCode(String email) async => sentTo.add(email);

  @override
  Future<void> verifyCode(String email, String code) async {
    if (code != validCode) {
      throw const AuthFailure('That code is wrong or has expired.');
    }
    _userId = signInAs;
    _changes.add(_userId);
  }

  @override
  Future<void> signOut() async {
    _userId = null;
    _changes.add(null);
  }
}

class FakeGateRepository implements GateRepository {
  FakeGateRepository({
    this.role = OperatorRole.guard,
    List<OnSiteVisit>? visits,
  }) : visits = visits ?? [];

  OperatorRole? role;
  List<OnSiteVisit> visits;
  GateStats statsValue = const GateStats(onSite: 42, entriesToday: 118);
  final gates = const [
    Gate(id: 'g-main', name: 'Main gate'),
    Gate(id: 'g-back', name: 'Back gate'),
  ];
  ScanResult Function(String token)? onScan;
  final scans = <({String token, String gateId, String? eventId})>[];
  final checkedOut = <String>[];
  Object? failWith;

  @override
  Future<Profile?> profile(String userId) async => Profile(
    id: userId,
    fullName: 'Yamikani Phiri',
    email: 'guard@ghii.test',
    role: role,
  );

  @override
  Future<List<Gate>> activeGates() async => gates;

  @override
  Future<GateStats> stats(String? gateId) async => statsValue;

  @override
  Future<ScanResult> recordScan({
    required String qrToken,
    required String gateId,
    String? eventId,
  }) async {
    if (failWith != null) throw failWith!;
    scans.add((token: qrToken, gateId: gateId, eventId: eventId));
    return onScan?.call(qrToken) ??
        const ScanResult(
          outcome: ScanOutcome.entryRecorded,
          fullName: 'Chikondi Banda',
        );
  }

  @override
  Future<List<OnSiteVisit>> onSite() async => List.of(visits);

  final offlineScans = <({String tokenHash, String eventId})>[];
  OfflineCacheData cache = OfflineCacheData(
    generatedAt: DateTime.utc(2026),
    passes: const [],
    openVisits: const [],
  );

  @override
  Future<OfflineCacheData> offlineCache() async => cache;

  @override
  Future<ScanResult> recordOfflineScan({
    required String tokenHash,
    required String gateId,
    required DateTime scannedAt,
    required String eventId,
  }) async {
    offlineScans.add((tokenHash: tokenHash, eventId: eventId));
    return const ScanResult(outcome: ScanOutcome.entryRecorded);
  }

  final pushTokens = <String, String?>{};

  @override
  Future<void> setPushToken(String userId, String? token) async =>
      pushTokens[userId] = token;

  @override
  Future<ScanResult> checkOut(String visitId, {String? eventId}) async {
    checkedOut.add(visitId);
    visits = visits.where((v) => v.visitId != visitId).toList();
    return const ScanResult(outcome: ScanOutcome.exitRecorded);
  }
}

class InMemorySettings implements SettingsRepository {
  InMemorySettings([this.gate]);
  Gate? gate;

  @override
  Future<Gate?> selectedGate() async => gate;

  @override
  Future<void> setSelectedGate(Gate g) async => gate = g;

  @override
  Future<void> clearSelectedGate() async => gate = null;
}

class FakeApprovalsRepository implements ApprovalsRepository {
  FakeApprovalsRepository({
    List<RequestSummary>? pending,
    RequestDetail? detail,
  }) : pending = pending ?? [],
       detailValue = detail;

  List<RequestSummary> pending;
  RequestDetail? detailValue;
  final decisions = <({String passId, bool approve, String? reason})>[];
  Decision? nextDecision;
  final _changes = StreamController<void>.broadcast();

  void emitChange() => _changes.add(null);

  @override
  Future<List<RequestSummary>> requests(RequestTab tab) async =>
      tab == RequestTab.pending ? List.of(pending) : [];

  @override
  Future<int> pendingCount() async => pending.length;

  @override
  Stream<void> changes() => _changes.stream;

  @override
  Future<RequestDetail> detail(String passId) async => detailValue!;

  @override
  Future<String?> photoUrl(String storagePath) async => null;

  @override
  Future<Decision> decide(
    String passId, {
    required bool approve,
    String? reason,
  }) async {
    decisions.add((passId: passId, approve: approve, reason: reason));
    pending = pending.where((p) => p.passId != passId).toList();
    return nextDecision ??
        Decision(
          alreadyDecided: false,
          status: approve ? RequestStatus.approved : RequestStatus.rejected,
        );
  }

  @override
  Future<List<ActivityItem>> recentActivity() async => const [];
}

class FakeGateRequestsRepository implements GateRequestsRepository {
  final created = <NewVisitor>[];
  final photos = <String, int>{};
  List<GateRequest> requests = [];
  List<VisitorPassMatch> matches = [];
  final checkedIn = <String>[];
  final _status = StreamController<RequestStatus>.broadcast();

  void emitStatus(RequestStatus s) => _status.add(s);

  final requestIds = <String?>[];

  @override
  Future<CreatedRequest> create(NewVisitor v, {String? clientRequestId}) async {
    requestIds.add(clientRequestId);
    created.add(v);
    final id = 'req-${created.length}';
    requests = [
      GateRequest(
        passId: id,
        statusToken: 'tok-$id',
        status: RequestStatus.pending,
        fullName: v.fullName,
        passType: v.passType,
        hostName: v.hostName,
        requestedAt: DateTime.now(),
      ),
      ...requests,
    ];
    return CreatedRequest(passId: id, statusToken: 'tok-$id');
  }

  @override
  Future<void> uploadIdPhoto(String passId, Uint8List jpeg) async =>
      photos[passId] = jpeg.lengthInBytes;

  @override
  Future<List<GateRequest>> mine() async => List.of(requests);

  @override
  Stream<RequestStatus> statusChanges(String statusToken) => _status.stream;

  @override
  Future<List<VisitorPassMatch>> findVisitors(String query) async => matches;

  @override
  Future<ScanResult> checkIn(String passId, String gateId) async {
    checkedIn.add(passId);
    return const ScanResult(
      outcome: ScanOutcome.entryRecorded,
      fullName: 'Visitor',
    );
  }
}

/// Switchable network state ("airplane mode") for tests.
class FakeConnectivity implements ConnectivityService {
  FakeConnectivity({bool online = true})
    : _online = online; // ignore: prefer_initializing_formals

  bool _online;
  final _changes = StreamController<bool>.broadcast();

  bool get online => _online;
  set online(bool value) {
    _online = value;
    _changes.add(value);
  }

  @override
  Future<bool> isOnline() async => _online;

  @override
  Stream<bool> onlineChanges() => _changes.stream;
}

/// Provider overrides wiring the fakes in.
List<Override> fakeOverrides({
  required FakeAuthRepository auth,
  required FakeGateRepository gates,
  required InMemorySettings settings,
  FakeApprovalsRepository? approvals,
  FakeGateRequestsRepository? requests,
  FakeConnectivity? connectivity,
  LocalDb? db,
  bool liveOutbox = false,
}) => [
  // drift's live queries close on a timer after their last listener leaves, which
  // widget tests report as pending; tests not about offline get fixed counts.
  if (!liveOutbox) ...[
    outboxCountProvider.overrideWith((ref) => Stream.value(0)),
    outboxFailedProvider.overrideWith((ref) => Stream.value(0)),
  ],
  localDbProvider.overrideWith((ref) {
    final local = db ?? LocalDb(NativeDatabase.memory());
    ref.onDispose(local.close);
    return local;
  }),
  connectivityProvider.overrideWithValue(connectivity ?? FakeConnectivity()),
  authRepositoryProvider.overrideWithValue(auth),
  gateRepositoryProvider.overrideWithValue(gates),
  settingsRepositoryProvider.overrideWithValue(settings),
  approvalsRepositoryProvider.overrideWithValue(
    approvals ?? FakeApprovalsRepository(),
  ),
  gateRequestsRepositoryProvider.overrideWithValue(
    requests ?? FakeGateRequestsRepository(),
  ),
];

/// A single screen inside the app theme, with fakes.
Widget themed(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: child),
      ),
    );

void disableFontFetching() => GoogleFonts.config.allowRuntimeFetching = false;

/// Unmounts the app and lets drift close its live queries, so no timer is left pending.
Future<void> unmountAndFlush(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}
