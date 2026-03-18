import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User

try:
    u = User.objects.get(id=17)
    print(f"Trying to delete user: {u.username} (ID: {u.id})")
    u.delete()
    print("SUCCESS")
except Exception as e:
    import traceback
    traceback.print_exc()
