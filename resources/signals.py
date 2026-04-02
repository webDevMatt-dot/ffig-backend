from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import Resource

@receiver(post_save, sender=Resource)
def notify_global_new_resource(sender, instance, created, **kwargs):
    """Notify all users (global topic) about a new resource."""
    if created and instance.is_active:
        from core.services.fcm_service import send_topic_notification
        send_topic_notification(
            topic="global",
            title="New Resource Uploaded",
            body=f"{instance.title} is now available in Resources.",
            data={"type": "new_resource", "resource_id": str(instance.id), "category": instance.category}
        )
