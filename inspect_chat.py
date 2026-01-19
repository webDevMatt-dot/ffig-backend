
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'ffig_backend.settings')
django.setup()

from chat.models import Conversation, Message

public_chats = Conversation.objects.filter(is_public=True)
print(f"Found {public_chats.count()} public conversations.")

for chat in public_chats:
    msg_count = chat.messages.count()
    print(f"Chat ID: {chat.id}, Messages: {msg_count}")
