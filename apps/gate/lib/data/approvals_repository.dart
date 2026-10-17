import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'gate_repository.dart';
import 'request_models.dart';

enum RequestTab { pending, escalated, approved, rejected }

/// The receptionist/admin side of visitor requests (R1–R3).
abstract class ApprovalsRepository {
  Future<List<RequestSummary>> requests(RequestTab tab);
  Future<int> pendingCount();

  /// Fires whenever any pass changes (new request, decision) so lists can refresh.
  Stream<void> changes();
  Future<RequestDetail> detail(String passId);

  /// Short-lived link to an ID photo, or null if it cannot be viewed.
  Future<String?> photoUrl(String storagePath);
  Future<Decision> decide(
    String passId, {
    required bool approve,
    String? reason,
  });
  Future<List<ActivityItem>> recentActivity();
}

class SupabaseApprovalsRepository implements ApprovalsRepository {
  SupabaseApprovalsRepository(this._client);
  final SupabaseClient _client;

  static const _summaryColumns =
      'id, status, type, source, host_name, contact_phone, created_at, valid_from, valid_until, '
      'escalated_at, decided_at, reject_reason, people(full_name, phone), vehicles(plate)';

  Future<T> _call<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw const GateFailure('Your account cannot do this. Ask an admin.');
      }
      if (e.message == 'reason_required') {
        throw const GateFailure('Give a reason for rejecting.');
      }
      if (e.message == 'request_expired') {
        throw const GateFailure(
          'This request\'s dates have passed. Reject it instead.',
        );
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
  Future<List<RequestSummary>> requests(RequestTab tab) => _call(() async {
    var q = _client.from('passes').select(_summaryColumns).inFilter('type', [
      'day',
      'week',
    ]);
    final weekAgo = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 7))
        .toIso8601String();
    q = switch (tab) {
      RequestTab.pending => q.eq('status', 'pending'),
      RequestTab.escalated =>
        q.eq('status', 'pending').not('escalated_at', 'is', null),
      RequestTab.approved =>
        q.eq('status', 'approved').gte('decided_at', weekAgo),
      RequestTab.rejected =>
        q.eq('status', 'rejected').gte('decided_at', weekAgo),
    };
    final rows =
        await (tab == RequestTab.pending || tab == RequestTab.escalated
                ? q.order('created_at', ascending: true)
                : q.order('decided_at', ascending: false))
            .limit(100);
    return rows.map(RequestSummary.fromRow).toList();
  });

  @override
  Future<int> pendingCount() => _call(() async {
    final res = await _client
        .from('passes')
        .select('id')
        .eq('status', 'pending')
        .inFilter('type', ['day', 'week'])
        .count(CountOption.exact);
    return res.count;
  });

  @override
  Stream<void> changes() {
    late final RealtimeChannel channel;
    final controller = StreamController<void>.broadcast(
      onCancel: () => _client.removeChannel(channel),
    );
    channel = _client
        .channel('approvals-${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'passes',
          callback: (_) => controller.add(null),
        )
        .subscribe();
    return controller.stream;
  }

  @override
  Future<RequestDetail> detail(String passId) => _call(() async {
    final json = await _client.rpc(
      'request_detail',
      params: {'p_pass_id': passId},
    );
    return RequestDetail.fromJson(Map<String, dynamic>.from(json as Map));
  });

  @override
  Future<String?> photoUrl(String storagePath) async {
    try {
      return await _client.storage
          .from('id-photos')
          .createSignedUrl(storagePath, 300);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Decision> decide(
    String passId, {
    required bool approve,
    String? reason,
  }) => _call(() async {
    final json = await _client.rpc(
      'decide_request',
      params: {
        'p_pass_id': passId,
        'p_decision': approve ? 'approve' : 'reject',
        'p_reason': reason,
      },
    );
    return Decision.fromJson(Map<String, dynamic>.from(json as Map));
  });

  @override
  Future<List<ActivityItem>> recentActivity() => _call(() async {
    final rows = await _client
        .from('visits')
        .select('entry_at, exit_at, people(full_name), gates(name)')
        .order('created_at', ascending: false)
        .limit(6);
    return rows.map(ActivityItem.fromRow).toList();
  });
}
