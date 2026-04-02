from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import FlashAlert, HeroItem, FounderProfile, BusinessOfMonth

@receiver(post_save, sender=FlashAlert)
def notify_global_new_flash_alert(sender, instance, created, **kwargs):
    """Notify all users (global topic) about a new flash alert."""
    if created and instance.is_active:
        from core.services.fcm_service import send_topic_notification
        send_topic_notification(
            topic="global",
            title=f"New Announcement: {instance.title}",
            body=instance.message,
            data={"type": "flash_alert", "alert_id": str(instance.id), "alert_type": instance.type}
        )

@receiver(post_save, sender=HeroItem)
def notify_global_new_hero_item(sender, instance, created, **kwargs):
    """Notify all users (global topic) about a new hero announcement."""
    if created and instance.is_active and instance.type == 'Announcement':
        from core.services.fcm_service import send_topic_notification
        send_topic_notification(
            topic="global",
            title="New Announcement",
            body=instance.title,
            data={"type": "hero_announcement", "item_id": str(instance.id)}
        )

@receiver(post_save, sender=FounderProfile)
def notify_global_new_founder_spotlight(sender, instance, created, **kwargs):
    """Notify all users (global topic) about a new Founder of the Week."""
    if (created and instance.is_active) or (not created and instance.is_active):
        # We might want a check to see if 'is_active' just flipped from False to True 
        # but for simplicity, notifying on any save where is_active=True is usually what's desired for spotlights.
        from core.services.fcm_service import send_topic_notification
        send_topic_notification(
            topic="global",
            title="Founder of the Week! 🌟",
            body=f"Meet {instance.name}, our featured founder from {instance.country}.",
            data={"type": "founder_spotlight", "founder_id": str(instance.id)}
        )

@receiver(post_save, sender=BusinessOfMonth)
def notify_global_new_business_spotlight(sender, instance, created, **kwargs):
    """Notify all users (global topic) about a new Business of the Month."""
    if (created and instance.is_active) or (not created and instance.is_active):
        from core.services.fcm_service import send_topic_notification
        send_topic_notification(
            topic="global",
            title="Business of the Month! 🏆",
            body=f"{instance.name} has been featured as this month's top business.",
            data={"type": "business_spotlight", "business_id": str(instance.id)}
        )
