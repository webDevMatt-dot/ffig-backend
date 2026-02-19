from rest_framework import serializers
from .models import HeroItem, FounderProfile, FlashAlert, NewsTickerItem, AppVersion, BusinessOfMonth
import boto3
from django.conf import settings

class AppVersionSerializer(serializers.ModelSerializer):
    class Meta:
        model = AppVersion
        fields = '__all__'

class HeroItemSerializer(serializers.ModelSerializer):
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = HeroItem
        fields = ['id', 'title', 'image', 'image_url', 'type', 'action_url', 'is_active', 'order', 'created_at']

    def get_image_url(self, obj):
        if not obj.image: return None
        request = self.context.get('request')
        try:
             url = obj.image.url
             # Always return absolute URLs for consistency
             if request and url.startswith('/'):
                 return request.build_absolute_uri(url)
             # If no request context, construct absolute URL manually
             if url.startswith('/') and not request:
                 from django.conf import settings
                 import os
                 domain = os.environ.get('SITE_URL', 'https://ffig-backend-ti5w.onrender.com')
                 return f"{domain}{url}"
             return url
        except: return None

class FounderProfileSerializer(serializers.ModelSerializer):
    photo_url = serializers.SerializerMethodField()
    
    class Meta:
        model = FounderProfile
        fields = ['id', 'user', 'name', 'photo', 'photo_url', 'bio', 'country', 'business_name', 'is_premium', 'is_active', 'expires_at', 'created_at']

    def get_photo_url(self, obj):
        # 1. Use uploaded photo if available
        if obj.photo:
            try:
                url = obj.photo.url
                # Always return absolute URLs for consistency
                request = self.context.get('request')
                if request and url.startswith('/'):
                    return request.build_absolute_uri(url)
                # If no request context, construct absolute URL manually
                if url.startswith('/') and not request:
                    from django.conf import settings
                    from django.contrib.sites.shortcuts import get_current_site
                    import os
                    # Fallback: Use MEDIA_URL if available
                    if hasattr(settings, 'MEDIA_URL'):
                        domain = os.environ.get('SITE_URL', 'https://ffig-backend-ti5w.onrender.com')
                        return f"{domain}{url}"
                return url
            except:
                return None
            
        # 2. Fallback to User Profile photo_url if Linked
        if obj.user and hasattr(obj.user, 'profile'):
            return obj.user.profile.photo_url
            
        return None


class FlashAlertSerializer(serializers.ModelSerializer):
    class Meta:
        model = FlashAlert
        fields = '__all__'

class NewsTickerItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = NewsTickerItem
        fields = '__all__'

class BusinessOfMonthSerializer(serializers.ModelSerializer):
    image_url = serializers.SerializerMethodField()
    owner_id = serializers.IntegerField(source='owner.id', read_only=True)
    owner_name = serializers.SerializerMethodField()
    owner_photo = serializers.SerializerMethodField()

    class Meta:
        model = BusinessOfMonth
        fields = ['id', 'name', 'image', 'image_url', 'website', 'location', 'description', 'is_premium', 'is_active', 'order', 'owner_id', 'owner_name', 'owner_photo', 'created_at']

    def get_owner_name(self, obj):
        if not obj.owner: return None
        return f"{obj.owner.first_name} {obj.owner.last_name}".strip() or obj.owner.username

    def get_owner_photo(self, obj):
        if not obj.owner or not hasattr(obj.owner, 'profile'): return None
        p = obj.owner.profile
        if p.photo:
            try:
                request = self.context.get('request')
                if request: return request.build_absolute_uri(p.photo.url)
            except: pass
            return p.photo.url
        return p.photo_url

    def get_image_url(self, obj):
        if not obj.image: return None
        request = self.context.get('request')
        try:
             url = obj.image.url
             # Always return absolute URLs for consistency
             if request and url.startswith('/'):
                 return request.build_absolute_uri(url)
             # If no request context, construct absolute URL manually
             if url.startswith('/') and not request:
                 from django.conf import settings
                 import os
                 domain = os.environ.get('SITE_URL', 'https://ffig-backend-ti5w.onrender.com')
                 return f"{domain}{url}"
             return url
        except: return None
