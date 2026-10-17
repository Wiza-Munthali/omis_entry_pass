// Plain data types shared by repositories and screens.
library;

enum OperatorRole { guard, receptionist, admin }

class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
  });

  final String id;
  final String fullName;
  final String email;

  /// Null when the account is not an active operator (staff, or deactivated).
  final OperatorRole? role;

  bool get isOperator => role != null;
  bool get canApprove =>
      role == OperatorRole.receptionist || role == OperatorRole.admin;

  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;

  factory Profile.fromRow(Map<String, dynamic> row) {
    final active = row['is_active'] as bool? ?? false;
    final role = switch (row['role']) {
      'guard' => OperatorRole.guard,
      'receptionist' => OperatorRole.receptionist,
      'admin' => OperatorRole.admin,
      _ => null,
    };
    return Profile(
      id: row['id'] as String,
      fullName: (row['full_name'] as String?)?.trim().isNotEmpty == true
          ? row['full_name'] as String
          : (row['email'] as String).split('@').first,
      email: row['email'] as String,
      role: active ? role : null,
    );
  }
}

class Gate {
  const Gate({required this.id, required this.name});

  final String id;
  final String name;

  factory Gate.fromRow(Map<String, dynamic> row) =>
      Gate(id: row['id'] as String, name: row['name'] as String);

  @override
  bool operator ==(Object other) =>
      other is Gate && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

class GateStats {
  const GateStats({required this.onSite, required this.entriesToday});

  final int onSite;
  final int entriesToday;

  factory GateStats.fromJson(Map<String, dynamic> j) => GateStats(
    onSite: (j['on_site'] as num).toInt(),
    entriesToday: (j['entries_today'] as num).toInt(),
  );
}

enum PassType { staff, day, week }

PassType? _passType(Object? v) => switch (v) {
  'staff' => PassType.staff,
  'day' => PassType.day,
  'week' => PassType.week,
  _ => null,
};

/// Every outcome of record_scan and check_out (docs/SPEC.md → 5. Scanning at the gate).
enum ScanOutcome {
  entryRecorded,
  exitRecorded,
  alreadyCheckedOut,
  invalid,
  pending,
  rejected,
  revoked,
  expired,
  notYetValid;

  static ScanOutcome parse(String value) => switch (value) {
    'entry_recorded' => entryRecorded,
    'exit_recorded' => exitRecorded,
    'already_checked_out' => alreadyCheckedOut,
    'pending' => pending,
    'rejected' => rejected,
    'revoked' => revoked,
    'expired' => expired,
    'not_yet_valid' => notYetValid,
    _ => invalid,
  };

  bool get allowed =>
      this == entryRecorded ||
      this == exitRecorded ||
      this == alreadyCheckedOut;
}

class ScanResult {
  const ScanResult({
    required this.outcome,
    this.fullName,
    this.passType,
    this.plate,
    this.validUntil,
    this.visitId,
    this.entryAt,
    this.exitAt,
    this.duration,
    this.replayed = false,
    this.passId,
  });

  final ScanOutcome outcome;

  /// The pass that was scanned (absent for unknown codes). Approvers use it to
  /// open a pending request straight from the scan (scan-and-approve).
  final String? passId;
  final String? fullName;
  final PassType? passType;
  final String? plate;
  final DateTime? validUntil;
  final String? visitId;
  final DateTime? entryAt;
  final DateTime? exitAt;
  final Duration? duration;
  final bool replayed;

  factory ScanResult.fromJson(Map<String, dynamic> j) {
    DateTime? time(String key) =>
        j[key] == null ? null : DateTime.parse(j[key] as String);
    return ScanResult(
      outcome: ScanOutcome.parse(j['result'] as String? ?? 'invalid'),
      fullName: j['full_name'] as String?,
      passType: _passType(j['pass_type']),
      plate: j['plate'] as String?,
      validUntil: time('valid_until'),
      visitId: j['visit_id'] as String?,
      entryAt: time('entry_at'),
      exitAt: time('exit_at'),
      duration: j['duration_seconds'] == null
          ? null
          : Duration(seconds: (j['duration_seconds'] as num).toInt()),
      replayed: j['replayed'] == true,
      passId: j['pass_id'] as String?,
    );
  }
}

class OnSiteVisit {
  const OnSiteVisit({
    required this.visitId,
    required this.fullName,
    required this.passType,
    required this.gateName,
    required this.entryAt,
    this.plate,
  });

  final String visitId;
  final String fullName;
  final PassType passType;
  final String gateName;
  final DateTime entryAt;
  final String? plate;

  bool get isStaff => passType == PassType.staff;

  factory OnSiteVisit.fromRow(Map<String, dynamic> r) => OnSiteVisit(
    visitId: r['visit_id'] as String,
    fullName: r['full_name'] as String,
    passType: _passType(r['pass_type']) ?? PassType.day,
    gateName: r['gate_name'] as String,
    entryAt: DateTime.parse(r['entry_at'] as String),
    plate: r['vehicle_plate'] as String?,
  );
}
