from rest_framework import serializers
from django.contrib.auth.models import User
from .models import Conversation, Message
import boto3
from django.conf import settings

# A simple User serializer for chat participants
class ChatUserSerializer(serializers.ModelSerializer):
    tier = serializers.CharField(source='profile.tier', read_only=True)
    tier = serializers.CharField(source='profile.tier', read_only=True)
    photo_url = serializers.SerializerMethodField()

    def get_photo_url(self, obj):
        try:
            if obj.profile.photo:
                return obj.profile.photo.url
            return obj.profile.photo_url
        except:
            return None

    class Meta:
        model = User
        fields = ['id', 'username', 'tier', 'photo_url']

class MessageSerializer(serializers.ModelSerializer):
    sender = ChatUserSerializer(read_only=True)
    is_me = serializers.SerializerMethodField()
    reply_to = serializers.SerializerMethodField()
    reply_to_id = serializers.PrimaryKeyRelatedField(
        queryset=Message.objects.all(), source='reply_to', write_only=True, required=False, allow_null=True
    )
    is_read = serializers.SerializerMethodField()
    
    # Media Fields
    attachment = serializers.FileField(write_only=True, required=False) # For input
    attachment_url = serializers.SerializerMethodField() # For output
    message_type = serializers.CharField(required=False)

    class Meta:
        model = Message
        fields = ['id', 'sender', 'text', 'created_at', 'is_me', 'reply_to', 'reply_to_id', 'is_read', 'message_type', 'attachment', 'attachment_url']

    def get_attachment_url(self, obj):
        if not obj.attachment:
            return None
        
        # If in development or using local storage, return the direct URL
        if 's3' not in settings.DEFAULT_FILE_STORAGE.lower() and 's3' not in settings.STORAGES['default']['BACKEND'].lower():
            try:
                request = self.context.get('request')
                return request.build_absolute_uri(obj.attachment.url)
            except:
                return obj.attachment.url

        # Generate Presigned URL for S3
        try:
            s3_client = boto3.client(
                's3',
                aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
                aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
                region_name=settings.AWS_S3_REGION_NAME
            )
            url = s3_client.generate_presigned_url(
                'get_object',
                Params={'Bucket': settings.AWS_STORAGE_BUCKET_NAME, 'Key': obj.attachment.name},
                ExpiresIn=3600 # 1 Hour
            )
            return url
        except Exception as e:
            # Fallback
            return None

    def get_is_read(self, obj):
        # 1. Start with actual DB status
        status = obj.is_read
        
        # 2. If I am the SENDER, check if the RECIPIENT allows me to see it
        request = self.context.get('request')
        if request and obj.sender == request.user:
            # Context injected by MessageListView
            partner_allows = self.context.get('partner_read_receipts', True) 
            if not partner_allows:
                return False
        
        return status

    def get_reply_to(self, obj):
        if obj.reply_to:
            return {
                'id': obj.reply_to.id,
                'text': obj.reply_to.text,
                'sender': ChatUserSerializer(obj.reply_to.sender).data
            }
        return None

    def get_is_me(self, obj):
        # Tell Flutter if this message is from "me" (blue bubble) or "them" (grey bubble)
        request = self.context.get('request')
        return request and request.user == obj.sender

class ConversationSerializer(serializers.ModelSerializer):
    participants = ChatUserSerializer(many=True, read_only=True)
    last_message = serializers.SerializerMethodField()

    def get_last_message(self, obj):
        last_msg = obj.messages.order_by('-created_at').first()
        if last_msg:
            return MessageSerializer(last_msg, context=self.context).data
        return None

    def get_unread_count(self, obj):
        request = self.context.get('request')
        if request and request.user:
             # Count messages in this conversation where I am a participant, but NOT the sender, and is_read=False
             return obj.messages.filter(is_read=False).exclude(sender=request.user).count()
        return 0

    unread_count = serializers.SerializerMethodField()
    class Meta:
        model = Conversation
        fields = ['id', 'participants', 'updated_at', 'last_message', 'unread_count']
