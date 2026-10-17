import 'models.dart';

DateTime? _time(Object? v) => v == null ? null : DateTime.parse(v as String);

PassType _type(Object? v) => v == 'week'
    ? PassType.week
    : (v == 'staff' ? PassType.staff : PassType.day);

/// Request status as shown to operators ("expired" for approved passes past their dates).
enum RequestStatus {
  pending,
  approved,
  rejected,
  revoked,
  expired;

  static RequestStatus parse(Object? v) => RequestStatus.values.firstWhere(
    (s) => s.name == v,
    orElse: () => pending,
  );
}

/// One row of the receptionist's approval queue (R2).
class RequestSummary {
  const RequestSummary({
    required this.passId,
    required this.status,
    required this.passType,
    required this.fromGate,
    required this.fullName,
    required this.requestedAt,
    required this.validFrom,
    required this.validUntil,
    this.hostName,
    this.phone,
    this.plate,
    this.escalatedAt,
    this.decidedAt,
    this.rejectReason,
  });

  final String passId;
  final RequestStatus status;
  final PassType passType;
  final bool fromGate;
  final String fullName;
  final String? hostName;
  final String? phone;
  final String? plate;
  final DateTime requestedAt;
  final DateTime validFrom;
  final DateTime validUntil;
  final DateTime? escalatedAt;
  final DateTime? decidedAt;
  final String? rejectReason;

  bool get escalated => escalatedAt != null;

  factory RequestSummary.fromRow(Map<String, dynamic> r) {
    final person = (r['people'] as Map?) ?? const {};
    final vehicle = r['vehicles'] as Map?;
    final validUntil = DateTime.parse(r['valid_until'] as String);
    var status = RequestStatus.parse(r['status']);
    if (status == RequestStatus.approved &&
        !validUntil.isAfter(DateTime.now())) {
      status = RequestStatus.expired;
    }
    return RequestSummary(
      passId: r['id'] as String,
      status: status,
      passType: _type(r['type']),
      fromGate: r['source'] == 'gate',
      fullName: person['full_name'] as String? ?? '—',
      hostName: r['host_name'] as String?,
      phone: (r['contact_phone'] ?? person['phone']) as String?,
      plate: vehicle?['plate'] as String?,
      requestedAt: DateTime.parse(r['created_at'] as String),
      validFrom: DateTime.parse(r['valid_from'] as String),
      validUntil: validUntil,
      escalatedAt: _time(r['escalated_at']),
      decidedAt: _time(r['decided_at']),
      rejectReason: r['reject_reason'] as String?,
    );
  }
}

/// Everything on the request detail screen (R3), from request_detail.
class RequestDetail {
  const RequestDetail({
    required this.passId,
    required this.status,
    required this.passType,
    required this.fromGate,
    required this.fullName,
    required this.requestedAt,
    required this.validFrom,
    required this.validUntil,
    this.idNumber,
    this.phone,
    this.email,
    this.plate,
    this.hostName,
    this.purpose,
    this.requestedByName,
    this.decidedByName,
    this.escalatedAt,
    this.decidedAt,
    this.rejectReason,
    this.photoPaths = const [],
  });

  final String passId;
  final RequestStatus status;
  final PassType passType;
  final bool fromGate;
  final String fullName;
  final String? idNumber;
  final String? phone;
  final String? email;
  final String? plate;
  final String? hostName;
  final String? purpose;
  final String? requestedByName;
  final String? decidedByName;
  final DateTime requestedAt;
  final DateTime validFrom;
  final DateTime validUntil;
  final DateTime? escalatedAt;
  final DateTime? decidedAt;
  final String? rejectReason;
  final List<String> photoPaths;

  factory RequestDetail.fromJson(Map<String, dynamic> j) => RequestDetail(
    passId: j['pass_id'] as String,
    status: RequestStatus.parse(j['status']),
    passType: _type(j['pass_type']),
    fromGate: j['source'] == 'gate',
    fullName: j['full_name'] as String,
    idNumber: j['id_number'] as String?,
    phone: j['phone'] as String?,
    email: j['email'] as String?,
    plate: j['plate'] as String?,
    hostName: j['host_name'] as String?,
    purpose: j['purpose'] as String?,
    requestedByName: j['requested_by_name'] as String?,
    decidedByName: j['decided_by_name'] as String?,
    requestedAt: DateTime.parse(j['requested_at'] as String),
    validFrom: DateTime.parse(j['valid_from'] as String),
    validUntil: DateTime.parse(j['valid_until'] as String),
    escalatedAt: _time(j['escalated_at']),
    decidedAt: _time(j['decided_at']),
    rejectReason: j['reject_reason'] as String?,
    photoPaths: ((j['photo_paths'] as List?) ?? const []).cast<String>(),
  );
}

/// Result of decide_request.
class Decision {
  const Decision({
    required this.alreadyDecided,
    required this.status,
    this.decidedByName,
  });

  final bool alreadyDecided;
  final RequestStatus status;
  final String? decidedByName;

  factory Decision.fromJson(Map<String, dynamic> j) => Decision(
    alreadyDecided: j['result'] == 'already_decided',
    status: RequestStatus.parse(j['status']),
    decidedByName: j['decided_by_name'] as String?,
  );
}

/// A guard's own gate request (G3 waiting list, G9).
class GateRequest {
  const GateRequest({
    required this.passId,
    required this.statusToken,
    required this.status,
    required this.fullName,
    required this.passType,
    required this.requestedAt,
    this.hostName,
    this.plate,
    this.escalatedAt,
    this.decidedAt,
    this.rejectReason,
    this.onSite = false,
  });

  final String passId;
  final String statusToken;
  final RequestStatus status;
  final String fullName;
  final PassType passType;
  final String? hostName;
  final String? plate;
  final DateTime requestedAt;
  final DateTime? escalatedAt;
  final DateTime? decidedAt;
  final String? rejectReason;
  final bool onSite;

  factory GateRequest.fromJson(Map<String, dynamic> j) => GateRequest(
    passId: j['pass_id'] as String,
    statusToken: j['status_token'] as String,
    status: RequestStatus.parse(j['status']),
    fullName: j['full_name'] as String,
    passType: _type(j['pass_type']),
    hostName: j['host_name'] as String?,
    plate: j['plate'] as String?,
    requestedAt: DateTime.parse(j['requested_at'] as String),
    escalatedAt: _time(j['escalated_at']),
    decidedAt: _time(j['decided_at']),
    rejectReason: j['reject_reason'] as String?,
    onSite: j['on_site'] == true,
  );
}

/// A returning visitor found by name or ID (find_visitor_passes).
class VisitorPassMatch {
  const VisitorPassMatch({
    required this.passId,
    required this.fullName,
    required this.passType,
    required this.validUntil,
    this.idLast4,
    this.plate,
    this.hostName,
    this.onSite = false,
  });

  final String passId;
  final String fullName;
  final String? idLast4;
  final PassType passType;
  final String? plate;
  final String? hostName;
  final DateTime validUntil;
  final bool onSite;

  factory VisitorPassMatch.fromJson(Map<String, dynamic> j) => VisitorPassMatch(
    passId: j['pass_id'] as String,
    fullName: j['full_name'] as String,
    idLast4: j['id_last4'] as String?,
    passType: _type(j['pass_type']),
    plate: j['plate'] as String?,
    hostName: j['host_name'] as String?,
    validUntil: DateTime.parse(j['valid_until'] as String),
    onSite: j['on_site'] == true,
  );
}

/// What the guard enters on the New visitor form (G7).
class NewVisitor {
  const NewVisitor({
    required this.fullName,
    required this.idNumber,
    required this.hostName,
    required this.purpose,
    required this.passType,
    this.phone,
    this.plate,
  });

  final String fullName;
  final String idNumber;
  final String hostName;
  final String purpose;
  final PassType passType;
  final String? phone;
  final String? plate;
}

/// A recent entry or exit for the receptionist's activity feed (R1).
class ActivityItem {
  const ActivityItem({
    required this.fullName,
    required this.gateName,
    required this.entryAt,
    this.exitAt,
  });

  final String fullName;
  final String gateName;
  final DateTime entryAt;
  final DateTime? exitAt;

  DateTime get latest => exitAt ?? entryAt;

  factory ActivityItem.fromRow(Map<String, dynamic> r) => ActivityItem(
    fullName: ((r['people'] as Map?)?['full_name'] as String?) ?? '—',
    gateName: ((r['gates'] as Map?)?['name'] as String?) ?? '',
    entryAt: DateTime.parse(r['entry_at'] as String),
    exitAt: _time(r['exit_at']),
  );
}
