import os
import django
from django.utils import timezone
from datetime import timedelta

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from authentication.models import PasswordResetOTP

print("Checking recent OTP records...")
recent_otps = PasswordResetOTP.objects.order_by('-created_at')[:5]

for otp in recent_otps:
    print(f"[{otp.created_at}] Email: {otp.email}, Used: {otp.is_used}")
