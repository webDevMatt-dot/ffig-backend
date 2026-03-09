import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User

username = "President"
email = "president@ffig.com"
password = "RestoredUser123!"

if not User.objects.filter(username=username).exists():
    user = User.objects.create_user(username=username, email=email, password=password)
    print(f"User '{username}' created successfully.")
else:
    print(f"User '{username}' already exists.")
