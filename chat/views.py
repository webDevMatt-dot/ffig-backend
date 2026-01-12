from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.contrib.auth.models import User
from django.shortcuts import get_object_or_404
from core.permissions import IsPremiumUser, IsStandardUser
from .models import Conversation, Message
from .serializers import ConversationSerializer, MessageSerializer

# 1. List all my conversations
class ConversationListView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ConversationSerializer

    def get_queryset(self):
        from django.db.models import Q
        user = self.request.user
        queryset = user.conversations.all().order_by('-updated_at')

        # 1. Critical: Filter by Recipient ID (Fixes Chat Bleed)
        recipient_id = self.request.query_params.get('recipient_id')
        if recipient_id:
             queryset = queryset.filter(participants__id=recipient_id)

        # 2. Search
        search = self.request.query_params.get('search')
        if search:
             queryset = queryset.filter(
                 Q(participants__username__icontains=search) | 
                 Q(messages__text__icontains=search)
             ).distinct()

        # 3. Filter (Unread/Favorites)
        filter_type = self.request.query_params.get('filter')
        if filter_type == 'unread':
             queryset = queryset.filter(
                 messages__is_read=False
             ).exclude(messages__sender=user).distinct()
        elif filter_type == 'favorites':
             if hasattr(user, 'profile'):
                 queryset = queryset.filter(participants__in=user.profile.favorites.all()).distinct()
        
        return queryset

# 2. Get messages for a specific conversation
class MessageListView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = MessageSerializer

    def get_queryset(self):
        conversation_id = self.kwargs['pk']
        
        # Security Check
        conversation = get_object_or_404(Conversation, id=conversation_id)
        if not conversation.is_public and self.request.user not in conversation.participants.all():
             return Message.objects.none()

        # 1. Get messages with eager loading (N+1 fix)
        messages = Message.objects.filter(conversation__id=conversation_id).select_related(
            'sender', 
            'sender__profile', 
            'reply_to', 
            'reply_to__sender', 
            'reply_to__sender__profile'
        ).order_by('created_at')

        # 2. MARK AS READ (Magic!)
        # Only mark messages sent by the *other* person as read
        messages.exclude(sender=self.request.user).update(is_read=True)

        return messages

class UnreadCountView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        # Count messages sent to ME that are NOT read
        count = Message.objects.filter(
            conversation__participants=request.user, 
            is_read=False
        ).exclude(sender=request.user).count()

        return Response({"unread_count": count})

# 3. Send a message (Auto-creates conversation if needed)
class SendMessageView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        recipient_id = request.data.get('recipient_id')
        text = request.data.get('text')
        conversation_id = request.data.get('conversation_id')

        sender = request.user

        # Scenario A: Sending to an existing conversation
        if conversation_id:
            # We need to filter by participants to ensure the sender is part of it
            # But simpler for now: just get the object
            conversation = get_object_or_404(Conversation, id=conversation_id)
            if not conversation.is_public and sender not in conversation.participants.all():
                 return Response({"error": "You are not a participant"}, status=403)

        # Scenario B: Starting a new chat with a User ID
        elif recipient_id:
            recipient = get_object_or_404(User, id=recipient_id)
            # Check if conversation already exists
            conversation = Conversation.objects.filter(participants=sender).filter(participants=recipient).first()
            if not conversation:
                conversation = Conversation.objects.create()
                conversation.participants.add(sender, recipient)
        else:
            return Response({"error": "Missing recipient_id or conversation_id"}, status=400)

        # Create the message
        reply_id = request.data.get('reply_to_id')
        Message.objects.create(conversation=conversation, sender=sender, text=text, reply_to_id=reply_id)

        # Update timestamp
        conversation.save() 

        return Response({"status": "Message sent", "conversation_id": conversation.id}, status=201)

# 4. Get/Create Global Community Chat
class CommunityChatView(APIView):
    permission_classes = [IsStandardUser]

    def get(self, request):
        conversation, created = Conversation.objects.get_or_create(is_public=True)
        return Response({"id": conversation.id, "created": created})
