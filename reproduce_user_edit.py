import os
import django
from rest_framework.exceptions import ValidationError

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User
from authentication.serializers import UserSerializer

def test_serializer_update():
    print("--- Testing UserSerializer Update Validation ---")
    
    # 1. Create a dummy user
    username = "test_edit_user"
    email = "test_edit@example.com"
    if User.objects.filter(username=username).exists():
        user = User.objects.get(username=username)
        print(f"Using existing user: {user.username} (ID: {user.id})")
    else:
        user = User.objects.create_user(username=username, email=email, password="password123")
        print(f"Created user: {user.username} (ID: {user.id})")

    # 2. Try to update self with SAME username
    print("\n[Test 1] Updating self with SAME username...")
    data = {'username': username, 'email': email, 'first_name': 'Changed'}
    serializer = UserSerializer(instance=user, data=data, partial=True)
    if serializer.is_valid():
        print("PASS: Validation successful for self-update.")
    else:
        print(f"FAIL: Validation failed: {serializer.errors}")

    # 3. Try to update self with CASE-INSENSITIVE same username
    print("\n[Test 2] Updating self with Uppercase username...")
    data = {'username': username.upper(), 'email': email}
    serializer = UserSerializer(instance=user, data=data, partial=True)
    if serializer.is_valid():
        print("PASS: Validation successful for case-insensitive self-update.")
    else:
        print(f"FAIL: Validation failed: {serializer.errors}")

    # 4. Create another user
    other_username = "test_other_user"
    if not User.objects.filter(username=other_username).exists():
        User.objects.create_user(username=other_username, email="other@example.com", password="password")
    
    # 5. Try to update first user to second user's name
    print("\n[Test 3] Updating User 1 to User 2's username (Should Fail)...")
    data = {'username': 'Test_Other_User', 'email': email} # Mixed case check
    serializer = UserSerializer(instance=user, data=data, partial=True)
    if serializer.is_valid():
        print("FAIL: Validation SUCCEEDED but should have failed!")
    else:
        print(f"PASS: Validation failed as expected: {serializer.errors}")

    # 6. Check for duplicates in DB
    print("\n--- Checking for Duplicates in DB ---")
    all_users = User.objects.all()
    seen = {}
    duplicates = []
    for u in all_users:
        u_lower = u.username.lower()
        if u_lower in seen:
            duplicates.append((u.username, seen[u_lower]))
        seen[u_lower] = u.username
    
    if duplicates:
        print("WARNING: Found potential case-insensitive duplicates:")
        for dup in duplicates:
            print(f" - {dup}")
    else:
        print("No case-insensitive duplicates found.")

    # Clean up
    # user.delete()
    # User.objects.filter(username=other_username).delete()

if __name__ == "__main__":
    test_serializer_update()
