from django.contrib import admin
from .models import HeroItem, FounderProfile, FlashAlert, NewsTickerItem, AppVersion

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
    list_display = ('name', 'business_name', 'country', 'is_active', 'is_premium')
    list_editable = ('is_active', 'is_premium')
    search_fields = ('name', 'business_name', 'country')

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
