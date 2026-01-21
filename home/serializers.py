from rest_framework import serializers
from .models import HeroItem, FounderProfile, FlashAlert, NewsTickerItem, AppVersion
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
        fields = '__all__'

    def get_image_url(self, obj):
        if not obj.image: return None
        request = self.context.get('request')
        try:
             url = obj.image.url
             # If local storage, ensure absolute URI
             if url.startswith('/'):
                 return request.build_absolute_uri(url)
             return url
        except: return None

class FounderProfileSerializer(serializers.ModelSerializer):
    photo = serializers.SerializerMethodField()
    
    class Meta:
        model = FounderProfile
        fields = '__all__'

    def get_photo(self, obj):
        # 1. Use uploaded photo if available
        if obj.photo:
            try:
                url = obj.photo.url
                if url.startswith('/'):
                    request = self.context.get('request')
                    if request: return request.build_absolute_uri(url)
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
