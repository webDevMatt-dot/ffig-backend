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
    """
    API for App Versions.
    GET (Public): Check latest version.
    POST/PATCH (Admin): Update version info (Automated releases).
    """
    serializer_class = AppVersionSerializer
    filterset_fields = ['platform']
    
    def get_queryset(self):
        return AppVersion.objects.order_by('-updated_at')

# --- APK Download Helper ---
import os
from django.conf import settings
from django.http import FileResponse, Http404, HttpResponse
from rest_framework.decorators import api_view, permission_classes, authentication_classes

@api_view(['GET'])
@authentication_classes([]) # No Auth required
@permission_classes([permissions.AllowAny])
def download_latest_apk(request):
    """
    Scans mobile_app/web for the latest app-vX.X.X.apk and serves it.
    """
    try:
        apk_dir = os.path.join(settings.BASE_DIR, 'mobile_app', 'web')
        if not os.path.exists(apk_dir):
             return HttpResponse("APK Directory not found", status=404)
        
        # Find all .apk files starting with app-v
        files = [f for f in os.listdir(apk_dir) if f.startswith('app-v') and f.endswith('.apk')]
        if not files:
             return HttpResponse("No APK found", status=404)
        
        # Sort to find "latest" just in case multiple exist (though we clean usually)
        # Assuming filename sort works roughly if version padding is correct, or just pick first one
        files.sort(reverse=True) 
        latest_file = files[0]
        
        file_path = os.path.join(apk_dir, latest_file)
        
        # Serve as attachment
        response = FileResponse(open(file_path, 'rb'), content_type='application/vnd.android.package-archive')
        response['Content-Disposition'] = f'attachment; filename="{latest_file}"'
        return response
        
    except Exception as e:
        return HttpResponse(f"Error serving APK: {str(e)}", status=500)
