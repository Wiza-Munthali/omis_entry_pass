import 'package:sentry_flutter/sentry_flutter.dart';

import 'env.dart';

/// Error reporting to Sentry (Phase 9). Without SENTRY_DSN nothing is sent and
/// [runReported] just runs the app.
///
/// Guards handle visitors' names, phone numbers, ID numbers and plates, and every
/// scanned QR code is a secret, so events are scrubbed before they leave the phone
/// (same rules as the web app's lib/observability/scrub.ts):
/// - only the user's id is kept (no email, name or IP);
/// - URLs lose their query string and token-like segments;
/// - emails, phone numbers and tokens in messages are masked;
/// - console/debug-print breadcrumbs are dropped.
/// Only errors are sent: no sessions, performance traces, screenshots or replays.
Future<void> runReported(void Function() runApp) async {
  if (Env.sentryDsn.isEmpty) {
    runApp();
    return;
  }
  await SentryFlutter.init((options) {
    options
      ..dsn = Env.sentryDsn
      ..environment = Env.sentryEnvironment
      ..sendDefaultPii = false
      ..enableAutoSessionTracking = false
      ..enableAutoPerformanceTracing = false
      ..enableUserInteractionBreadcrumbs = false
      ..attachScreenshot = false
      ..attachViewHierarchy = false
      ..beforeSend = ((event, hint) => scrubEvent(event))
      ..beforeBreadcrumb = ((crumb, hint) => scrubBreadcrumb(crumb));
  }, appRunner: runApp);
}

/// Tags later errors with the signed-in operator's id (never their email or name).
void setReportedUser(String? id) {
  if (Env.sentryDsn.isEmpty) return;
  Sentry.configureScope(
    (scope) => scope.setUser(id == null ? null : SentryUser(id: id)),
  );
}

/// Base64url secrets are 32+ characters (24 or 32 random bytes).
final _token = RegExp(r'[A-Za-z0-9_-]{32,}');
final _email = RegExp(r'''[^\s@"'<>()]+@[^\s@"'<>()]+\.[A-Za-z]{2,}''');
final _digits = RegExp(r'\+?\d[\d\s-]{6,}\d');
final _nonDigit = RegExp(r'\D');

String scrubText(String text) => text
    .replaceAll(_email, '[email]')
    .replaceAll(_token, '[token]')
    // 9+ digits is a phone number; dates (8 digits) stay readable.
    .replaceAllMapped(
      _digits,
      (m) => m[0]!.replaceAll(_nonDigit, '').length >= 9 ? '[phone]' : m[0]!,
    );

String scrubUrl(String url) => url
    .split(RegExp('[?#]'))
    .first
    .replaceAll(_token, '[token]')
    .replaceAll(_email, '[email]');

Breadcrumb? scrubBreadcrumb(Breadcrumb? crumb) {
  if (crumb == null) return null;
  if (crumb.category == 'console' || crumb.category == 'print') return null;
  if (crumb.message != null) crumb.message = scrubText(crumb.message!);
  final data = crumb.data;
  if (data != null) {
    final clean = Map<String, dynamic>.of(data)..remove('body');
    for (final key in const ['url', 'from', 'to']) {
      final value = clean[key];
      if (value is String) clean[key] = scrubUrl(value);
    }
    crumb.data = clean;
  }
  return crumb;
}

SentryEvent scrubEvent(SentryEvent event) {
  final message = event.message;
  if (message != null) {
    event.message = SentryMessage(scrubText(message.formatted));
  }
  final request = event.request;
  if (request != null) {
    event.request = SentryRequest(
      url: request.url == null ? null : scrubUrl(request.url!),
    );
  }
  final user = event.user;
  if (user != null) {
    event.user = user.id == null ? null : SentryUser(id: user.id);
  }
  final transaction = event.transaction;
  if (transaction != null) event.transaction = scrubUrl(transaction);
  for (final exception in event.exceptions ?? const <SentryException>[]) {
    if (exception.value != null) exception.value = scrubText(exception.value!);
  }
  event.breadcrumbs = event.breadcrumbs
      ?.map(scrubBreadcrumb)
      .whereType<Breadcrumb>()
      .toList();
  return event;
}
