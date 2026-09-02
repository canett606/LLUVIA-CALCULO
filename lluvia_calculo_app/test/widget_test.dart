import 'package:flutter_test/flutter_test.dart';
import 'package:lluvia_calculo/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const LluviaCalculoApp());

    // Verify basic app loads
    expect(find.text('Lluvia de Cálculo Mental'), findsOneWidget);
  });
}
