import os
import django
from datetime import timedelta
from django.utils import timezone
from django.test import Client

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User

def test_blocking():
    client = Client()

    # Setup an expired user
    username = "test_expired_user"
    user, created = User.objects.get_or_create(username=username, defaults={'email': f"{username}@test.com"})
    
    # ensure dummy user has a password for token generation
    user.set_password("testpass123")
    user.save()

    profile = user.profile
    profile.subscription_expiry = timezone.now() - timedelta(days=5) # Expired 5 days ago
    profile.save()
    
    # Get a JWT token
    login_response = client.post('/api/auth/login/', {'username': username, 'password': 'testpass123'})
    
    print(f"Login Status: {login_response.status_code}") # Should be 200
    if login_response.status_code != 200:
        print(f"Login failed: {login_response.json()}")
        user.delete()
        return
        
    token = login_response.json().get('access')
    headers = {"HTTP_AUTHORIZATION": f"Bearer {token}"}
    
    print("\n--- Testing Allowed Endpoints ---")
    res = client.get('/api/members/me/', **headers)
    print(f"Fetch Profile (Allowed) Status: {res.status_code}")
    
    # Depending on what the endpoint expects, it might be 400 or 405, but it shouldn't be the 403 membership_expired response
    res = client.post('/api/payments/verify-subscription/', **headers)
    print(f"Payments (Allowed) Status: {res.status_code}")

    print("\n--- Testing Blocked Endpoints ---")
    res = client.get('/api/events/', **headers)
    print(f"Events Status: {res.status_code}")
    if res.status_code == 403:
        print(f"Events Response: {res.json()}")

    # Cleanup
    print("\n--- Cleanup ---")
    user.delete()

if __name__ == "__main__":
    test_blocking()
