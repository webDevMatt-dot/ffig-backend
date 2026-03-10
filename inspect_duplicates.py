import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User

users_to_check = ['Rosheen', 'President', 'matt_luis', 'Tester2_old']

for username in users_to_check:
    u = User.objects.filter(username=username).first()
    if u:
        print(f"User: {u.username}")
        print(f"  ID: {u.id}")
        print(f"  Email: {u.email}")
        print(f"  Date Joined: {u.date_joined}")
        print(f"  Last Login: {u.last_login}")
        try:
            print(f"  Tier: {u.profile.tier}")
            print(f"  Bio: {'Exists' if u.profile.bio else 'Empty'}")
        except:
            print(f"  Profile: Missing")
        print("-" * 20)
    else:
        print(f"User: {username} not found")
