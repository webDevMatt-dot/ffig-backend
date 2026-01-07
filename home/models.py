from django.db import models

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

    def __str__(self):
        return self.title

class FounderProfile(models.Model):
    name = models.CharField(max_length=200)
    photo = models.ImageField(upload_to='founder_photos/')
    bio = models.TextField()
    country = models.CharField(max_length=100)
    business_name = models.CharField(max_length=200)
    is_premium = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

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
