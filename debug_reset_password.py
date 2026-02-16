import os
import django
import sys

# Setup Django Environment
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "ffig_backend.settings")
django.setup()

from django.contrib.auth.models import User
from authentication.serializers import CustomTokenObtainPairSerializer

def test_password_reset():
    username = "debug_reset_user"
    password_initial = "InitialPass123!"
    password_reset = "ResetPass456!"

    print(f"--- Test: Creating/Resetting User {username} ---")

    # 1. Create/Get User
    try:
        user = User.objects.get(username=username)
        print("User exists, deleting...")
        user.delete()
    except User.DoesNotExist:
        pass

    user = User.objects.create_user(username=username, password=password_initial, email=f"{username}@example.com")
    print(f"1. User created. Hash starts with: {user.password[:20]}...")
    
    # 2. Check Initial Login (Simulate)
    if user.check_password(password_initial):
        print("   [OK] Initial password check passed.")
    else:
        print("   [FAIL] Initial password check failed!")

    # 3. Perform Reset Logic (Copying logic from AdminPasswordResetView)
    print("\n--- Performing Admin Reset Logic ---")
    user_to_reset = User.objects.get(id=user.id)
    user_to_reset.set_password(password_reset)
    user_to_reset.save()
    print(f"2. User saved. New Hash starts with: {user_to_reset.password[:20]}...")

    # 4. Verification
    user_refetched = User.objects.get(id=user.id)
    print(f"3. Refetched Hash starts with: {user_refetched.password[:20]}...")

    if user_refetched.check_password(password_reset):
        print("   [OK] Reset password check passed on refetched user.")
    else:
        print("   [FAIL] Reset password check FAILED on refetched user!")

    if user_refetched.check_password(password_initial):
        print("   [FAIL] Old password still works!")
    else:
        print("   [OK] Old password no longer works.")

    # 5. Serializer Login Test
    print("\n--- Testing Login Serializer with New Password ---")
    serializer = CustomTokenObtainPairSerializer(data={'username': username, 'password': password_reset})
    try:
        if serializer.is_valid():
             print("   [OK] Serializer validation passed.")
        else:
             print(f"   [FAIL] Serializer validation failed: {serializer.errors}")
    except Exception as e:
        print(f"   [FAIL] Serializer exception: {e}")

if __name__ == "__main__":
    test_password_reset()
