import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User

# Look for users with 'president' in username or email
users = User.objects.filter(username__icontains='president') | User.objects.filter(email__icontains='president')

if users.exists():
    for user in users:
        print(f"Found user: {user.username} ({user.email})")
        user.is_staff = True
        user.is_superuser = True
        user.save()
        print(f"Successfully granted admin rights to {user.username}!")
else:
    print("Could not find any user with 'president' in their username or email.")
