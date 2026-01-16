from rest_framework import serializers
from django.contrib.auth.models import User
from .models import Conversation, Message

# A simple User serializer for chat participants
class ChatUserSerializer(serializers.ModelSerializer):
    tier = serializers.CharField(source='profile.tier', read_only=True)
    photo_url = serializers.CharField(source='profile.photo_url', read_only=True)

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

    class Meta:
        model = Message
        fields = ['id', 'sender', 'text', 'created_at', 'is_me', 'reply_to', 'reply_to_id', 'is_read']

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
