from django.db.models.signals import post_save
from django.dispatch import receiver
from django.contrib.auth.models import User
from .models import Poll, QuizQuestion
from core.services.fcm_service import send_push_notification

@receiver(post_save, sender=Poll)
def notify_new_poll(sender, instance, created, **kwargs):
    """
    Trigger a push notification to all users when a new poll is created.
    """
    if created:
        # Get all users who have an FCM token in their profile
        users = User.objects.filter(profile__fcm_token__isnull=False).distinct()
        for user in users:
            send_push_notification(
                user,
                title="New Community Poll! 📊",
                body=f"We want your input: {instance.question}",
                data={"type": "poll", "poll_id": str(instance.id)}
            )

@receiver(post_save, sender=QuizQuestion)
def notify_new_quiz_question(sender, instance, created, **kwargs):
    """
    Trigger a push notification to all users when a new quiz question is created.
    """
    if created:
        # Get all users who have an FCM token in their profile
        users = User.objects.filter(profile__fcm_token__isnull=False).distinct()
        for user in users:
            send_push_notification(
                user,
                title="New Community Quiz! 🧠",
                body=f"Test your knowledge: {instance.prompt[:40]}...",
                data={"type": "quiz", "quiz_id": str(instance.id)}
            )
