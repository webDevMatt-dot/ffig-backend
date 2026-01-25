from django.db import models
from django.contrib.auth.models import User
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.utils import timezone
from datetime import timedelta

class Profile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    business_name = models.CharField(max_length=200, blank=True)
    INDUSTRY_CHOICES = [
        ('TECH', 'Technology'),
        ('FIN', 'Finance'),
        ('HLTH', 'Healthcare'),
        ('RET', 'Retail'),
        ('EDU', 'Education'),
        ('MED', 'Media & Arts'),
        ('LEG', 'Legal'),
        ('FASH', 'Fashion'),
        ('MAN', 'Manufacturing'),
        ('OTH', 'Other'),
    ]
    
    industry = models.CharField(max_length=50, choices=INDUSTRY_CHOICES, default='OTH')
    industry_other = models.CharField(max_length=100, blank=True)
    location = models.CharField(max_length=100, blank=True)
    bio = models.TextField(blank=True)
    # RBAC Fields
    TIER_CHOICES = [
        ('FREE', 'Free'),
        ('STANDARD', 'Standard (\$200)'),
        ('PREMIUM', 'Premium (\$400)'),
    ]
    tier = models.CharField(max_length=20, choices=TIER_CHOICES, default='FREE')
    subscription_expiry = models.DateTimeField(null=True, blank=True)
    suspension_expiry = models.DateTimeField(null=True, blank=True)
    admin_notice = models.TextField(blank=True, help_text="Reason for warning/suspension (visible to user)")
    
    # Deprecated (Map to Tier later)
    is_premium = models.BooleanField(default=False) 
    
    # Privacy Settings
    read_receipts_enabled = models.BooleanField(default=True)
    
    # Favorites
    favorites = models.ManyToManyField(User, related_name='favorited_by', blank=True)
    
    # Blocking
    blocked_users = models.ManyToManyField(User, related_name='blocked_by', blank=True)
    is_blocked = models.BooleanField(default=False, help_text="Indefinitely blocked by admin")

    # We'll stick to a placeholder image for now to save setup time
    photo_url = models.URLField(blank=True, default="https://ui-avatars.com/api/?background=D4AF37&color=fff&name=Founder")
    photo = models.ImageField(upload_to='profile_photos/', blank=True, null=True)
    last_seen = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.user.username}'s Profile ({self.tier})"

class BusinessProfile(models.Model):
    STATUS_CHOICES = [('PENDING', 'Pending'), ('APPROVED', 'Approved'), ('REJECTED', 'Rejected')]
    
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='business_profile')
    company_name = models.CharField(max_length=200)
    logo = models.ImageField(upload_to='business_logos/', blank=True, null=True)
    website = models.URLField(blank=True)
    description = models.TextField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING')
    feedback = models.TextField(blank=True, help_text="Admin feedback if rejected")
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.company_name

class MarketingRequest(models.Model):
    TYPE_CHOICES = [('AD', 'Advertisement'), ('PROMOTION', 'Promotion')]
    STATUS_CHOICES = [('PENDING', 'Pending'), ('APPROVED', 'Approved'), ('REJECTED', 'Rejected')]

    user = models.ForeignKey(User, on_delete=models.CASCADE)
    type = models.CharField(max_length=20, choices=TYPE_CHOICES)
    title = models.CharField(max_length=200)
    image = models.ImageField(upload_to='marketing_assets/', blank=True, null=True)
    video = models.FileField(upload_to='marketing_videos/', blank=True, null=True)
    link = models.URLField(blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING')
    feedback = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

class ContentReport(models.Model):
    STATUS_CHOICES = [('OPEN', 'Open'), ('RESOLVED', 'Resolved')]
    ITEM_TYPE_CHOICES = [('CHAT', 'Chat Message'), ('USER', 'User Profile'), ('POST', 'Post')]

    reporter = models.ForeignKey(User, on_delete=models.CASCADE, related_name='reports_filed')
    reported_item_type = models.CharField(max_length=20, choices=ITEM_TYPE_CHOICES)
    reported_item_id = models.CharField(max_length=100) # Flexible ID
    reason = models.TextField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='OPEN')
    created_at = models.DateTimeField(auto_now_add=True)

class Notification(models.Model):
    recipient = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notifications')
    title = models.CharField(max_length=255)
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Notification for {self.recipient.username}: {self.title}"

# Magic: Auto-create a Profile whenever a User is created
@receiver(post_save, sender=User)
def create_user_profile(sender, instance, created, **kwargs):
    if created:
        Profile.objects.create(user=instance)
        
        # Notify Admins
        admins = User.objects.filter(is_staff=True)
        for admin in admins:
            Notification.objects.create(
                recipient=admin,
                title="New User Registration",
                message=f"New user joined: {instance.username} ({instance.email})"
            )

class MarketingLike(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    marketing_request = models.ForeignKey(MarketingRequest, on_delete=models.CASCADE, related_name='likes')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'marketing_request')

class MarketingComment(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    marketing_request = models.ForeignKey(MarketingRequest, on_delete=models.CASCADE, related_name='comments')
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)


class Story(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    media = models.FileField(upload_to='stories/')
    created_at = models.DateTimeField(auto_now_add=True)

    @property
    def is_active(self):
        return self.created_at >= timezone.now() - timedelta(hours=24)

    def __str__(self):
        return f"Story by {self.user.username} at {self.created_at}"
