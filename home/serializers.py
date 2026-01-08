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
    class Meta:
        model = FounderProfile
        fields = '__all__'

class FlashAlertSerializer(serializers.ModelSerializer):
    class Meta:
        model = FlashAlert
        fields = '__all__'

class NewsTickerItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = NewsTickerItem
        fields = '__all__'
