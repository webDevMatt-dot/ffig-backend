import os
import django
from rest_framework.test import APIRequestFactory

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User
from authentication.serializers import UserSerializer
from authentication.views import AdminUserDetailView

def reproduce():
    # 1. Create a dummy user
    username = "test_update_user"
    email = "test_update@example.com"
    try:
        user = User.objects.get(username=username)
        user.delete()
        print("Deleted existing test user")
    except User.DoesNotExist:
        pass
    
    user = User.objects.create_user(username=username, email=email, password="password123")
    print(f"Created user: {user.username} (ID: {user.id})")

    # 2. Prepare update data (simulating what the frontend might send)
    # Scenario A: Sending same username, updating tier
    data = {
        "username": username,
        "email": email,
        "first_name": "Test",
        "last_name": "Update",
        "profile": {
            "tier": "PREMIUM"
        }
    }

    print("\n--- Attempting Update with SAME username ---")
    serializer = UserSerializer(instance=user, data=data)
    if serializer.is_valid():
        serializer.save()
        print("✅ Update Successful!")
        print(f"New Tier: {user.profile.tier}")
        print(f"Is Premium: {user.profile.is_premium}")
    else:
        print("❌ Update Failed!")
        print(serializer.errors)

    # Scenario B: Case sensitivity check (if applicable)
    # different casing but same letters
    data_diff_case = data.copy()
    data_diff_case['username'] = username.upper()
    
    print(f"\n--- Attempting Update with UPPERCASE username ({username.upper()}) ---")
    serializer = UserSerializer(instance=user, data=data_diff_case)
    if serializer.is_valid():
        print("✅ Update (Case Change) Valid (Note: this might check availability)")
        # We don't save here to avoid changing it yet
    else:
        print("❌ Update (Case Change) Failed!")
        print(serializer.errors)

if __name__ == "__main__":
    reproduce()
