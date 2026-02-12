from django.db import models
from django.contrib.auth.models import User
from PIL import Image
from io import BytesIO
from django.core.files.base import ContentFile

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
    MESSAGE_TYPES = (
        ('text', 'Text'),
        ('image', 'Image'),
        ('audio', 'Audio/Voice'),
    )

    conversation = models.ForeignKey(Conversation, related_name='messages', on_delete=models.CASCADE)
    sender = models.ForeignKey(User, related_name='sent_messages', on_delete=models.CASCADE)
    text = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    is_read = models.BooleanField(default=False)
    reply_to = models.ForeignKey('self', null=True, blank=True, on_delete=models.SET_NULL, related_name='replies')
    
    # Media Fields
    attachment = models.FileField(upload_to='chat_media/', blank=True, null=True)
    message_type = models.CharField(max_length=10, choices=MESSAGE_TYPES, default='text')
    
    # Metadata for specialized messages (e.g. Story Replies, Forwarded, etc.)
    metadata = models.JSONField(null=True, blank=True)

    def save(self, *args, **kwargs):
        # Compression Logic for Images
        if self.attachment and self.message_type == 'image':
            # Check if it's already compressed (avoid re-compressing heavily)
            # Or simplified: try-except around opening it.
            try:
                img = Image.open(self.attachment)
                
                # Check mode (RGBA needs conversion for JPEG)
                if img.mode != 'RGB':
                    img = img.convert('RGB')

                # Resize max dimension to 1024
                img.thumbnail((1024, 1024)) 
                
                output = BytesIO()
                img.save(output, format='JPEG', quality=70)
                output.seek(0)
                
                # Replace the file content
                # Note: self.attachment.name might be full path, we just want filename to avoid nesting issues
                original_name = self.attachment.name.split('/')[-1]
                self.attachment = ContentFile(output.read(), name=original_name)
            except Exception as e:
                # Fallback: Just save as is if Pillow fails (e.g. corrupt image)
                print(f"Image compression failed: {e}")
                pass
        
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.sender.username}: {self.message_type}"
