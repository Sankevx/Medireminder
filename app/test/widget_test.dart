// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medireminder/main.dart';
import 'package:medireminder/screens/auth_screen.dart';

void main() {
  testWidgets('MediReminder opens on login screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MediReminderApp());

    expect(find.text('MediReminder'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('password recovery requires a valid email before continuing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: RecoverScreen()),
    );

    await tester.tap(find.text('Enviar código'));
    await tester.pump();

    expect(find.text('Paso 1 de 3'), findsOneWidget);
    expect(find.text('Ingresa un correo válido.'), findsOneWidget);
  });
}
