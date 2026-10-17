import 'package:flutter_test/flutter_test.dart';
import 'package:omis_gate/main.dart';

import 'support/fakes.dart';

void main() {
  setUpAll(disableFontFetching);

  testWidgets('without Supabase settings the app explains how to run it', (
    tester,
  ) async {
    await tester.pumpWidget(const SetupApp());
    expect(find.text('OMIS Entry'), findsOneWidget);
    expect(find.textContaining('--dart-define-from-file'), findsOneWidget);
  });
}
