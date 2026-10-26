import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('Carga de estructura visual básica de UTB Market', (WidgetTester tester) async {
    // Definir tamaño de ventana adecuado para desktop/web
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const UtbMarketApp());
    await tester.pumpAndSettle();

    // Verificamos textos clave en la interfaz
    expect(find.text('UTB Market'), findsOneWidget);
    expect(find.text('Mercado Estudiantil'), findsOneWidget);
    expect(find.text('Iniciar Sesión'), findsOneWidget);
    expect(find.text('Categorías Destacadas'), findsOneWidget);
  });
}
