import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from django.contrib.auth.models import User
from members.models import Profile

found = False

try:
    user = User.objects.get(username__iexact='apple')
    profile = user.profile
    print(f"Current tier: {profile.tier}, is_premium: {profile.is_premium}")
    
    profile.tier = 'STANDARD'
    profile.is_premium = False
    profile.save()
    
    print(f"Updated user {user.username} (ID: {user.id}) to Free/Standard Tier.")
    found = True
except User.DoesNotExist:
    pass

if not found:
    users = User.objects.filter(email__icontains='apple')
    for u in users:
        print(f"Found potential match: {u.username} ({u.email})")
        
        profile = u.profile
        profile.tier = 'STANDARD'
        profile.is_premium = False
        profile.save()
        print(f"Updated user {u.username} (ID: {u.id}) to Free/Standard Tier.")
        found = True

if not found:
    users = User.objects.filter(username__icontains='apple')
    for u in users:
        print(f"Found potential match: {u.username} ({u.email})")
        
        profile = u.profile
        profile.tier = 'STANDARD'
        profile.is_premium = False
        profile.save()
        print(f"Updated user {u.username} (ID: {u.id}) to Free/Standard Tier.")
        found = True
        
if not found:
    print("User 'apple' not found.")
