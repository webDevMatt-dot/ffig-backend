from django.contrib import admin
from .models import Conversation, Message

# This lets you see messages inside the Conversation page
class MessageInline(admin.TabularInline):
    model = Message
    extra = 0 # Don't show empty rows
    readonly_fields = ('sender', 'text', 'created_at') # Prevent admin from editing history easily

@admin.register(Conversation)
class ConversationAdmin(admin.ModelAdmin):
    list_display = ('id', 'get_participants', 'updated_at')
    inlines = [MessageInline] # <--- Magic Line

    def get_participants(self, obj):
        return ", ".join([u.username for u in obj.participants.all()])
    get_participants.short_description = 'Participants'

@admin.register(Message)
class MessageAdmin(admin.ModelAdmin):
    list_display = ('sender', 'text_preview', 'conversation', 'created_at', 'is_read')
    list_filter = ('is_read', 'created_at', 'sender')
    search_fields = ('text', 'sender__username')

    def text_preview(self, obj):
        return obj.text[:50] + "..." if len(obj.text) > 50 else obj.text
