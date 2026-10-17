import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/event_id.dart';
import 'models.dart';

/// Thrown when the server cannot be reached or refuses a call.
class GateFailure implements Exception {
  const GateFailure(this.message, {this.network = false});
  final String message;

  /// True when the server could not be reached (as opposed to refusing the call).
  /// Scans and gate requests then fall back to the offline outbox.
  final bool network;
  @override
  String toString() => message;
}

/// Everything the gate screens read or change. All writes go through RPCs.
abstract class GateRepository {
  Future<Profile?> profile(String userId);
  Future<List<Gate>> activeGates();
  Future<GateStats> stats(String? gateId);
  Future<ScanResult> recordScan({
    required String qrToken,
    required String gateId,
    String? eventId,
  });
  Future<List<OnSiteVisit>> onSite();
  Future<ScanResult> checkOut(String visitId, {String? eventId});

  /// Saves (or clears, with null) this phone's push token on the operator's profile.
  Future<void> setPushToken(String userId, String? token);

  /// Approved pass fingerprints and open visits for the offline cache.
  Future<OfflineCacheData> offlineCache();

  /// Sends a scan made offline: by fingerprint, with its original time and event id.
  Future<ScanResult> recordOfflineScan({
    required String tokenHash,
    required String gateId,
    required DateTime scannedAt,
    required String eventId,
  });
}

/// What offline_pass_cache returns.
class OfflineCacheData {
  const OfflineCacheData({
    required this.generatedAt,
    required this.passes,
    required this.openVisits,
  });

  final DateTime generatedAt;
  final List<Map<String, dynamic>> passes;
  final List<Map<String, dynamic>> openVisits;

  factory OfflineCacheData.fromJson(Map<String, dynamic> j) => OfflineCacheData(
    generatedAt: DateTime.parse(j['generated_at'] as String),
    passes: ((j['passes'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
    openVisits: ((j['open_visits'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
  );
}

class SupabaseGateRepository implements GateRepository {
  SupabaseGateRepository(this._client);
  final SupabaseClient _client;

  Future<T> _call<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw const GateFailure('Your account cannot do this. Ask an admin.');
      }
      if (e.message == 'gate_not_found') {
        throw const GateFailure('This gate is closed. Choose another gate.');
      }
      throw GateFailure('Server error: ${e.message}');
    } on GateFailure {
      rethrow;
    } catch (_) {
      throw const GateFailure(
        'No connection. Check the network and try again.',
      );
    }
  }

  @override
  Future<Profile?> profile(String userId) => _call(() async {
    final row = await _client
        .from('profiles')
        .select('id, full_name, email, role, is_active')
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : Profile.fromRow(row);
  });

  @override
  Future<List<Gate>> activeGates() => _call(() async {
    final rows = await _client
        .from('gates')
        .select('id, name')
        .eq('is_active', true)
        .order('name');
    return rows.map(Gate.fromRow).toList();
  });

  @override
  Future<GateStats> stats(String? gateId) => _call(() async {
    final json = await _client.rpc('gate_stats', params: {'p_gate_id': gateId});
    return GateStats.fromJson(Map<String, dynamic>.from(json as Map));
  });

  @override
  Future<ScanResult> recordScan({
    required String qrToken,
    required String gateId,
    String? eventId,
  }) => _call(() async {
    final json = await _client.rpc(
      'record_scan',
      params: {
        'p_qr_token': qrToken,
        'p_gate_id': gateId,
        'p_scanned_at': DateTime.now().toUtc().toIso8601String(),
        'p_client_event_id': eventId ?? newEventId(),
      },
    );
    return ScanResult.fromJson(Map<String, dynamic>.from(json as Map));
  });

  @override
  Future<List<OnSiteVisit>> onSite() => _call(() async {
    final rows = await _client
        .from('on_site')
        .select(
          'visit_id, full_name, pass_type, vehicle_plate, gate_name, entry_at',
        )
        .order('entry_at', ascending: false);
    return rows.map(OnSiteVisit.fromRow).toList();
  });

  @override
  Future<ScanResult> checkOut(String visitId, {String? eventId}) =>
      _call(() async {
        final json = await _client.rpc(
          'check_out',
          params: {
            'p_visit_id': visitId,
            'p_client_event_id': eventId ?? newEventId(),
          },
        );
        return ScanResult.fromJson(Map<String, dynamic>.from(json as Map));
      });

  @override
  Future<OfflineCacheData> offlineCache() => _call(() async {
    final json = await _client.rpc('offline_pass_cache');
    return OfflineCacheData.fromJson(Map<String, dynamic>.from(json as Map));
  });

  @override
  Future<ScanResult> recordOfflineScan({
    required String tokenHash,
    required String gateId,
    required DateTime scannedAt,
    required String eventId,
  }) => _call(() async {
    final json = await _client.rpc(
      'record_offline_scan',
      params: {
        'p_token_hash': tokenHash,
        'p_gate_id': gateId,
        'p_scanned_at': scannedAt.toUtc().toIso8601String(),
        'p_client_event_id': eventId,
      },
    );
    return ScanResult.fromJson(Map<String, dynamic>.from(json as Map));
  });

  @override
  Future<void> setPushToken(String userId, String? token) => _call(
    () =>
        _client.from('profiles').update({'fcm_token': token}).eq('id', userId),
  );
}
