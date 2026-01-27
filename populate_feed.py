import os
import django
from django.conf import settings
from django.contrib.auth.models import User
from members.models import MarketingRequest, Profile

# Ensure Django is setup
# (If running via manage.py shell, this is handled. If standalone, need setup)

def populate():
    print("Populating VVIP Feed...")
    
    # Get Admin User or create one
    user, _ = User.objects.get_or_create(username='admin')
    if not hasattr(user, 'profile'):
        Profile.objects.create(user=user)
        
    # Clear existing test data? Maybe not.
    
    # 1. Content (Reel)
    req1, created = MarketingRequest.objects.get_or_create(
        title="Welcome to VVIP",
        user=user,
        defaults={
            'type': 'CONTENT',
            'status': 'APPROVED',
            'link': 'https://example.com',
            'image': '', # Use placeholder logic or mocked URL
            'video': ''
        }
    )
    if created:
        req1.status = 'APPROVED'
        req1.type = 'CONTENT'
        req1.save()
        print("Created Content: Welcome to VVIP")
        
    # 2. Ad
    req2, created = MarketingRequest.objects.get_or_create(
        title="Exclusive Watch Collection",
        user=user,
        defaults={
            'type': 'AD',
            'status': 'APPROVED',
            'link': 'https://watches.example.com',
        }
    )
    if created:
        req2.status = 'APPROVED'
        req2.save()
        print("Created Ad: Watch Collection")

    # 3. Promotion
    req3, created = MarketingRequest.objects.get_or_create(
        title="Gold Members Get 20% Off",
        user=user,
        defaults={
            'type': 'PROMOTION',
            'status': 'APPROVED',
            'link': 'https://promo.example.com',
        }
    )
    if created:
        req3.status = 'APPROVED'
        req3.save()
        print("Created Promotion: Gold 20% Off")
        
    print("Done!")

populate()
