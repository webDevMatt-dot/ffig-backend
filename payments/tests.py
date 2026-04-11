from datetime import date
from types import SimpleNamespace
from unittest.mock import patch

from django.contrib.auth.models import User
from django.test import override_settings
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from events.models import Event, Ticket, TicketTier


@override_settings(EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend')
class PaymentsApiTests(APITestCase):
    def setUp(self):
        self.organizer = User.objects.create_user(
            username='organizer',
            email='organizer@example.com',
            password='x',
        )
        self.organizer.stripe_account.stripe_account_id = 'acct_test_123'
        self.organizer.stripe_account.payouts_enabled = True
        self.organizer.stripe_account.save()

        self.buyer = User.objects.create_user(
            username='buyer',
            email='buyer@example.com',
            password='x',
        )
        self.admin = User.objects.create_user(
            username='admin',
            email='admin@example.com',
            password='x',
            is_staff=True,
        )

        self.event = Event.objects.create(
            title='Summit',
            location='Cape Town',
            date=date(2026, 4, 10),
            organizer=self.organizer,
        )
        self.paid_tier = TicketTier.objects.create(
            event=self.event,
            name='General',
            price='25.00',
            currency='usd',
            capacity=100,
            available=100,
        )
        self.free_tier = TicketTier.objects.create(
            event=self.event,
            name='RSVP',
            price='0.00',
            currency='usd',
            capacity=20,
            available=5,
        )

    @patch('payments.views.stripe.PaymentIntent.create')
    def test_create_payment_intent_returns_client_secret_and_expected_amount(self, mock_create):
        mock_create.return_value = SimpleNamespace(client_secret='pi_client_secret_test')

        self.client.force_authenticate(user=self.buyer)
        response = self.client.post(
            reverse('create_payment_intent'),
            {
                'tier_id': self.paid_tier.id,
                'quantity': 2,
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['clientSecret'], 'pi_client_secret_test')

        call_kwargs = mock_create.call_args.kwargs
        self.assertEqual(call_kwargs['amount'], 5000)
        self.assertEqual(call_kwargs['currency'], 'usd')
        self.assertEqual(call_kwargs['metadata']['tier_id'], self.paid_tier.id)
        self.assertEqual(call_kwargs['transfer_data']['destination'], 'acct_test_123')

    @patch('payments.views.send_ticket_receipt', return_value=True)
    def test_free_registration_creates_tickets_and_decrements_availability(self, mock_receipt):
        self.client.force_authenticate(user=self.buyer)
        response = self.client.post(
            reverse('register_free_ticket'),
            {
                'tier_id': self.free_tier.id,
                'quantity': 2,
                'first_name': 'Jane',
                'last_name': 'Doe',
                'email': 'jane@example.com',
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Ticket.objects.filter(tier=self.free_tier, user=self.buyer).count(), 2)
        self.free_tier.refresh_from_db()
        self.assertEqual(self.free_tier.available, 3)
        self.assertEqual(mock_receipt.call_count, 2)

    def test_verify_ticket_requires_admin(self):
        ticket = Ticket.objects.create(
            event=self.event,
            tier=self.paid_tier,
            user=self.buyer,
            qr_code_data='TEST-QR-123',
            purchase_price='25.00',
            original_price='25.00',
        )

        self.client.force_authenticate(user=self.buyer)
        forbidden = self.client.post(
            reverse('verify_ticket'),
            {'qr_code_data': ticket.qr_code_data},
            format='json',
        )
        self.assertEqual(forbidden.status_code, status.HTTP_403_FORBIDDEN)

        self.client.force_authenticate(user=self.admin)
        allowed = self.client.post(
            reverse('verify_ticket'),
            {'qr_code_data': ticket.qr_code_data},
            format='json',
        )
        self.assertEqual(allowed.status_code, status.HTTP_200_OK)
        ticket.refresh_from_db()
        self.assertEqual(ticket.status, 'USED')
