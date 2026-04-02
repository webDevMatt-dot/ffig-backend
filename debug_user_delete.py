import os
import django
from django.conf import settings
from django.contrib.auth import get_user_model

# Setup Django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "ffig_backend.settings")
django.setup()

User = get_user_model()

print("--- Testing User Deletion ---")

# 1. Create a temporary user
username = "temp_delete_user"
email = "temp_delete@example.com"
User.objects.filter(username=username).delete()

user = User.objects.create_user(username=username, email=email, password="Password123!")
print(f"Created user: {user.username} (ID: {user.id})")

# 2. Try to delete
try:
    print(f"Attempting to delete user {user.id}...")
    user.delete()
    print("Successfully deleted user!")
except Exception as e:
    import traceback
    print(f"FAILED to delete user: {e}")
    traceback.print_exc()

print("\nDone.")
