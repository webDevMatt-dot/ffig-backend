import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User

users = User.objects.all()
if not users:
    print("NO USERS FOUND locally.")
for u in users:
    try:
        p = u.profile
        print(f"User: {u.username}")
        print(f"  Bio: '{p.bio}'")
        print(f"  Business Name: '{p.business_name}'")
        print(f"  Location: '{p.location}'")
        print(f"  Industry: '{p.industry}'")
        print(f"  Photo (bool): {bool(p.photo)}")
        print(f"  Photo URL: '{p.photo_url}'")
        print(f"  Missing Fields: {p.get_missing_fields()}")
        print("-" * 20)
    except Exception as e:
        pass
