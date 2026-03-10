import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User
from members.models import Profile

def cleanup():
    # 1. Rename Tester2 to avoid conflict with tester2
    try:
        tester2_upper = User.objects.get(username='Tester2')
        tester2_upper.username = 'Tester2_old'
        tester2_upper.save()
        print(f"Renamed Tester2 (ID: {tester2_upper.id}) to Tester2_old")
    except User.DoesNotExist:
        print("Tester2 not found, skipping rename.")

    # 2. Create missing profile for 'user'
    try:
        user_obj = User.objects.get(username='user')
        if not hasattr(user_obj, 'profile'):
            Profile.objects.create(user=user_obj)
            print(f"Created profile for 'user' (ID: {user_obj.id})")
        else:
            print(f"'user' already has a profile.")
    except User.DoesNotExist:
        print("'user' not found, skipping profile creation.")

if __name__ == "__main__":
    cleanup()
