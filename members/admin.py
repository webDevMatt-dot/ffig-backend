from django.contrib import admin
from .models import Profile

@admin.register(Profile)
class ProfileAdmin(admin.ModelAdmin):
    # This makes the columns visible in the list
    list_display = ('user', 'business_name', 'is_premium', 'location') 
    
    # This allows you to filter by premium status on the right sidebar
    list_filter = ('is_premium', 'industry')
    
    # This lets you edit the checkmark directly from the list view (optional but fast!)
    list_editable = ('is_premium',) 
    
    search_fields = ('user__username', 'business_name')
