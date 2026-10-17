import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/event_id.dart';
import 'gate_repository.dart';
import 'models.dart';
import 'request_models.dart';

/// A request just sent from the gate.
class CreatedRequest {
  const CreatedRequest({required this.passId, required this.statusToken});
  final String passId;
  final String statusToken;
}

/// The guard's side of visitor requests (G7–G9) and returning visitors.
abstract class GateRequestsRepository {
  Future<CreatedRequest> create(NewVisitor visitor);
  Future<void> uploadIdPhoto(String passId, Uint8List jpeg);
  Future<List<GateRequest>> mine();

  /// Fires with the new status whenever the request is decided (Realtime broadcast).
  Stream<RequestStatus> statusChanges(String statusToken);
  Future<List<VisitorPassMatch>> findVisitors(String query);
  Future<ScanResult> checkIn(String passId, String gateId);
}

class SupabaseGateRequestsRepository implements GateRequestsRepository {
  SupabaseGateRequestsRepository(this._client);
  final SupabaseClient _client;

  Future<T> _call<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on PostgrestException catch (e) {
      final message = switch (e.message) {
        'full_name_required' => 'Enter the visitor\'s full name.',
        'id_number_required' => 'Enter the ID number.',
        'host_name_required' => 'Enter who they are visiting.',
        'purpose_required' => 'Choose the purpose of the visit.',
        'invalid_plate' => 'Use letters and numbers only for the plate.',
        'gate_not_found' => 'This gate is closed. Choose another gate.',
        _ when e.code == '42501' =>
          'Your account cannot do this. Ask an admin.',
        _ => 'Server error: ${e.message}',
      };
      throw GateFailure(message);
    } on StorageException catch (e) {
      throw GateFailure(
        e.statusCode == '413'
            ? 'The photo is too large. Take it again.'
            : 'Photo upload failed.',
      );
    } on GateFailure {
      rethrow;
    } catch (_) {
      throw const GateFailure(
        'No connection. Check the network and try again.',
      );
    }
  }

  @override
  Future<CreatedRequest> create(NewVisitor v) => _call(() async {
    final json = await _client.rpc(
      'create_gate_request',
      params: {
        'p_full_name': v.fullName,
        'p_id_number': v.idNumber,
        'p_pass_type': v.passType.name,
        'p_host_name': v.hostName,
        'p_purpose': v.purpose,
        'p_phone': v.phone,
        'p_plate': v.plate,
        'p_client_request_id': newEventId(),
      },
    );
    final m = Map<String, dynamic>.from(json as Map);
    return CreatedRequest(
      passId: m['pass_id'] as String,
      statusToken: m['status_token'] as String,
    );
  });

  @override
  Future<void> uploadIdPhoto(String passId, Uint8List jpeg) => _call(() async {
    final path = '$passId/${newEventId()}.jpg';
    await _client.storage
        .from('id-photos')
        .uploadBinary(
          path,
          jpeg,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    await _client.from('id_photos').insert({
      'pass_id': passId,
      'storage_path': path,
    });
  });

  @override
  Future<List<GateRequest>> mine() => _call(() async {
    final json = await _client.rpc('my_gate_requests');
    return (json as List)
        .map((e) => GateRequest.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  });

  @override
  Stream<RequestStatus> statusChanges(String statusToken) {
    late final RealtimeChannel channel;
    final controller = StreamController<RequestStatus>.broadcast(
      onCancel: () => _client.removeChannel(channel),
    );
    channel = _client
        .channel('request:$statusToken')
        .onBroadcast(
          event: 'status_changed',
          callback: (payload) {
            final inner = payload['payload'] is Map
                ? payload['payload'] as Map
                : payload;
            controller.add(RequestStatus.parse(inner['status']));
          },
        )
        .subscribe();
    return controller.stream;
  }

  @override
  Future<List<VisitorPassMatch>> findVisitors(String query) => _call(() async {
    final json = await _client.rpc(
      'find_visitor_passes',
      params: {'p_query': query},
    );
    return (json as List)
        .map(
          (e) => VisitorPassMatch.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  });

  @override
  Future<ScanResult> checkIn(String passId, String gateId) => _call(() async {
    final json = await _client.rpc(
      'check_in_pass',
      params: {
        'p_pass_id': passId,
        'p_gate_id': gateId,
        'p_client_event_id': newEventId(),
      },
    );
    return ScanResult.fromJson(Map<String, dynamic>.from(json as Map));
  });
}
