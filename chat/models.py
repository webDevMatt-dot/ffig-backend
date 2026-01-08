from django.db import models
from django.contrib.auth.models import User

class Conversation(models.Model):
    participants = models.ManyToManyField(User, related_name='conversations', blank=True) # Blank for public
    is_public = models.BooleanField(default=False)
    updated_at = models.DateTimeField(auto_now=True) # To sort by recent activity

    def __str__(self):
        return f"Conversation {self.id}"

class Message(models.Model):
    conversation = models.ForeignKey(Conversation, related_name='messages', on_delete=models.CASCADE)
    sender = models.ForeignKey(User, related_name='sent_messages', on_delete=models.CASCADE)
    text = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    is_read = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.sender.username}: {self.text[:20]}"
