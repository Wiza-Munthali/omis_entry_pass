import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:omis_gate/main.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('app boots to the setup screen', (tester) async {
    await tester.pumpWidget(const OmisGateApp());
    expect(find.text('OMIS Entry'), findsOneWidget);
    expect(find.text('Scan pass'), findsOneWidget);
  });
}
