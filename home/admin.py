from django.contrib import admin
from .models import HeroItem, FounderProfile, FlashAlert, NewsTickerItem, AppVersion, BusinessOfMonth

@admin.register(AppVersion)
class AppVersionAdmin(admin.ModelAdmin):
    list_display = ('platform', 'latest_version', 'required', 'updated_at')

@admin.register(HeroItem)
class HeroItemAdmin(admin.ModelAdmin):
    list_display = ('title', 'type', 'is_active', 'order')
    list_editable = ('is_active', 'order')
    search_fields = ('title', 'type')
    ordering = ('order', '-created_at')

@admin.register(FounderProfile)
class FounderProfileAdmin(admin.ModelAdmin):
    list_display = ('name', 'user', 'business_name', 'country', 'is_active', 'expires_at')
    list_editable = ('is_active',)
    search_fields = ('name', 'business_name', 'country')
    # autocomplete_fields = ['user'] # Disabled to allow standard dropdown selection
    
    fieldsets = (
        ('Spotlight Selection', {
            'fields': ('user', 'expires_at', 'is_active')
        }),
        ('Auto-Filled Details (Editable)', {
            'fields': ('name', 'business_name', 'country', 'bio', 'photo', 'is_premium'),
            'description': "<strong>LEAVE THESE BLANK</strong> to auto-fill from the selected User's profile. You can fill them manually to override specific details."
        }),
    )

@admin.register(FlashAlert)
class FlashAlertAdmin(admin.ModelAdmin):
    list_display = ('title', 'type', 'expiry_time', 'is_active')
    list_editable = ('is_active',)
    list_filter = ('type', 'is_active')

@admin.register(NewsTickerItem)
class NewsTickerItemAdmin(admin.ModelAdmin):
    list_display = ('text', 'is_active', 'order')
    list_editable = ('is_active', 'order')
    ordering = ('order', '-created_at')

@admin.register(BusinessOfMonth)
class BusinessOfMonthAdmin(admin.ModelAdmin):
    list_display = ('name', 'website', 'location', 'is_active', 'order')
    list_editable = ('is_active', 'order')
    search_fields = ('name', 'location', 'description')
    ordering = ('order', '-created_at')
