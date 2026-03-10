import os
import django
import json

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User
from authentication.serializers import UserSerializer

def test_update(username):
    try:
        user = User.objects.get(username=username)
        print(f"Testing update for user: {user.username} (ID: {user.id}, Email: {user.email})")
        
        # Simulate what the Flutter app sends
        data = {
           'username': user.username,
           'email': user.email,
           'first_name': user.first_name,
           'last_name': user.last_name,
           'is_staff': user.is_staff,
           'profile': {'tier': 'PREMIUM'}
        }
        
        serializer = UserSerializer(instance=user, data=data, partial=True)
        if serializer.is_valid():
            print("Serializer is valid!")
            serializer.save()
            print("Successfully saved!")
        else:
            print(f"Serializer errors: {serializer.errors}")
            
    except Exception as e:
        print(f"Error: {e}")

def test_conflict(username, target_username):
    try:
        user = User.objects.get(username=username)
        print(f"Testing conflict for user: {user.username} (ID: {user.id}) -> {target_username}")
        
        data = {
           'username': target_username,
           'email': user.email,
           'profile': {'tier': 'PREMIUM'}
        }
        
        serializer = UserSerializer(instance=user, data=data, partial=True)
        if serializer.is_valid():
            print("Serializer is valid! (Unexpected if conflict exists)")
        else:
            print(f"Serializer errors: {serializer.errors}")
            
    except Exception as e:
        print(f"Error: {e}")

def test_all_users():
    users = User.objects.all()
    print(f"Testing updates for {users.count()} users...")
    errors = []
    missing_profiles = []
    for user in users:
        has_profile = hasattr(user, 'profile')
        if not has_profile:
            missing_profiles.append(user.username)
            continue
            
        data = {
           'username': user.username,
           'email': user.email,
           'profile': {'tier': 'PREMIUM' if user.profile.tier == 'PREMIUM' else 'STANDARD'}
        }
        
        serializer = UserSerializer(instance=user, data=data, partial=True)
        if not serializer.is_valid():
            errors.append((user.username, serializer.errors))
    
    if missing_profiles:
        print(f"\nUsers missing profiles: {missing_profiles}")
        
    if errors:
        print("\nFound users that fail validation even without changes:")
        for name, err in errors:
            print(f"  - {name}: {err}")
    else:
        print("\nAll users with profiles passed validation for self-update.")

if __name__ == "__main__":
    test_all_users()
