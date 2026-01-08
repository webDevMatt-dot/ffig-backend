from rest_framework import serializers
from django.contrib.auth.models import User
from .models import Conversation, Message

# A simple User serializer for chat participants
class ChatUserSerializer(serializers.ModelSerializer):
    tier = serializers.CharField(source='profile.tier', read_only=True)

    class Meta:
        model = User
        fields = ['id', 'username', 'tier']

class MessageSerializer(serializers.ModelSerializer):
    sender = ChatUserSerializer(read_only=True)
    is_me = serializers.SerializerMethodField()

    class Meta:
        model = Message
        fields = ['id', 'sender', 'text', 'created_at', 'is_me']

    def get_is_me(self, obj):
        # Tell Flutter if this message is from "me" (blue bubble) or "them" (grey bubble)
        request = self.context.get('request')
        return request and request.user == obj.sender

class ConversationSerializer(serializers.ModelSerializer):
    participants = ChatUserSerializer(many=True, read_only=True)
    last_message = serializers.SerializerMethodField()

    class Meta:
        model = Conversation
        fields = ['id', 'participants', 'updated_at', 'last_message']

    def get_last_message(self, obj):
        last_msg = obj.messages.order_by('-created_at').first()
        if last_msg:
            return MessageSerializer(last_msg, context=self.context).data
        return None
