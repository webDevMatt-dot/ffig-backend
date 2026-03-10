import os
import django
from collections import Counter

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User

def check_duplicates():
    all_users = User.objects.all()
    usernames = [u.username.lower().strip() for u in all_users]
    counts = Counter(usernames)
    
    duplicates = [name for name, count in counts.items() if count > 1]
    
    if duplicates:
        print("Found potentially conflicting usernames (case-insensitive and trimmed):")
        for name in duplicates:
            matches = User.objects.filter(username__icontains=name)
            print(f"\nConflict Group: '{name}'")
            for m in matches:
                print(f"  - ID: {m.id}, Username: '{m.username}', Email: {m.email}")
    else:
        print("No duplicate usernames found (case-insensitive and trimmed).")

if __name__ == "__main__":
    check_duplicates()
