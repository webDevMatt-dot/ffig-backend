import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/auth/signup_screen.dart';

void main() {
  testWidgets('signup screen renders key auth controls', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignUpScreen()));

    expect(find.text('APPLY'), findsOneWidget);
    expect(find.text('FIRST NAME'), findsOneWidget);
    expect(find.text('EMAIL ADDRESS'), findsOneWidget);
    expect(find.text('SUBMIT APPLICATION'), findsOneWidget);
  });
}
