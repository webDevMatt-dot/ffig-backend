from django.db.models.signals import post_save
from django.dispatch import receiver
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
