import os
import django
from django.utils import timezone
import datetime

# Setup Django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "ffig_backend.settings")
django.setup()

from django.contrib.auth import get_user_model
from core.services.fcm_service import send_push_notification, send_topic_notification

User = get_user_model()

def send_all_tests():
    # 1. Find Admin User
    admin = User.objects.filter(is_staff=True).exclude(username='AnonymousUser').first()
    if not admin:
        print("❌ No admin user found to send direct tests.")
        return

    print(f"🚀 Sending tests to Admin: {admin.username}")
    if not hasattr(admin, 'profile') or not admin.profile.fcm_token:
        print(f"⚠️ Warning: User {admin.username} has no FCM token. Direct pushes will skip, but topics will still be sent.")

    # --- DIRECT / ADMIN ALERTS ---
    print("\n--- 📱 Testing Direct / Admin Alerts ---")
    
    # 1. New User Verified
    send_push_notification(
        admin, 
        "Test: New User Verified", 
        f"TEST: {admin.username} has joined FFIG.",
        data={"type": "admin_alert", "user_id": str(admin.id)}
    )
    print("✅ Sent: New User Verified (Admin)")

    # 2. Ticket Purchase
    send_push_notification(
        admin, 
        "Test: New Ticket Purchase", 
        f"TEST: {admin.username} bought 1 VIP ticket for Gala Night.",
        data={"type": "admin_purchase_alert", "event_id": "test_event"}
    )
    print("✅ Sent: New Ticket Purchase (Admin)")

    # 3. New Business Pending
    send_push_notification(
        admin, 
        "Test: Business Pending", 
        "TEST: Female Founders Co. has submitted their profile.",
        data={"type": "admin_business_alert", "business_id": "test_biz"}
    )
    print("✅ Sent: Business Pending (Admin)")

    # 4. Message Alert
    send_push_notification(
        admin, 
        f"Message from FFIG Support", 
        "TEST: This is a test direct message notification.",
        data={"type": "chat_message", "conversation_id": "test_chat"}
    )
    print("✅ Sent: Direct Message Alert")


    # --- TOPIC / GLOBAL ALERTS ---
    print("\n--- 🌍 Testing Topic / Global Alerts ---")

    # 5. New Featured Post
    send_topic_notification(
        "global",
        "Test: New Featured Post",
        "TEST: Check out our latest update!",
        data={"type": "new_post", "post_id": "test_post"}
    )
    print("✅ Sent: Featured Post (Topic: global)")

    # 6. New Story
    send_topic_notification(
        "global",
        "Test: New Story",
        f"TEST: {admin.username} posted a new story.",
        data={"type": "new_story", "story_id": "test_story"}
    )
    print("✅ Sent: New Story (Topic: global)")

    # 7. New Resource
    send_topic_notification(
        "global",
        "Test: New Resource Uploaded",
        "TEST: The March Magazine is now available.",
        data={"type": "new_resource", "resource_id": "test_res"}
    )
    print("✅ Sent: New Resource (Topic: global)")

    # 8. Flash Alert
    send_topic_notification(
        "global",
        "Test Announcement: Gala Night",
        "TEST: Tickets are closing in 2 hours!",
        data={"type": "flash_alert", "alert_id": "test_alert"}
    )
    print("✅ Sent: Flash Alert (Topic: global)")

    # 9. Founder of the Week
    send_topic_notification(
        "global",
        "Test: Founder of the Week! 🌟",
        "TEST: Meet Sarah Jane, our featured founder.",
        data={"type": "founder_spotlight", "founder_id": "test_founder"}
    )
    print("✅ Sent: Founder of the Week (Topic: global)")

    # 10. Business of the Month
    send_topic_notification(
        "global",
        "Test: Business of the Month! 🏆",
        "TEST: Tech Queens Inc. is our business of the month.",
        data={"type": "business_spotlight", "business_id": "test_biz"}
    )
    print("✅ Sent: Business of the Month (Topic: global)")

    # 11. Community Chat
    send_topic_notification(
        "community_chat",
        f"Community Chat: {admin.username}",
        "TEST: Hello everyone! This is a test community message.",
        data={"type": "community_chat", "sender_name": admin.username}
    )
    print("✅ Sent: Community Chat (Topic: community_chat)")

    print("\n--- 🏁 All Tests Sent! Check your device. ---")

if __name__ == "__main__":
    send_all_tests()
