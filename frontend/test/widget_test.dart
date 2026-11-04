import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('MFU333 app starts successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const Mfu333App());

    expect(find.byType(Mfu333App), findsOneWidget);
  });
}
