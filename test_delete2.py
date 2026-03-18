import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User
from django.db import transaction

print("Testing user deletion for all users...")
users = User.objects.all()
failed_users = []

for u in users:
    try:
        with transaction.atomic():
            u.delete()
            # If successful, immediately rollback to prevent actual deletion
            raise Exception("ForceRollback")
    except Exception as e:
        if str(e) == "ForceRollback":
            continue
        print(f"FAILED to delete '{u.username}' (ID: {u.id}): {type(e).__name__} - {e}")
        failed_users.append(u.username)

if failed_users:
    print(f"\nFailed to delete {len(failed_users)} users: {', '.join(failed_users)}")
else:
    print("\nAll users can be deleted successfully at the ORM level.")
