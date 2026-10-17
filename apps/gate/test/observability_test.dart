import 'package:flutter_test/flutter_test.dart';
import 'package:omis_gate/core/observability.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const qrToken = 'Zq3vX9k2LmN8pR4tY6wB1cD5fG7hJ0aSxY2'; // like a scanned code

void main() {
  test('masks emails, phone numbers and tokens; keeps dates', () {
    expect(
      scrubText('grace@gmail.com +265 991 234 567 scanned $qrToken'),
      '[email] [phone] scanned [token]',
    );
    expect(
      scrubText('expired 2026-10-17 at 23:59'),
      'expired 2026-10-17 at 23:59',
    );
  });

  test('URLs lose queries and tokens', () {
    expect(
      scrubUrl('http://10.0.2.2:54321/rest/v1/passes?qr_token=eq.$qrToken'),
      'http://10.0.2.2:54321/rest/v1/passes',
    );
  });

  test('events keep only the user id and scrubbed text', () {
    final event = scrubEvent(
      SentryEvent(
        message: SentryMessage('Scan failed for $qrToken'),
        user: SentryUser(id: 'u1', email: 'guard@ghii.org', name: 'Guard'),
        exceptions: [SentryException(type: 'E', value: 'phone 0991234567')],
        breadcrumbs: [
          Breadcrumb(category: 'console', message: 'grace@gmail.com'),
          Breadcrumb(
            category: 'navigation',
            data: {'to': '/approvals/abc?name=Grace'},
          ),
        ],
      ),
    );
    expect(event.message!.formatted, 'Scan failed for [token]');
    expect(event.user!.id, 'u1');
    expect(event.user!.email, isNull);
    expect(event.user!.name, isNull);
    expect(event.exceptions!.single.value, 'phone [phone]');
    expect(event.breadcrumbs!.map((b) => b.data?['to']), ['/approvals/abc']);
  });
}
