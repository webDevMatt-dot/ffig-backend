from rest_framework import serializers
from django.contrib.auth.models import User
from .models import Profile, BusinessProfile, MarketingRequest, ContentReport
from django.utils import timezone
from datetime import timedelta

class ProfileSerializer(serializers.ModelSerializer):
    # Fetch the username from the related User model
    username = serializers.CharField(source='user.username', read_only=True)
    email = serializers.CharField(source='user.email', read_only=True)
    
    # Allow updating these via the Profile endpoint
    first_name = serializers.CharField(source='user.first_name', required=False)
    last_name = serializers.CharField(source='user.last_name', required=False)

    user_id = serializers.IntegerField(source='user.id', read_only=True)
    is_online = serializers.SerializerMethodField()
    industry_label = serializers.CharField(source='get_industry_display', read_only=True)
    
    is_staff = serializers.BooleanField(source='user.is_staff', read_only=True)
    admin_notice = serializers.SerializerMethodField()
    photo_url = serializers.SerializerMethodField() # Override to prefer S3 photo
    
    class Meta:
        model = Profile
        fields = ['id', 'user_id', 'username', 'email', 'first_name', 'last_name', 'business_name', 'industry', 'industry_label', 'location', 'bio', 'photo_url', 'photo', 'is_premium', 'tier', 'subscription_expiry', 'is_online', 'is_staff', 'read_receipts_enabled', 'admin_notice', 'suspension_expiry', 'is_blocked']

    def get_admin_notice(self, obj):
        # Only show the notice if the request user IS the profile user
        request = self.context.get('request', None)
        if request and request.user == obj.user:
            return obj.admin_notice
        return None

    def update(self, instance, validated_data):
        # The 'source' fields (user.first_name) come in as a nested dictionary under 'user'
        user_data = validated_data.pop('user', {})

        # Update key User fields if provided
        if user_data:
            user = instance.user
            if 'first_name' in user_data:
                user.first_name = user_data['first_name']
            if 'last_name' in user_data:
                user.last_name = user_data['last_name']
            user.save()

        # Update remaining Profile fields normally
        if 'tier' in validated_data:
            instance.tier = validated_data['tier']
        
        # Backward compatibility for is_premium
        if 'is_premium' in validated_data:
            instance.is_premium = validated_data['is_premium']
            
        instance.save()
            
        return super().update(instance, validated_data)

    def get_is_online(self, obj):
        if not obj.last_seen:
            return False
        # Online if active in last 5 minutes
        return (timezone.now() - obj.last_seen) < timedelta(minutes=5)

    def get_photo_url(self, obj):
        if obj.photo:
            return obj.photo.url
        return obj.photo_url


class BusinessProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = BusinessProfile
        fields = '__all__'
        read_only_fields = ['user', 'status', 'feedback']

class AdminBusinessProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = BusinessProfile
        fields = '__all__'
        read_only_fields = ['user'] # Admin can edit status and feedback


class MarketingLikeSerializer(serializers.ModelSerializer):
    class Meta:
        from .models import MarketingLike
        model = MarketingLike
        fields = '__all__'

class MarketingCommentSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    photo_url = serializers.SerializerMethodField()
    
    class Meta:
        from .models import MarketingComment
        model = MarketingComment
        fields = ['id', 'user', 'username', 'photo_url', 'content', 'created_at']
        read_only_fields = ['user', 'created_at']

    def get_photo_url(self, obj):
        try:
            profile = obj.user.profile
            if profile.photo:
                return profile.photo.url
            return profile.photo_url
        except:
            return None

class MarketingRequestSerializer(serializers.ModelSerializer):
    likes_count = serializers.SerializerMethodField()
    comments_count = serializers.SerializerMethodField()
    is_liked = serializers.SerializerMethodField()
    username = serializers.CharField(source='user.username', read_only=True)
    user_photo = serializers.SerializerMethodField()

    class Meta:
        model = MarketingRequest
        fields = '__all__'
        read_only_fields = ['user', 'status', 'feedback']

    def get_likes_count(self, obj):
        return obj.likes.count()

    def get_comments_count(self, obj):
        return obj.comments.count()

    def get_is_liked(self, obj):
        request = self.context.get('request', None)
        if request and request.user.is_authenticated:
            return obj.likes.filter(user=request.user).exists()
        return False

    def get_user_photo(self, obj):
        try:
            profile = obj.user.profile
            if profile.photo:
                return profile.photo.url
            return profile.photo_url
        except:
            return None

class AdminMarketingRequestSerializer(serializers.ModelSerializer):
    likes_count = serializers.SerializerMethodField()
    
    class Meta:
        model = MarketingRequest
        fields = '__all__'
        read_only_fields = ['user'] # Admin can edit status and feedback
    
    def get_likes_count(self, obj):
        return obj.likes.count()

class ContentReportSerializer(serializers.ModelSerializer):
    class Meta:
        model = ContentReport
    reporter_username = serializers.CharField(source='reporter.username', read_only=True)
    reported_user = serializers.SerializerMethodField()
    target_user_id = serializers.SerializerMethodField()
    
    class Meta:
        model = ContentReport
        fields = '__all__'
        read_only_fields = ['status', 'reporter']

    def get_reported_user(self, obj):
        try:
            if obj.reported_item_type == 'USER':
                user = User.objects.get(id=obj.reported_item_id)
                return f"{user.username} (ID: {user.id})"
            return f"ID: {obj.reported_item_id}"
        except:
             return "Unknown User"

    def get_target_user_id(self, obj):
        # Helper to get the user ID to act upon
        try:
            if obj.reported_item_type == 'USER':
                return int(obj.reported_item_id)
            # For CHAT, if we had message lookup we'd resolve it here
            return None 
        except:
            return None

class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        from .models import Notification
        model = Notification
        fields = '__all__'
        read_only_fields = ['recipient', 'created_at']
