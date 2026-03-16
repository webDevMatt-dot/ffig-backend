import os
import django
import sys

# Setup Django environment
sys.path.append('/Users/matt/ffig-mobile-app')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User
from members.models import BusinessProfile, Profile
from members.serializers import AdminBusinessProfileSerializer
from chat.models import Conversation, Message

def main():
    # 1. Setup test user and business profile
    username = "test_business_user"
    email = "testbusiness@example.com"
    
    user, created = User.objects.get_or_create(username=username, email=email)
    if created:
        user.set_password("password123")
        user.save()
        
    print(f"User: {user.username} (ID: {user.id})")
        
    # Ensure profile exists
    profile, _ = Profile.objects.get_or_create(user=user)
    
    # Delete existing business profile if any
    if hasattr(user, 'business_profile'):
        user.business_profile.delete()
        
    # Create a fresh PENDING business profile
    bp = BusinessProfile.objects.create(
        user=user,
        company_name="Test Company LLC",
        description="A test company",
        status="PENDING"
    )
    print(f"Created BusinessProfile: ID {bp.id}, Status: {bp.status}")
    
    # Check messages before
    print("\n--- Before Rejection ---")
    conversations = list(user.conversations.all())
    print(f"User is in {len(conversations)} conversations.")
    start_msg_count = Message.objects.filter(conversation__participants=user).count()
    print(f"User has {start_msg_count} total messages.")
    
    # 2. Simulate the admin rejection request
    print("\n--- Rejecting Business Profile ---")
    
    # Use the logic from the view directly, or just update and call the signal/override directly.
    # We will simulate what perform_update does.
    old_status = bp.status
    bp.status = 'REJECTED'
    bp.feedback = "The logo is too blurry."
    bp.save()
    new_status = bp.status
    
    if old_status != 'REJECTED' and new_status == 'REJECTED':
        from core.services.fcm_service import send_push_notification
        
        # Try to find an admin user to send the message from
        admin_user = User.objects.filter(is_superuser=True).first()
        if not admin_user:
            admin_user = User.objects.filter(is_staff=True).first()
            
        print(f"Found admin user: {admin_user.username if admin_user else 'None'}")
            
        if admin_user and bp.user != admin_user:
            # Find existing conversation
            conversation = Conversation.objects.filter(
                participants=admin_user
            ).filter(
                participants=bp.user
            ).filter(
                is_public=False
            ).first()
            
            if not conversation:
                conversation = Conversation.objects.create(is_public=False)
                conversation.participants.add(admin_user, bp.user)
                
            message_text = f"Your business profile for '{bp.company_name}' has been rejected."
            if bp.feedback:
                message_text += f"\n\nReason: {bp.feedback}"
                
            msg = Message.objects.create(
                conversation=conversation,
                sender=admin_user,
                text=message_text
            )
            print(f"Created message ID {msg.id}: {msg.text}")
            
            # # Send push notification to the user (commented out to avoid actual FCM issues in test)
            # send_push_notification(
            #     bp.user,
            #     title="Business Profile Update",
            #     body=f"Your business profile has been rejected. Check your inbox for details.",
            #     data={
            #         "type": "profile_rejected",
            #         "conversation_id": str(conversation.id)
            #     }
            # )
            
    # 3. Verify messages after
    print("\n--- After Rejection ---")
    conversations = list(user.conversations.all())
    print(f"User is in {len(conversations)} conversations.")
    
    # Print the last message
    if conversations:
        conv = conversations[0]
        last_msg = conv.messages.last()
        if last_msg:
             print(f"Last message from {last_msg.sender.username}: {last_msg.text}")
    else:
        print("Error: No conversations found for user!")

if __name__ == "__main__":
    main()
