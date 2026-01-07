from rest_framework import viewsets, permissions
from .models import HeroItem, FounderProfile, FlashAlert, NewsTickerItem
from .serializers import (
    HeroItemSerializer, FounderProfileSerializer, 
    FlashAlertSerializer, NewsTickerItemSerializer
)
from django.utils import timezone

class HeroItemViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = HeroItem.objects.filter(is_active=True)
    serializer_class = HeroItemSerializer
    permission_classes = [permissions.AllowAny]

class FounderProfileViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = FounderProfile.objects.filter(is_active=True)
    serializer_class = FounderProfileSerializer
    permission_classes = [permissions.AllowAny]

class FlashAlertViewSet(viewsets.ReadOnlyModelViewSet):
    # Only show active alerts that haven't expired
    queryset = FlashAlert.objects.filter(is_active=True)
    serializer_class = FlashAlertSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        return super().get_queryset().filter(expiry_time__gt=timezone.now())

class NewsTickerItemViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = NewsTickerItem.objects.filter(is_active=True)
    serializer_class = NewsTickerItemSerializer
    permission_classes = [permissions.AllowAny]
