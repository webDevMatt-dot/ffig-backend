import os
import django
import json

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User
from core.services.fcm_service import send_push_notification

def verify_fcm():
    print("🔍 Checking FCM Setup...")
    
    # 1. Check Credentials
    import firebase_admin
    if not firebase_admin._apps:
        print("❌ Firebase App NOT initialized automatically.")
    else:
        print("✅ Firebase App initialized.")

    # 2. Check Users with Tokens
    users_with_tokens = User.objects.filter(profile__fcm_token__isnull=False).exclude(profile__fcm_token='')
    count = users_with_tokens.count()
    print(f"📊 Found {count} users with FCM tokens.")
    
    if count == 0:
        print("⚠️ No users have FCM tokens. The mobile app needs to sync the token first.")
        return

    # 3. Send Test Notification to the latest user (likely the one testing)
    target_user = users_with_tokens.last()
    print(f"🚀 Attempting to send test notification to: {target_user.username}")
    print(f"   Token: {target_user.profile.fcm_token[:20]}...")

    success = send_push_notification(
        target_user, 
        "Test Notification", 
        "This is a test from the verification script.",
        data={"type": "TEST"}
    )
    
    if success:
        print("✅ calling send_push_notification returned True (Message sent to FCM).")
        print("   If it doesn't appear on the phone, checks:")
        print("   1. Is the app in background? (Foreground needs local handling)")
        print("   2. Are system notifications enabled for the app?")
        print("   3. Is the method in fcm_service.py using the correct credential?")
    else:
        print("❌ calling send_push_notification returned False.")

if __name__ == "__main__":
    verify_fcm()
