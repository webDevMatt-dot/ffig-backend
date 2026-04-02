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

print("--- Testing Registration OTP Flow ---")

# 1. Register a user
email = "otp_test_new@example.com"
username = "otp_test_user_new"

# Delete if exists
User.objects.filter(username=username).delete()

print(f"Registering user {username}...")
response = client.post('/api/auth/register/', {
    'username': username,
    'email': email,
    'first_name': 'OTP',
    'last_name': 'Test',
    'password': 'Password123!',
    'password2': 'Password123!',
    'industry': 'TECH',
    'location': 'United States'
}, format='json')

print(f"Response Status: {response.status_code}")

# 2. Check user status
user = User.objects.get(username=username)
print(f"User is_active: {user.is_active} (Expected: False)")

# 3. Check OTP record
from authentication.models import SignupOTP
otp_record = SignupOTP.objects.filter(email=email).latest('created_at')
print(f"OTP Record created. Expires: {otp_record.expires_at}")

# 4. Try login (should fail)
print("\nAttempting login with inactive user...")
login_response = client.post('/api/auth/login/', {
    'username': username,
    'password': 'Password123!'
}, format='json')
print(f"Login Response: {login_response.status_code} (Expected: 401)")

# 5. Verify OTP
# Since we can't easily get the plain text OTP from the hashed value in the DB without mocking,
# let's just cheat and check the hashing manually or mock the check_password.
# In the test, we can just manually set is_active=True after confirming the record exists.
# BUT let's try a real verification by getting the actual OTP from the send_mail call? 
# Testing with a real OTP is hard in automated script without mocking send_mail.
# Let's mock check_password for our test or just use the model directly to test 'Verify' view.

print("\nVerifying OTP via view...")
# We need the real otp. Let's create one we know.
from django.contrib.auth.hashers import make_password
known_otp = "123456"
otp_record.otp_hash = make_password(known_otp)
otp_record.save()

verify_response = client.post('/api/auth/register/verify-otp/', {
    'email': email,
    'otp': known_otp
}, format='json')

print(f"Verify Response: {verify_response.status_code}")
user.refresh_from_db()
print(f"User is_active after verify: {user.is_active} (Expected: True)")

# 6. Try login again (should succeed)
print("\nAttempting login with active user...")
login_response = client.post('/api/auth/login/', {
    'username': username,
    'password': 'Password123!'
}, format='json')
print(f"Login Response: {login_response.status_code} (Expected: 200)")

# Cleanup
user.delete()
print("\nCleanup done.")
