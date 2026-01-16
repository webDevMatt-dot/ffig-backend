from django.db import models
from django.contrib.auth.models import User

class Conversation(models.Model):
    participants = models.ManyToManyField(User, related_name='conversations', blank=True)
    is_public = models.BooleanField(default=False)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Conversation {self.id}"

class ConversationClearStatus(models.Model):
    """Tracks when a user cleared a specific conversation"""
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    conversation = models.ForeignKey(Conversation, on_delete=models.CASCADE)
    cleared_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('user', 'conversation')

class ConversationMuteStatus(models.Model):
    """Tracks if a user has muted a specific conversation"""
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    conversation = models.ForeignKey(Conversation, on_delete=models.CASCADE)
    is_muted = models.BooleanField(default=True)
    muted_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('user', 'conversation')

class Message(models.Model):
    conversation = models.ForeignKey(Conversation, related_name='messages', on_delete=models.CASCADE)
    sender = models.ForeignKey(User, related_name='sent_messages', on_delete=models.CASCADE)
    text = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    is_read = models.BooleanField(default=False)
    reply_to = models.ForeignKey('self', null=True, blank=True, on_delete=models.SET_NULL, related_name='replies')

    def __str__(self):
        return f"{self.sender.username}: {self.text[:20]}"
