import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('Marketplace app loads its main screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MarketplaceApp());

    expect(find.text('Marketplace UTB'), findsOneWidget);
    expect(find.text('Registro / Login'), findsOneWidget);
    expect(find.text('Crear publicación'), findsOneWidget);
  });
}
