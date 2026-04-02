from django.db.models.signals import post_save
from django.dispatch import receiver
from django.contrib.auth.signals import user_logged_in
from .models import Notification
from firebase_admin import messaging
import logging

logger = logging.getLogger(__name__)

@receiver(post_save, sender=Notification)
def send_fcm_notification(sender, instance, created, **kwargs):
    """
    Triggers when a Notification is created.
    Sends a push notification to the recipient via FCM.
    """
    if created:
        # Check if the instance has a flag to skip FCM (e.g. set by Chat View)
        if getattr(instance, 'skip_fcm', False):
            return

        try:
            # 1. Get User's FCM Token
            user_profile = getattr(instance.recipient, 'profile', None)
            if not user_profile or not user_profile.fcm_token:
                logger.warning(f"Skipping Push: No FCM token for user {instance.recipient.username}")
                return

            token = user_profile.fcm_token

            # 2. Construct Message
            # See FCM docs: https://firebase.google.com/docs/cloud-messaging/send-message
            message = messaging.Message(
                notification=messaging.Notification(
                    title=instance.title,
                    body=instance.message,
                ),
                data={
                    "click_action": "FLUTTER_NOTIFICATION_CLICK",
                    "id": str(instance.id),
                    "type": "general_notification" 
                },
                token=token,
            )

            # 3. Send
            response = messaging.send(message)
            logger.info(f"✅ Push Sent to {instance.recipient.username}: {response}")

        except Exception as e:
            logger.error(f"❌ Failed to send FCM Push: {e}")


@receiver(user_logged_in)
def log_user_login(sender, request, user, **kwargs):
    """
    Triggers when a user logs in.
    Creates a LoginLog entry.
    """
    from .models import LoginLog
    
    # Get IP Address
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        ip = x_forwarded_for.split(',')[0]
    else:
        ip = request.META.get('REMOTE_ADDR')
        
    user_agent = request.META.get('HTTP_USER_AGENT', '')
    
    LoginLog.objects.create(
        user=user,
        ip_address=ip,
        user_agent=user_agent
    )
    logger.info(f"📝 Logged login for {user.username} from {ip}")

@receiver(post_save, sender='members.BusinessProfile')
def notify_admin_new_business(sender, instance, created, **kwargs):
    """Notify admins when a new business profile is submitted."""
    if created:
        from core.services.fcm_service import send_push_notification
        from django.contrib.auth.models import User
        admins = User.objects.filter(is_staff=True)
        for admin in admins:
            send_push_notification(
                admin,
                title="New Business Pending Approval",
                body=f"{instance.company_name} has submitted their profile.",
                data={"type": "admin_business_alert", "business_id": str(instance.id)}
            )

@receiver(post_save, sender='members.Story')
def notify_global_new_story(sender, instance, created, **kwargs):
    """Notify all users (global topic) about a new story."""
    if created:
        from core.services.fcm_service import send_topic_notification
        send_topic_notification(
            topic="global",
            title="New Story",
            body=f"{instance.user.username} posted a new story.",
            data={"type": "new_story", "story_id": str(instance.id)}
        )

@receiver(post_save, sender='members.MarketingRequest')
def notify_global_new_post(sender, instance, created, **kwargs):
    """Notify all users (global topic) about a new featured post (approved ad/promotion)."""
    # If it's just created or status changed to APPROVED
    # Usually we notify when it's actually live
    if (created and instance.status == 'APPROVED') or (not created and instance.status == 'APPROVED'):
         # Simple check to avoid double-paging if we had a 'paged' field
         # For now, we only notify on creation if it's already approved, or when updated to approved.
         # This is a bit simplistic but works for basic flow.
         from core.services.fcm_service import send_topic_notification
         send_topic_notification(
            topic="global",
            title="New Featured Post",
            body=f"{instance.title}: Check out our latest update!",
            data={"type": "new_post", "post_id": str(instance.id)}
         )
