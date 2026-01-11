from rest_framework import serializers
from .models import HeroItem, FounderProfile, FlashAlert, NewsTickerItem, AppVersion

class AppVersionSerializer(serializers.ModelSerializer):
    class Meta:
        model = AppVersion
        fields = '__all__'

class HeroItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = HeroItem
        fields = '__all__'

class FounderProfileSerializer(serializers.ModelSerializer):
    photo = serializers.SerializerMethodField()
    
    class Meta:
        model = FounderProfile
        fields = '__all__'

    def get_photo(self, obj):
        # 1. Use uploaded photo if available
        if obj.photo:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.photo.url)
            return obj.photo.url
            
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
