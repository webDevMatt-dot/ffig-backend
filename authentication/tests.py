from django.contrib.auth.models import User
from django.test import RequestFactory, TestCase

from .serializers import UserSerializer


class UserSerializerValidationTests(TestCase):
    def setUp(self):
        self.factory = RequestFactory()
        self.user = User.objects.create_user(
            username='FounderOne',
            email='founder1@example.com',
            password='x',
        )
        self.other = User.objects.create_user(
            username='FounderTwo',
            email='founder2@example.com',
            password='x',
        )

    def test_allows_same_username_when_editing_user_even_without_instance(self):
        request = self.factory.patch('/api/admin/users/1/')
        request.parser_context = {'kwargs': {'pk': self.user.pk}}

        serializer = UserSerializer(
            data={'username': 'FounderOne'},
            context={'request': request},
            partial=True,
        )

        self.assertTrue(serializer.is_valid(), serializer.errors)

    def test_rejects_conflicting_username_for_another_user(self):
        serializer = UserSerializer(
            instance=self.user,
            data={'username': 'FounderTwo'},
            partial=True,
        )

        self.assertFalse(serializer.is_valid())
        self.assertIn('username', serializer.errors)

    def test_allows_same_email_when_editing_user_even_without_instance(self):
        request = self.factory.patch('/api/admin/users/1/')
        request.parser_context = {'kwargs': {'pk': self.user.pk}}

        serializer = UserSerializer(
            data={'email': 'founder1@example.com'},
            context={'request': request},
            partial=True,
        )

        self.assertTrue(serializer.is_valid(), serializer.errors)

    def test_rejects_conflicting_email_for_another_user(self):
        serializer = UserSerializer(
            instance=self.user,
            data={'email': 'founder2@example.com'},
            partial=True,
        )

        self.assertFalse(serializer.is_valid())
        self.assertIn('email', serializer.errors)
