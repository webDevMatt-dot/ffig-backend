from django.db import models
from django.contrib.auth.models import User
from django.db.models.signals import post_save
from django.dispatch import receiver

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
    location = models.CharField(max_length=100, blank=True)
    bio = models.TextField(blank=True)
    is_premium = models.BooleanField(default=False)
    # We'll stick to a placeholder image for now to save setup time
    photo_url = models.URLField(blank=True, default="https://ui-avatars.com/api/?background=D4AF37&color=fff&name=Founder")
    photo = models.ImageField(upload_to='profile_photos/', blank=True, null=True)
    last_seen = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.user.username}'s Profile"

# Magic: Auto-create a Profile whenever a User is created
@receiver(post_save, sender=User)
def create_user_profile(sender, instance, created, **kwargs):
    if created:
        Profile.objects.create(user=instance)
