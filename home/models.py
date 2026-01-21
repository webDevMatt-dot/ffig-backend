from django.db import models
from PIL import Image
from io import BytesIO
from django.core.files.base import ContentFile

class HeroItem(models.Model):
    TYPE_CHOICES = [
        ('Announcement', 'Announcement'),
        ('Sponsorship', 'Sponsorship'),
        ('Update', 'Update'),
        ('Opportunity', 'Opportunity'),
        ('Community', 'Community'),
    ]

    title = models.CharField(max_length=200)
    image = models.ImageField(upload_to='hero_images/')
    type = models.CharField(max_length=50, choices=TYPE_CHOICES, default='Update')
    action_url = models.URLField(blank=True, null=True)
    is_active = models.BooleanField(default=True)
    order = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order', '-created_at']

    def save(self, *args, **kwargs):
        # Compression Logic
        if self.image:
             try:
                img = Image.open(self.image)
                if img.mode != 'RGB':
                    img = img.convert('RGB')
                
                # Resize max dimension to 1024
                img.thumbnail((1024, 1024))
                
                output = BytesIO()
                img.save(output, format='JPEG', quality=85) # High quality for Hero
                output.seek(0)
                
                self.image = ContentFile(output.read(), name=self.image.name.split('/')[-1])
             except Exception:
                pass 
        super().save(*args, **kwargs)

    def __str__(self):
        return self.title

from datetime import timedelta
from django.utils import timezone
from django.contrib.auth.models import User

class FounderProfile(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, null=True, blank=True, help_text="Select an existing user to auto-fill details")
    name = models.CharField(max_length=200, blank=True)
    photo = models.ImageField(upload_to='founder_photos/', blank=True, null=True)
    bio = models.TextField(blank=True)
    country = models.CharField(max_length=100, blank=True)
    business_name = models.CharField(max_length=200, blank=True)
    is_premium = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    expires_at = models.DateTimeField(null=True, blank=True, help_text="Defaults to 7 days from now")
    created_at = models.DateTimeField(auto_now_add=True)

    def save(self, *args, **kwargs):
        # 1. Auto-set Expiry if new or not set
        if not self.expires_at:
            self.expires_at = timezone.now() + timedelta(days=7)
        
        # 2. Auto-populate from User Profile if user is selected
        if self.user:
            try:
                # Assuming the related name is 'profile' or reverse lookup is accessible
                # Based on members/models.py: Profile.user = OneToOneField(User)
                user_profile = self.user.profile 
                
                if not self.name:
                    self.name = f"{self.user.first_name} {self.user.last_name}".strip() or self.user.username
                
                if not self.business_name:
                    self.business_name = user_profile.business_name
                
                if not self.country:
                    self.country = user_profile.location
                
                if not self.bio:
                    self.bio = user_profile.bio
                
                # Check tier for premium status logic (if applicable)
                if user_profile.tier == 'PREMIUM':
                    self.is_premium = True
                
            except Exception as e:
                print(f"Error populating FounderProfile from User: {e}")
        
        # Compression Logic
        if self.photo:
             try:
                img = Image.open(self.photo)
                if img.mode != 'RGB':
                    img = img.convert('RGB')
                
                # Resize max dimension to 1024
                img.thumbnail((1024, 1024))
                
                output = BytesIO()
                img.save(output, format='JPEG', quality=85)
                output.seek(0)
                
                # Use split to get filename only
                self.photo = ContentFile(output.read(), name=self.photo.name.split('/')[-1])
             except Exception:
                pass 

        super().save(*args, **kwargs)

    def __str__(self):
        return self.name

class FlashAlert(models.Model):
    TYPE_CHOICES = [
        ('Happening Soon', 'Happening Soon'),
        ('Tickets Closing', 'Tickets Closing'),
        ('Flash Sale', 'Flash Sale'),
        ('Alert', 'Alert'),
    ]

    title = models.CharField(max_length=100)
    message = models.CharField(max_length=255)
    expiry_time = models.DateTimeField()
    action_url = models.URLField(blank=True, null=True)
    type = models.CharField(max_length=50, choices=TYPE_CHOICES, default='Alert')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.title} - {self.expiry_time}"

class NewsTickerItem(models.Model):
    text = models.CharField(max_length=255)
    url = models.URLField(blank=True, null=True)
    is_active = models.BooleanField(default=True)
    order = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order', '-created_at']

    def __str__(self):
        return self.text

class AppVersion(models.Model):
    PLATFORM_CHOICES = [
        ('ANDROID', 'Android'),
        ('IOS', 'iOS'),
    ]
    platform = models.CharField(max_length=10, choices=PLATFORM_CHOICES)
    latest_version = models.CharField(max_length=20, help_text="e.g. 1.0.3")
    required = models.BooleanField(default=False, help_text="Force update?")
    update_url = models.URLField(help_text="Play Store or Direct Link")
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.platform} - {self.latest_version}"
