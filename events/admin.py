from django.contrib import admin
from .models import Event

@admin.register(Event)
class EventAdmin(admin.ModelAdmin):
    list_display = ('title', 'date', 'location', 'organizer', 'is_active', 'is_featured')
    search_fields = ('title', 'location', 'description')
    list_filter = ('is_active', 'is_featured', 'is_virtual')
