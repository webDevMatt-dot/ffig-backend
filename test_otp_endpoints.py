import os
import django
from django.conf import settings
from rest_framework.test import APIClient
from django.contrib.auth import get_user_model

# Setup Django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "ffig_backend.settings")
django.setup()

User = get_user_model()
client = APIClient()

print("Creating test user...")
user, created = User.objects.get_or_create(username="otp_test_user", email="test@femalefoundersinitiative.com")
user.set_password("old_password_123!")
user.save()

print("\n--- Testing Request OTP ---")
response = client.post('/api/auth/password/reset/request-otp/', {
    'email': 'test@femalefoundersinitiative.com',
    'sender_email': 'test@example.com'
}, format='json')

print(f"Status: {response.status_code}")
print(f"Data: {response.data}")

print("\n--- Verifying OTP created in DB ---")
from authentication.models import PasswordResetOTP
otp_record = PasswordResetOTP.objects.filter(email='test@femalefoundersinitiative.com').latest('created_at')
print(f"Found OTP record for {otp_record.email}. Valid: {otp_record.is_valid()}")

# To actually find the plain text OTP, we can't (it's hashed), so let's mock the check_password for our test OR create a known one.
print("\n--- Testing Confirm OTP (with invalid OTP to ensure it fails securely) ---")
response = client.post('/api/auth/password/reset/confirm-otp/', {
    'email': 'test@femalefoundersinitiative.com',
    'otp': '123456', # This will be wrong since the real one is random
    'new_password': 'NewPassword123!'
}, format='json')

print(f"Status: {response.status_code}")
print(f"Data: {response.data}")

print("\n--- Cleaning up ---")
user.delete()
print("Done.")

