import os
import django
from django.contrib.auth import get_user_model

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

User = get_user_model()
username = os.environ.get('FFIG_ADMIN_USERNAME', 'admin')
password = os.environ.get('FFIG_ADMIN_PASSWORD', 'ChangeMe123!')
email = 'admin@ffig.com'

if not User.objects.filter(username=username).exists():
    print(f"Creating superuser {username}...")
    User.objects.create_superuser(username, email, password)
    print("Superuser created.")
else:
    print(f"Superuser {username} already exists.")
