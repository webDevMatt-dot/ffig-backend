import os
import django
from datetime import timedelta
from django.utils import timezone

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User
from django.core.management import call_command

def test_reminders():
    # Get or create 3 users for testing
    users = []
    days_list = [90, 30, 7]
    
    print("--- Setup Test Data ---")
    for days in days_list:
        username = f"test_expire_{days}"
        user, created = User.objects.get_or_create(username=username, defaults={'email': f"{username}@test.com"})
        
        # Profile is auto-created by signal
        profile = user.profile
        profile.subscription_expiry = timezone.now() + timedelta(days=days)
        profile.save()
        users.append(user)
        print(f"Set {user.username} to expire in {days} days ({profile.subscription_expiry.date()}).")
        
    print("\n--- Running Management Command ---")
    call_command('send_expiration_reminders')
    
    print("\n--- Cleanup ---")
    for user in users:
        user.delete()
    print("Test users deleted.")

if __name__ == "__main__":
    test_reminders()
