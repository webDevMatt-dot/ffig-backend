import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User

def inspect_users(ids):
    for uid in ids:
        try:
            u = User.objects.get(id=uid)
            print(f"ID: {uid}")
            print(f"  Username: '{u.username}' (len: {len(u.username)})")
            print(f"  Username Hex: {u.username.encode().hex()}")
            print(f"  Email: '{u.email}'")
        except User.DoesNotExist:
            print(f"ID: {uid} not found")

if __name__ == "__main__":
    inspect_users([28, 32])
