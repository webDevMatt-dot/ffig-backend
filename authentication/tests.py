from django.contrib.auth.models import User
from django.test import RequestFactory, TestCase, override_settings
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from .serializers import UserSerializer


@override_settings(EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend')
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


@override_settings(EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend')
class AuthenticationApiTests(APITestCase):
    def setUp(self):
        self.password = 'SecurePass123!'
        self.user = User.objects.create_user(
            username='FounderCase',
            email='FounderCase@example.com',
            password=self.password,
            is_staff=True,
        )

    def test_login_accepts_email_case_insensitively_and_returns_tokens(self):
        response = self.client.post(
            reverse('token_obtain_pair'),
            {
                'username': 'FOUNDERCASE@EXAMPLE.COM',
                'password': self.password,
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.data)
        self.assertIn('refresh', response.data)
        self.assertEqual(response.data['user_id'], self.user.id)
        self.assertTrue(response.data['is_staff'])

    def test_login_rejects_invalid_credentials(self):
        response = self.client.post(
            reverse('token_obtain_pair'),
            {
                'username': 'foundercase@example.com',
                'password': 'wrong-password',
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
        self.assertNotIn('access', response.data)


@override_settings(EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend')
class AdminUserEndpointPermissionTests(APITestCase):
    def setUp(self):
        self.admin = User.objects.create_user(
            username='adminuser',
            email='admin@example.com',
            password='x',
            is_staff=True,
        )
        self.member = User.objects.create_user(
            username='memberuser',
            email='member@example.com',
            password='x',
        )

    def test_non_admin_cannot_list_users(self):
        self.client.force_authenticate(user=self.member)
        response = self.client.get(reverse('admin_user_list'))
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_admin_can_list_users(self):
        self.client.force_authenticate(user=self.admin)
        response = self.client.get(reverse('admin_user_list'))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        returned_ids = {item['id'] for item in response.data}
        self.assertIn(self.admin.id, returned_ids)
        self.assertIn(self.member.id, returned_ids)
