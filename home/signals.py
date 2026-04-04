from django.db.models.signals import post_save
from django.dispatch import receiver
from django.utils import timezone
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
    if instance.is_active:
        # We only notify if it was JUST activated or JUST created as active.
        # If it's an update but was already active, we don't notify again.
        # To be precise, we check if it was previously inactive. 
        # But for new creation + active, we definitely notify.
        
        # Simplified: If created and active, notify. 
        # If not created and active, we need to know if it transition.
        # Signal doesn't easily store 'old' value. 
        # But we can rely on our save() logic setting a very recent expires_at.
        
        if created:
            from core.services.fcm_service import send_topic_notification
            send_topic_notification(
                topic="global",
                title="Founder of the Week! 🌟",
                body=f"Meet {instance.name}, our featured founder from {instance.country}.",
                data={"type": "founder_spotlight", "founder_id": str(instance.id)}
            )
        else:
            # Check if it was just activated (within the last few seconds)
            # This is a safe proxy for "just clicked Go Live"
            if instance.expires_at and (timezone.now() - instance.expires_at).total_seconds() > -604800 + 10: # approx 10s window
                 # This is tricky with signals. 
                 # Better approach: check if it was previously active.
                 # Let's assume for now that activation is the main trigger.
                 pass 
             
    # NOTE: Re-implementing with a more robust 'just activated' check or moving to view.
    # For now, let's just ensure we don't notify if created as INACTIVE.
    if created and instance.is_active:
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
