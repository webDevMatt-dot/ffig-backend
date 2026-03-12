import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User

# The user's name is Matthew. Let's find him.
users = User.objects.filter(first_name__icontains="Matthew")
if not users:
    print("Could not find user Matthew. Printing all users:")
    for u in User.objects.all():
        print(f"User: {u.username}, First Name: {u.first_name}, Last Name: {u.last_name}")
else:
    for u in users:
        p = getattr(u, 'profile', None)
        if p:
            print(f"User: {u.username}")
            print(f"  Bio: '{p.bio}'")
            print(f"  Business Name: '{p.business_name}'")
            print(f"  Location: '{p.location}'")
            print(f"  Industry: '{p.industry}'")
            print(f"  Photo (bool): {bool(p.photo)}")
            if p.photo:
                try:
                    print(f"  Photo path: {p.photo.name}")
                except:
                    pass
            print(f"  Photo URL: '{p.photo_url}'")
            print(f"  Missing Fields: {p.get_missing_fields()}")
            print("-" * 20)
