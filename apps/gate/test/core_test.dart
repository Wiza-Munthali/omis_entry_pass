import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omis_gate/core/event_id.dart';
import 'package:omis_gate/core/redirect.dart';
import 'package:omis_gate/core/time.dart';
import 'package:omis_gate/data/models.dart';

const guard = Profile(
  id: 'u',
  fullName: 'Y P',
  email: 'g@x',
  role: OperatorRole.guard,
);
const staff = Profile(id: 'u', fullName: 'S P', email: 's@x', role: null);
const gate = Gate(id: 'g', name: 'Main gate');

String? where(
  String at, {
  AsyncValue<String?>? user,
  AsyncValue<Profile?>? profile,
  AsyncValue<Gate?>? g,
}) => resolveRedirect(
  location: at,
  userId: user ?? const AsyncData('u'),
  profile: profile ?? const AsyncData(guard),
  gate: g ?? const AsyncData(gate),
);

void main() {
  group('redirect', () {
    test('signed out goes to sign-in, and stays there', () {
      expect(where('/home', user: const AsyncData(null)), '/sign-in');
      expect(where('/sign-in', user: const AsyncData(null)), isNull);
    });
    test('waits while sign-in, profile or gate load', () {
      expect(where('/home', user: const AsyncLoading()), '/loading');
      expect(where('/home', profile: const AsyncLoading()), '/loading');
      expect(where('/home', g: const AsyncLoading()), '/loading');
    });
    test('profile failure shows the loading screen (retry / sign out)', () {
      expect(
        where(
          '/home',
          profile: AsyncError(Exception('offline'), StackTrace.empty),
        ),
        '/loading',
      );
    });
    test('non-operators are stopped', () {
      expect(where('/home', profile: const AsyncData(staff)), '/not-operator');
      expect(where('/home', profile: const AsyncData(null)), '/not-operator');
    });
    test('operators without a gate choose one', () {
      expect(where('/home', g: const AsyncData(null)), '/gate');
    });
    test(
      'ready operators leave setup screens for home, and may revisit the gate list',
      () {
        expect(where('/sign-in'), '/home');
        expect(where('/loading'), '/home');
        expect(where('/not-operator'), '/home');
        expect(where('/gate'), isNull);
        expect(where('/on-site'), isNull);
      },
    );
  });

  group('time and display', () {
    test('times show in Africa/Blantyre (UTC+2) whatever the phone zone', () {
      expect(formatTime(DateTime.utc(2026, 10, 17, 6, 42)), '08:42');
      expect(formatDate(DateTime.utc(2027, 10, 16, 23, 30)), '17 Oct 2027');
    });
    test('durations', () {
      expect(formatDuration(const Duration(seconds: 30)), 'under a minute');
      expect(formatDuration(const Duration(minutes: 12)), '12 min');
      expect(
        formatDuration(const Duration(hours: 2, minutes: 5)),
        '2 h 05 min',
      );
    });
    test('plates and initials', () {
      expect(displayPlate('BT4521'), 'BT 4521');
      expect(initials('Chikondi  Banda'), 'CB');
      expect(initials('Thoko'), 'T');
    });
    test('event ids are random UUID v4', () {
      final a = newEventId();
      expect(
        a,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(newEventId(), isNot(a));
    });
  });

  group('models', () {
    test('every record_scan result parses', () {
      const map = {
        'entry_recorded': ScanOutcome.entryRecorded,
        'exit_recorded': ScanOutcome.exitRecorded,
        'already_checked_out': ScanOutcome.alreadyCheckedOut,
        'pending': ScanOutcome.pending,
        'rejected': ScanOutcome.rejected,
        'revoked': ScanOutcome.revoked,
        'expired': ScanOutcome.expired,
        'not_yet_valid': ScanOutcome.notYetValid,
        'invalid': ScanOutcome.invalid,
        'something_new': ScanOutcome.invalid,
      };
      map.forEach(
        (json, outcome) =>
            expect(ScanOutcome.parse(json), outcome, reason: json),
      );
    });
    test('scan payload', () {
      final r = ScanResult.fromJson({
        'result': 'exit_recorded',
        'full_name': 'Chikondi Banda',
        'pass_type': 'staff',
        'plate': 'BT4521',
        'entry_at': '2026-10-17T06:42:00Z',
        'exit_at': '2026-10-17T15:05:00Z',
        'duration_seconds': 30180,
        'replayed': true,
      });
      expect(r.outcome, ScanOutcome.exitRecorded);
      expect(r.passType, PassType.staff);
      expect(r.duration, const Duration(hours: 8, minutes: 23));
      expect(r.replayed, isTrue);
      expect(r.outcome.allowed, isTrue);
      expect(ScanOutcome.revoked.allowed, isFalse);
    });
    test('only active guards, receptionists and admins are operators', () {
      Profile p(String role, bool active) => Profile.fromRow({
        'id': 'u',
        'full_name': 'A B',
        'email': 'a@b',
        'role': role,
        'is_active': active,
      });
      expect(p('guard', true).role, OperatorRole.guard);
      expect(p('admin', true).canApprove, isTrue);
      expect(p('guard', true).canApprove, isFalse);
      expect(p('staff', true).isOperator, isFalse);
      expect(p('admin', false).isOperator, isFalse);
    });
  });
}
