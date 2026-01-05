from rest_framework import serializers
from django.contrib.auth.models import User
from .models import Profile
from django.utils import timezone
from datetime import timedelta

class ProfileSerializer(serializers.ModelSerializer):
    # Fetch the username from the related User model
    username = serializers.CharField(source='user.username', read_only=True)
    email = serializers.CharField(source='user.email', read_only=True)

    user_id = serializers.IntegerField(source='user.id', read_only=True)
    is_online = serializers.SerializerMethodField()
    industry_label = serializers.CharField(source='get_industry_display', read_only=True)
    
    is_staff = serializers.BooleanField(source='user.is_staff', read_only=True)
    
    class Meta:
        model = Profile
        fields = ['id', 'user_id', 'username', 'email', 'business_name', 'industry', 'industry_label', 'location', 'bio', 'photo_url', 'photo', 'is_premium', 'is_online', 'is_staff']

    def get_is_online(self, obj):
        if not obj.last_seen:
            return False
        # Online if active in last 5 minutes
        return (timezone.now() - obj.last_seen) < timedelta(minutes=5)
