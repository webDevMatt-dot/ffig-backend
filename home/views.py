from rest_framework import viewsets, permissions
from .models import HeroItem, FounderProfile, FlashAlert, NewsTickerItem, AppVersion
from .serializers import (
    HeroItemSerializer, FounderProfileSerializer, 
    FlashAlertSerializer, NewsTickerItemSerializer, AppVersionSerializer
)
from django.utils import timezone

class BaseHomeViewSet(viewsets.ModelViewSet):
    def get_permissions(self):
        # Allow anyone to Read, but only Staff to Write (Create, Update, Delete)
        if self.action in ['list', 'retrieve']:
            return [permissions.AllowAny()]
        return [permissions.IsAdminUser()]

class HeroItemViewSet(BaseHomeViewSet):
    serializer_class = HeroItemSerializer
    
    def get_queryset(self):
        # Admins see everything, Users see only active
        if self.request.user and self.request.user.is_staff:
            return HeroItem.objects.all()
        return HeroItem.objects.filter(is_active=True)

class FounderProfileViewSet(BaseHomeViewSet):
    serializer_class = FounderProfileSerializer
    
    def get_queryset(self):
        if self.request.user and self.request.user.is_staff:
            return FounderProfile.objects.all()
        return FounderProfile.objects.filter(is_active=True)

class FlashAlertViewSet(BaseHomeViewSet):
    serializer_class = FlashAlertSerializer
    
    def get_queryset(self):
        if self.request.user and self.request.user.is_staff:
            return FlashAlert.objects.all()
        return FlashAlert.objects.filter(is_active=True, expiry_time__gt=timezone.now())

class NewsTickerItemViewSet(BaseHomeViewSet):
    serializer_class = NewsTickerItemSerializer
    
    def get_queryset(self):
        if self.request.user and self.request.user.is_staff:
            return NewsTickerItem.objects.all()
        return NewsTickerItem.objects.filter(is_active=True)

class AppVersionViewSet(BaseHomeViewSet):
    serializer_class = AppVersionSerializer
    
    def get_queryset(self):
        return AppVersion.objects.all()
