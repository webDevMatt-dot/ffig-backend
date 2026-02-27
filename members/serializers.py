from rest_framework import serializers
from django.contrib.auth.models import User
from .models import Profile, BusinessProfile, MarketingRequest, ContentReport, Story, StoryView, Conversation, Message, LoginLog
from django.utils import timezone
from datetime import timedelta
from django.conf import settings
import boto3

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
        fields = ['id', 'user_id', 'username', 'email', 'first_name', 'last_name', 'business_name', 'industry', 'industry_other', 'industry_label', 'location', 'bio', 'photo_url', 'photo', 'is_premium', 'tier', 'subscription_expiry', 'is_online', 'is_staff', 'read_receipts_enabled', 'admin_notice', 'suspension_expiry', 'is_blocked', 'fcm_token']

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
        if not obj.photo:
            return obj.photo_url

        # Check for S3
        if 's3' not in settings.DEFAULT_FILE_STORAGE.lower() and 's3' not in settings.STORAGES['default']['BACKEND'].lower():
            try:
                request = self.context.get('request')
                return request.build_absolute_uri(obj.photo.url)
            except:
                return obj.photo.url

        # Generate Presigned URL
        try:
            s3_client = boto3.client(
                's3',
                aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
                aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
                region_name=settings.AWS_S3_REGION_NAME
            )
            url = s3_client.generate_presigned_url(
                'get_object',
                Params={'Bucket': settings.AWS_STORAGE_BUCKET_NAME, 'Key': obj.photo.name},
                ExpiresIn=3600 # 1 Hour
            )
            return url
        except Exception:
            return None


class BusinessProfileSerializer(serializers.ModelSerializer):
    logo_url = serializers.SerializerMethodField()

    class Meta:
        model = BusinessProfile
        fields = '__all__'
        read_only_fields = ['user', 'status', 'feedback']

    def get_logo_url(self, obj):
        if not obj.logo:
            return None
        
        # S3 Check & Presign
        if 's3' not in settings.DEFAULT_FILE_STORAGE.lower() and 's3' not in settings.STORAGES['default']['BACKEND'].lower():
                try:
                    return obj.logo.url
                except:
                    return None

        try:
            s3_client = boto3.client(
                's3',
                aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
                aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
                region_name=settings.AWS_S3_REGION_NAME
            )
            return s3_client.generate_presigned_url(
                'get_object',
                Params={'Bucket': settings.AWS_STORAGE_BUCKET_NAME, 'Key': obj.logo.name},
                ExpiresIn=3600
            )
        except:
            return None

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
            if not profile.photo:
                return profile.photo_url
            
            # S3 Check & Presign
            if 's3' not in settings.DEFAULT_FILE_STORAGE.lower() and 's3' not in settings.STORAGES['default']['BACKEND'].lower():
                 return profile.photo.url

            s3_client = boto3.client(
                's3',
                aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
                aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
                region_name=settings.AWS_S3_REGION_NAME
            )
            return s3_client.generate_presigned_url(
                'get_object',
                Params={'Bucket': settings.AWS_STORAGE_BUCKET_NAME, 'Key': profile.photo.name},
                ExpiresIn=3600
            )
        except:
            return None

class MarketingRequestSerializer(serializers.ModelSerializer):
    likes_count = serializers.SerializerMethodField()
    comments_count = serializers.SerializerMethodField()
    is_liked = serializers.SerializerMethodField()
    username = serializers.CharField(source='user.username', read_only=True)
    user_photo = serializers.SerializerMethodField()
    image_url = serializers.SerializerMethodField()
    video_url = serializers.SerializerMethodField()

    class Meta:
        model = MarketingRequest
        fields = ['id', 'user', 'type', 'title', 'image', 'image_url', 'video', 'video_url', 'link', 'status', 'feedback', 'created_at', 'likes_count', 'comments_count', 'is_liked', 'username', 'user_photo']
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
            if not profile.photo:
                return profile.photo_url
            
            # S3 Check & Presign
            if 's3' not in settings.DEFAULT_FILE_STORAGE.lower() and 's3' not in settings.STORAGES['default']['BACKEND'].lower():
                 return profile.photo.url

            s3_client = boto3.client(
                's3',
                aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
                aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
                region_name=settings.AWS_S3_REGION_NAME
            )
            return s3_client.generate_presigned_url(
                'get_object',
                Params={'Bucket': settings.AWS_STORAGE_BUCKET_NAME, 'Key': profile.photo.name},
                ExpiresIn=3600
            )
        except:
            return None

    def get_image_url(self, obj):
        if not obj.image: return None
        # S3 Check & Presign
        if 's3' not in settings.DEFAULT_FILE_STORAGE.lower() and 's3' not in settings.STORAGES['default']['BACKEND'].lower():
                try: return obj.image.url
                except: return None
        try:
            s3_client = boto3.client('s3', aws_access_key_id=settings.AWS_ACCESS_KEY_ID, aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY, region_name=settings.AWS_S3_REGION_NAME)
            return s3_client.generate_presigned_url('get_object', Params={'Bucket': settings.AWS_STORAGE_BUCKET_NAME, 'Key': obj.image.name}, ExpiresIn=3600)
        except: return None

    def get_video_url(self, obj):
        if not obj.video: return None
        # S3 Check & Presign
        if 's3' not in settings.DEFAULT_FILE_STORAGE.lower() and 's3' not in settings.STORAGES['default']['BACKEND'].lower():
                try: return obj.video.url
                except: return None
        try:
            s3_client = boto3.client('s3', aws_access_key_id=settings.AWS_ACCESS_KEY_ID, aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY, region_name=settings.AWS_S3_REGION_NAME)
            return s3_client.generate_presigned_url('get_object', Params={'Bucket': settings.AWS_STORAGE_BUCKET_NAME, 'Key': obj.video.name}, ExpiresIn=3600)
        except: return None

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

class StorySerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    media_url = serializers.SerializerMethodField()
    user_photo = serializers.SerializerMethodField()
    seen = serializers.SerializerMethodField()
    is_active = serializers.BooleanField(read_only=True)
    is_owner = serializers.SerializerMethodField()

    class Meta:
        model = Story
        fields = ['id', 'user', 'username', 'user_photo', 'media', 'media_url', 'created_at', 'seen', 'is_active', 'is_owner']
        read_only_fields = ['user', 'created_at']

    def get_is_owner(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.user == request.user
        return False

    def get_seen(self, obj):
        # This will be populated by the ViewSet efficiently
        return getattr(obj, 'is_seen', False)

    def get_user_photo(self, obj):
        if hasattr(obj.user, 'profile'):
            # Re-use logic or quick access
            p = obj.user.profile
            if p.photo:
                # Basic check, ideally use the profile logic but simple URL is fine for now
                if 's3' not in settings.DEFAULT_FILE_STORAGE.lower() and 's3' not in settings.STORAGES['default']['BACKEND'].lower():
                     try:
                        request = self.context.get('request')
                        if request: return request.build_absolute_uri(p.photo.url)
                     except: pass
                     return p.photo.url
                     
                # S3 Presign (Duplicate logic from ProfileSerializer to avoid circular dep or heavy refactor)
                try:
                    s3_client = boto3.client('s3', aws_access_key_id=settings.AWS_ACCESS_KEY_ID, aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY, region_name=settings.AWS_S3_REGION_NAME)
                    return s3_client.generate_presigned_url('get_object', Params={'Bucket': settings.AWS_STORAGE_BUCKET_NAME, 'Key': p.photo.name}, ExpiresIn=3600)
                except: return p.photo_url
            return p.photo_url
        return None

    def get_media_url(self, obj):
        if not obj.media: return None

        # Check for S3 usage
        is_s3 = False
        if hasattr(settings, 'DEFAULT_FILE_STORAGE') and 's3' in settings.DEFAULT_FILE_STORAGE.lower():
            is_s3 = True
        elif hasattr(settings, 'STORAGES') and 's3' in settings.STORAGES.get('default', {}).get('BACKEND', '').lower():
            is_s3 = True
            
        if not is_s3:
            try:
                request = self.context.get('request')
                if request:
                    return request.build_absolute_uri(obj.media.url)
            except:
                pass
            return obj.media.url
            
        # S3 Presigned URL
        try:
            s3_client = boto3.client(
                's3', 
                aws_access_key_id=settings.AWS_ACCESS_KEY_ID, 
                aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY, 
                region_name=settings.AWS_S3_REGION_NAME
            )
            return s3_client.generate_presigned_url(
                'get_object', 
                Params={'Bucket': settings.AWS_STORAGE_BUCKET_NAME, 'Key': obj.media.name}, 
                ExpiresIn=3600
            )
        except Exception as e:
            # Fallback
            print(f"Error generating presigned URL: {e}")
            try: return obj.media.url
            except: return None


class StoryViewSerializer(serializers.ModelSerializer):
    class Meta:
        model = StoryView
        fields = ['story', 'viewer', 'seen_at']
        read_only_fields = ['viewer', 'seen_at']


class StoryGroupSerializer(serializers.Serializer):
    user_id = serializers.IntegerField()
    username = serializers.CharField()
    user_photo = serializers.CharField(allow_null=True)
    has_unseen = serializers.BooleanField()
    stories = StorySerializer(many=True)


class MessageSerializer(serializers.ModelSerializer):
    sender = ProfileSerializer(source='sender.profile', read_only=True)
    
    class Meta:
        model = Message
        fields = ['id', 'sender', 'content', 'created_at', 'story', 'is_read']
        read_only_fields = ['sender', 'created_at', 'is_read']
class LoginLogSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)

    class Meta:
        model = LoginLog
        fields = ['id', 'username', 'timestamp', 'ip_address', 'user_agent']
