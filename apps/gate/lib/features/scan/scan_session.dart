import '../../core/event_id.dart';
import '../../data/gate_repository.dart';
import '../../data/models.dart';

/// What the scanner should show after a code is read.
sealed class ScanEvent {}

class ScanSucceeded extends ScanEvent {
  ScanSucceeded(this.result);
  final ScanResult result;
}

class ScanFailed extends ScanEvent {
  ScanFailed(this.message);
  final String message;
}

/// Turns camera detections into record_scan calls.
///
/// * One scan at a time: detections while a scan is in flight or a result is on
///   screen are ignored (the camera reports the same code many times a second).
/// * The same code is ignored for [repeatWindow] after its result is dismissed, so
///   a pass still in front of the camera is not scanned again as an exit.
/// * Each scan gets its own client_event_id, so a retried network call is safe.
class ScanSession {
  ScanSession({
    required this.repository,
    required this.gateId,
    this.repeatWindow = const Duration(seconds: 3),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final GateRepository repository;
  final String gateId;
  final Duration repeatWindow;
  final DateTime Function() _now;

  bool _busy = false;
  String? _lastCode;
  DateTime? _lastDoneAt;

  bool get busy => _busy;

  /// Returns null when the detection should be ignored.
  Future<ScanEvent?> handle(String? rawValue) async {
    final code = rawValue?.trim();
    if (code == null || code.isEmpty || _busy) return null;
    if (code == _lastCode &&
        _lastDoneAt != null &&
        _now().difference(_lastDoneAt!) < repeatWindow) {
      return null;
    }

    _busy = true;
    _lastCode = code;
    try {
      final result = await repository.recordScan(
        qrToken: code,
        gateId: gateId,
        eventId: newEventId(),
      );
      return ScanSucceeded(result);
    } on GateFailure catch (e) {
      return ScanFailed(e.message);
    } catch (_) {
      return ScanFailed('Something went wrong. Try again.');
    }
  }

  /// Call when the result has been dismissed and scanning can resume.
  void done() {
    _busy = false;
    _lastDoneAt = _now();
  }
}
