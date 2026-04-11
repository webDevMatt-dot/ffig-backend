import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/chat/inbox_screen.dart';

void main() {
  testWidgets('mini profile card renders profile CTA clearly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MiniProfileCard(
            displayName: 'Bresly Heart',
            firstName: 'Bresly',
            lastName: 'Heart',
            bio: 'Founder and builder.',
            tier: 'PREMIUM',
            onViewProfile: () {},
          ),
        ),
      ),
    );

    expect(find.text('Bresly Heart'), findsOneWidget);
    expect(find.text('View Full Profile'), findsOneWidget);
  });
}
