import os
import django
from django.conf import settings
from django.contrib.auth import get_user_model

# Setup Django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "ffig_backend.settings")
django.setup()

User = get_user_model()
email = "mgluis530@gmail.com"

print(f"--- Manual Welcome Email Sender ---")
print(f"Target Email: {email}")

try:
    user = User.objects.get(email__iexact=email)
    print(f"Found User: {user.username} (ID: {user.id})")
    
    from core.services.email_service import send_welcome_email
    success = send_welcome_email(user)
    
    if success:
        print(f"✅ Welcome email successfully sent to {email}")
    else:
        print(f"❌ Failed to send welcome email to {email}")
except User.DoesNotExist:
    print(f"❌ Error: No user found with email {email}")
except Exception as e:
    print(f"❌ An error occurred: {e}")

print("\nDone.")
