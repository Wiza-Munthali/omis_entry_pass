import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:google_fonts/google_fonts.dart';
import 'package:omis_gate/core/providers.dart';
import 'package:omis_gate/core/theme/app_theme.dart';
import 'package:omis_gate/data/auth_repository.dart';
import 'package:omis_gate/data/gate_repository.dart';
import 'package:omis_gate/data/models.dart';
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

/// Provider overrides wiring the fakes in.
List<Override> fakeOverrides({
  required FakeAuthRepository auth,
  required FakeGateRepository gates,
  required InMemorySettings settings,
}) => [
  authRepositoryProvider.overrideWithValue(auth),
  gateRepositoryProvider.overrideWithValue(gates),
  settingsRepositoryProvider.overrideWithValue(settings),
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
