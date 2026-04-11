import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/events/ticket_flow/checkout_screen.dart';

void main() {
  testWidgets('paid checkout shows computed payment CTA', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CheckoutScreen(
          event: const {'title': 'Summit 2026'},
          tier: const {
            'id': 10,
            'name': 'General Admission',
            'price': '25.00',
            'currency': 'usd',
          },
          quantity: 2,
        ),
      ),
    );

    expect(find.text('Order Summary'), findsOneWidget);
    expect(find.text('PAY USD 50.00'), findsOneWidget);
  });

  testWidgets('free checkout shows free registration CTA', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CheckoutScreen(
          event: const {'title': 'Summit 2026'},
          tier: const {
            'id': 11,
            'name': 'RSVP',
            'price': '0.00',
            'currency': 'usd',
          },
        ),
      ),
    );

    expect(find.text('Get Free Ticket'), findsOneWidget);
  });
}
