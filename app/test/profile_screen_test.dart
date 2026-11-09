import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medireminder/screens/home_screen.dart';

void main() {
  testWidgets('profile button opens accessibility and sign-out options',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Shell()));

    await tester.tap(find.byTooltip('Abrir perfil y accesibilidad'));
    await tester.pumpAndSettle();

    expect(find.text('Tu perfil'), findsOneWidget);
    expect(find.text('Accesibilidad'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);

    await tester.tap(find.text('Accesibilidad'));
    await tester.pumpAndSettle();
    expect(find.text('Ajusta la app a tus necesidades'), findsOneWidget);
  });

  testWidgets('profile sign out returns to login after confirmation',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Shell()));
    await tester.tap(find.byTooltip('Abrir perfil y accesibilidad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('¿Quieres salir de tu cuenta de MediReminder?'),
        findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
