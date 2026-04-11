import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/admin/admin_dashboard_screen.dart';

void main() {
  testWidgets('admin dashboard renders management entry points', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AdminDashboardScreen()));
    await tester.pump();

    expect(find.text('ADMIN DASHBOARD'), findsOneWidget);
    expect(find.text('Flash Alerts'), findsOneWidget);
    expect(find.text('Manage Events'), findsOneWidget);
  });
}
