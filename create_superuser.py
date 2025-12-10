import os
import django
from django.contrib.auth import get_user_model

# 1. Setup Django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "ffig_backend.settings")
django.setup()

# 2. Create Superuser
User = get_user_model()
username = "admin"
email = "admin@example.com"
password = "ChangeMe123!"  # <--- You will use this password to log in

if not User.objects.filter(username=username).exists():
    print(f"Creating superuser: {username}")
    User.objects.create_superuser(username, email, password)
    print("Superuser created successfully!")
else:
    print("Superuser already exists.")
