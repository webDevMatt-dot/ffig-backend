import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User

users = User.objects.all()
for u in users:
    print(f"Trying to delete user: {u.username} (ID: {u.id})")
    try:
        # Don't actually execute the commit, but try to see if .delete() throws
        # We can use an atomic block and rollback
        from django.db import transaction
        with transaction.atomic():
            u.delete()
            print(f"SUCCESS: {u.username}")
            raise Exception("Rollback")
    except Exception as e:
        if str(e) == "Rollback":
            continue
        print(f"FAILED: {u.username} - {e}")
