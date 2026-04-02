import os
import django
import sys
from datetime import timedelta
from django.utils import timezone

# Setup Django Environment
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User
from core.services.email_service import send_welcome_email

def fulfill_missed_welcomes():
    # Find users who joined in the last 48 hours
    start_time = timezone.now() - timedelta(days=2)
    new_users = User.objects.filter(date_joined__gte=start_time)
    
    print(f"🔍 Found {new_users.count()} users who joined since {start_time}")
    
    for user in new_users:
        print(f"✉️ Attempting to send welcome email to {user.username} ({user.email})...")
        success = send_welcome_email(user)
        if success:
            print(f"✅ Success!")
        else:
            print(f"❌ Failed.")

if __name__ == "__main__":
    fulfill_missed_welcomes()
