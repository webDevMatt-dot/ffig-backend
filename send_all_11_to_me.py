import os
import django

# Setup Django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "ffig_backend.settings")
django.setup()

from django.contrib.auth import get_user_model
from core.services.fcm_service import send_push_notification

User = get_user_model()

def send_all_direct_to_admin():
    # Find the 'admin' user specifically
    admin = User.objects.filter(username__iexact='admin').first()
    
    if not admin:
        # Fallback: Find the latest staff user that IS NOT Rosheen
        admin = User.objects.filter(is_staff=True).exclude(username__icontains='President').exclude(email__icontains='rosheen').order_by('-id').first()
    
    if not admin:
        print("❌ Error: No non-Rosheen admin user found.")
        return

    print(f"🚀 Sending 11 Direct Tests to: {admin.username} ({admin.email})")
    
    if not hasattr(admin, 'profile') or not admin.profile.fcm_token:
        print(f"❌ Error: User {admin.username} has no FCM token in their profile. Log out and log back in to refresh it.")
        return

    notifications = [
        ("New User Verified", f"Registration: A new user has joined FFIG.", {"type": "admin_alert"}),
        ("New Ticket Purchase", f"Payment: A VIP ticket has been purchased.", {"type": "admin_purchase_alert"}),
        ("Message from FFIG", f"Direct Chat: You have a new message.", {"type": "chat_message"}),
        ("Business Pending", f"Admin: A new business is pending approval.", {"type": "admin_business_alert"}),
        ("New Featured Post", "Global: Check out the latest updates!", {"type": "new_post"}),
        ("New Story", f"Stories: A new story has been shared.", {"type": "new_story"}),
        ("New Resource Uploaded", "Resources: The Masterclass video is live.", {"type": "new_resource"}),
        ("Announcement", "Alert: Event tickets are closing!", {"type": "flash_alert"}),
        ("Founder of the Week! 🌟", "Meet our featured founder of the week.", {"type": "founder_spotlight"}),
        ("Business of the Month! 🏆", "Vibe Studios is our business of the month.", {"type": "business_spotlight"}),
        ("Community Chat", f"Community: New message in the lounge.", {"type": "community_chat"})
    ]

    for i, (title, body, data) in enumerate(notifications, 1):
        print(f"Sending ({i}/11): {title}")
        send_push_notification(admin, title, body, data=data)
    
    print("\n✅ Sent all 11 directly to your device. Check your tray!")

if __name__ == "__main__":
    send_all_direct_to_admin()
