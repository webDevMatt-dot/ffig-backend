import os
import django
from collections import Counter

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User

def check_duplicate_emails():
    all_users = User.objects.all()
    emails = [u.email.lower().strip() for u in all_users if u.email]
    counts = Counter(emails)
    
    duplicates = [email for email, count in counts.items() if count > 1]
    
    if duplicates:
        print("Found duplicate emails (case-insensitive and trimmed):")
        for email in duplicates:
            matches = User.objects.filter(email__iexact=email)
            print(f"\nConflict Group: '{email}'")
            for m in matches:
                print(f"  - ID: {m.id}, Username: '{m.username}'")
    else:
        print("No duplicate emails found (case-insensitive and trimmed).")

if __name__ == "__main__":
    check_duplicate_emails()
