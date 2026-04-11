from unittest.mock import patch

from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import override_settings
from django.urls import reverse
from django.utils import timezone
from datetime import timedelta
from rest_framework import status
from rest_framework.test import APITestCase

from .models import Conversation, Message


@override_settings(EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend')
class ChatApiTests(APITestCase):
    def setUp(self):
        self.sender = User.objects.create_user(
            username='sender',
            email='sender@example.com',
            password='x',
        )
        self.recipient = User.objects.create_user(
            username='recipient',
            email='recipient@example.com',
            password='x',
        )

    def test_unread_count_excludes_current_user_messages(self):
        conversation = Conversation.objects.create()
        conversation.participants.add(self.sender, self.recipient)

        Message.objects.create(
            conversation=conversation,
            sender=self.recipient,
            text='Incoming 1',
            is_read=False,
        )
        Message.objects.create(
            conversation=conversation,
            sender=self.recipient,
            text='Incoming 2',
            is_read=False,
        )
        Message.objects.create(
            conversation=conversation,
            sender=self.sender,
            text='Outgoing message',
            is_read=False,
        )
        Message.objects.create(
            conversation=conversation,
            sender=self.recipient,
            text='Already read',
            is_read=True,
        )

        self.client.force_authenticate(user=self.sender)
        response = self.client.get(reverse('unread-count'))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['unread_count'], 2)

    @patch('core.services.fcm_service.send_push_notification', return_value=True)
    def test_send_message_creates_conversation_and_message(self, _mock_push):
        self.client.force_authenticate(user=self.sender)

        response = self.client.post(
            reverse('send-message'),
            {
                'recipient_id': self.recipient.id,
                'text': 'Hello from API test',
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

        conversation = (
            Conversation.objects.filter(participants=self.sender)
            .filter(participants=self.recipient)
            .first()
        )
        self.assertIsNotNone(conversation)
        self.assertEqual(conversation.messages.count(), 1)
        self.assertEqual(conversation.messages.first().text, 'Hello from API test')

    @patch('core.services.fcm_service.send_push_notification', return_value=True)
    def test_send_document_attachment_uses_document_type(self, _mock_push):
        self.client.force_authenticate(user=self.sender)
        attachment = SimpleUploadedFile(
            'pitch-deck.pdf',
            b'%PDF-1.4 mock',
            content_type='application/pdf',
        )

        response = self.client.post(
            reverse('send-message'),
            {
                'recipient_id': self.recipient.id,
                'message_type': 'document',
                'text': 'Please review this deck',
                'attachment': attachment,
            },
            format='multipart',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        message = Message.objects.order_by('-id').first()
        self.assertIsNotNone(message)
        self.assertEqual(message.message_type, 'document')
        self.assertTrue(bool(message.attachment))

    def test_sender_can_delete_message_within_window(self):
        conversation = Conversation.objects.create()
        conversation.participants.add(self.sender, self.recipient)
        message = Message.objects.create(
            conversation=conversation,
            sender=self.sender,
            text='Delete me quickly',
        )

        self.client.force_authenticate(user=self.sender)
        response = self.client.delete(
            reverse('delete-message', kwargs={'pk': message.id}),
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertFalse(Message.objects.filter(id=message.id).exists())

    def test_sender_cannot_delete_after_window_expires(self):
        conversation = Conversation.objects.create()
        conversation.participants.add(self.sender, self.recipient)
        message = Message.objects.create(
            conversation=conversation,
            sender=self.sender,
            text='Too old to delete',
        )
        Message.objects.filter(id=message.id).update(
            created_at=timezone.now() - timedelta(minutes=16),
        )

        self.client.force_authenticate(user=self.sender)
        response = self.client.delete(
            reverse('delete-message', kwargs={'pk': message.id}),
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertTrue(Message.objects.filter(id=message.id).exists())

    def test_non_sender_cannot_delete_message(self):
        conversation = Conversation.objects.create()
        conversation.participants.add(self.sender, self.recipient)
        message = Message.objects.create(
            conversation=conversation,
            sender=self.sender,
            text='Only sender can remove',
        )

        self.client.force_authenticate(user=self.recipient)
        response = self.client.delete(
            reverse('delete-message', kwargs={'pk': message.id}),
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertTrue(Message.objects.filter(id=message.id).exists())
