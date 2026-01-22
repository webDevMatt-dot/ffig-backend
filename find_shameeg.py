
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User

def find_users():
    users = User.objects.filter(username__icontains='Sham')
    print("Users matching 'Sham':")
    for u in users:
        print(f"- {u.username} (Email: {u.email})")

    users_email = User.objects.filter(email__icontains='shameeg')
    print("\nUsers with email matching 'shameeg':")
    for u in users_email:
        print(f"- {u.username} (Email: {u.email})")

if __name__ == "__main__":
    find_users()
