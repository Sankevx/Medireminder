import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medireminder/screens/home_screen.dart';

void main() {
  testWidgets('treatment form exposes schedule, route, and duration controls',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MedForm()),
    );

    expect(find.text('Vía de administración'), findsOneWidget);
    expect(find.text('Frecuencia de las dosis'), findsOneWidget);
    expect(find.text('Días de la semana'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Agregar hora'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Agregar hora'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Fecha de inicio'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Fecha de inicio'), findsOneWidget);
    expect(find.text('Fecha de fin'), findsOneWidget);
    expect(find.text('Agregar hora'), findsOneWidget);
  });

  testWidgets('interval schedule explains how its first time is used',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MedForm()),
    );

    await tester.tap(find.text('A horas específicas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cada 12 horas').last);
    await tester.pumpAndSettle();

    expect(
      find.text(
          'El intervalo empieza a partir del primer horario que agregues.'),
      findsOneWidget,
    );
    expect(find.text('Días de la semana'), findsNothing);
  });
}
