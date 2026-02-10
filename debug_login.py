import os
import django
import sys

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User
from members.serializers import ProfileSerializer
from members.models import Profile

def run():
    print("🚀 Starting Login Simulation...")
    
    # 1. Get or Create User
    username = "test_login_user"
    user, created = User.objects.get_or_create(username=username)
    if created:
        user.set_password('password123')
        user.save()
        Profile.objects.create(user=user)
        print(f"Created user: {username}")
    else:
        print(f"Using existing user: {username}")

    try:
        profile = user.profile
        print(f"Got profile: {profile}")
    except Exception as e:
        print(f"❌ Failed to get profile: {e}")
        return

    # 2. Serialize Profile
    print("Attempting to Serialize Profile...")
    try:
        serializer = ProfileSerializer(profile)
        data = serializer.data
        print("✅ Serialization Successful!")
        # print(data) 
    except Exception as e:
        print(f"❌ Serialization FAILED: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    run()
