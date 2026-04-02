import os
import django
from django.utils import timezone
import datetime

# Setup Django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "ffig_backend.settings")
django.setup()

from django.contrib.auth import get_user_model
from core.services.fcm_service import send_push_notification

User = get_user_model()

def send_all_direct():
    # 1. Target specifically 'admin' or the latest active staff
    admin = User.objects.filter(is_staff=True).order_by('-id').first()
    
    if not admin:
        print("❌ Error: No admin user found.")
        return

    print(f"🚀 Sending 11 Direct Tests to: {admin.username} ({admin.email})")
    
    if not hasattr(admin, 'profile') or not admin.profile.fcm_token:
        print(f"❌ Error: User {admin.username} has no FCM token. Push cannot be delivered.")
        return

    # --- LIST OF ALL 11 NOTIFICATIONS (DIRECT TO ADMIN) ---
    
    notifications = [
        ("New User Verified", f"Registration: {admin.username} has joined FFIG.", {"type": "admin_alert"}),
        ("New Ticket Purchase", f"Payment: 1 VIP ticket confirmed for {admin.username}.", {"type": "admin_purchase_alert"}),
        ("Message from Support", f"Direct Chat: This is a test private message.", {"type": "chat_message"}),
        ("Business Pending", f"Admin: FFIG Enterprises is pending approval.", {"type": "admin_business_alert"}),
        ("New Featured Post", "Global: Check out the latest community updates!", {"type": "new_post"}),
        ("New Story", f"Stories: {admin.username} shared a new moment.", {"type": "new_story"}),
        ("New Resource Uploaded", "Resources: The Masterclass video is live.", {"type": "new_resource"}),
        ("Announcement", "Alert: Tickets for the Gala Night are closing!", {"type": "flash_alert"}),
        ("Founder of the Week! 🌟", "Meet Sarah, our featured founder of the week.", {"type": "founder_spotlight"}),
        ("Business of the Month! 🏆", "Vibe Studios is our business of the month.", {"type": "business_spotlight"}),
        ("Community Chat", f"Community: [User] Test message in the lounge.", {"type": "community_chat"})
    ]

    for i, (title, body, data) in enumerate(notifications, 1):
        print(f"Sending ({i}/11): {title}")
        send_push_notification(admin, title, body, data=data)
    
    print("\n✅ All 11 notifications sent directly to your device. Check your tray!")

if __name__ == "__main__":
    send_all_direct()
