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
    
    class Meta:
        model = Profile
        fields = ['id', 'user_id', 'username', 'email', 'business_name', 'industry', 'location', 'bio', 'photo_url', 'photo', 'is_premium', 'is_online']

    def get_is_online(self, obj):
        if not obj.last_seen:
            return False
        # Online if active in last 5 minutes
        return (timezone.now() - obj.last_seen) < timedelta(minutes=5)
