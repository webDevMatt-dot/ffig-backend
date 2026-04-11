from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APIRequestFactory

from .models import Event
from .serializers import EventSerializer


class EventSharePreviewTests(TestCase):
    def setUp(self):
        self.event = Event.objects.create(
            title='Founders Dinner',
            location='Johannesburg',
            date='2026-05-10',
            description='Meet and connect with founders and investors.',
            image_url='https://example.com/event.jpg',
            is_active=True,
        )

    def test_share_preview_page_contains_og_tags(self):
        response = self.client.get(
            reverse(
                'event-share-preview-pretty',
                kwargs={'pk': self.event.id, 'event_slug': 'founders-dinner'},
            )
        )
        body = response.content.decode('utf-8')

        self.assertEqual(response.status_code, 200)
        self.assertIn('property="og:title"', body)
        self.assertIn('property="og:description"', body)
        self.assertIn('property="og:image"', body)
        self.assertIn(self.event.title, body)
        self.assertIn(f'/share/events/{self.event.id}/founders-dinner/', body)

    def test_event_serializer_exposes_share_url(self):
        request = APIRequestFactory().get('/api/events/')
        serializer = EventSerializer(self.event, context={'request': request})

        self.assertIn('share_url', serializer.data)
        self.assertTrue(
            serializer.data['share_url'].endswith(
                f'/share/events/{self.event.id}/founders-dinner/',
            )
        )

    def test_share_preview_works_for_inactive_event(self):
        inactive_event = Event.objects.create(
            title='Legacy Event',
            location='Cape Town',
            date='2026-04-01',
            description='Previously published event.',
            image_url='https://example.com/legacy.jpg',
            is_active=False,
        )

        response = self.client.get(
            reverse('event-share-preview', kwargs={'pk': inactive_event.id})
        )
        self.assertEqual(response.status_code, 200)

    def test_old_plain_share_url_still_works(self):
        response = self.client.get(
            reverse('event-share-preview', kwargs={'pk': self.event.id})
        )
        self.assertEqual(response.status_code, 200)
