import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sippt_movil/formato.dart';
import 'package:sippt_movil/widgets/distintivo.dart';

void main() {
  testWidgets('El distintivo muestra la palabra, no solo el color', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Distintivo(estado: EstadoVisual.critico)),
    ));
    expect(find.text('Crítico'), findsOneWidget);
  });
}
